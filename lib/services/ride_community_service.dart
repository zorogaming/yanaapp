import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_inbox_service.dart';
import 'auth_service.dart';

class RideCommunityService {
  RideCommunityService._();

  static final RideCommunityService instance = RideCommunityService._();

  static const String _ridesKey = 'ride_community_rides_v2';
  static const String _seededKey = 'ride_community_seeded_v2';
  static const String _memoriesKey = 'ride_community_memories_v2';
  static const String _memoriesSeededKey = 'ride_community_memories_seeded_v2';
  static const String _newRideAlertsKey = 'ride_community_admin_new_ride_alerts';
  static const String _rideRemindersKey = 'ride_community_admin_ride_reminders';

  final AuthService _authService = AuthService();

  Future<List<RideCommunityRide>> getRides() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureSeedData(prefs);
    final raw = (prefs.getString(_ridesKey) ?? '').trim();
    if (raw.isEmpty) return <RideCommunityRide>[];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((e) => RideCommunityRide.fromJson(e.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      }
    } catch (_) {}
    return <RideCommunityRide>[];
  }

  Future<void> createRide({
    required String title,
    required String city,
    required DateTime dateTime,
    required String startPoint,
    required String endPoint,
    required int maxRiders,
    required String whatsappLink,
    required String mapsLink,
    required String routePreview,
    required String emergencyContact,
    required String rideRules,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rides = await getRides();
    final organizerKey = await _currentUserKey();
    final organizerName = await _currentUserLabel();
    final ride = RideCommunityRide(
      id: 'ride_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      city: city,
      dateTime: dateTime,
      startPoint: startPoint,
      endPoint: endPoint,
      maxRiders: maxRiders,
      whatsappLink: whatsappLink,
      mapsLink: mapsLink,
      routePreview: routePreview,
      organizerId: organizerKey,
      organizerName: organizerName,
      emergencyContact: emergencyContact,
      rideRules: rideRules,
      createdAt: DateTime.now(),
      rewardLabel: 'Organizer reward: cashback + community coupon',
      safetyNote:
          'Ride safely. Follow local laws and wear proper safety gear. The app is not responsible for incidents or accidents.',
      participants: const [],
    );
    rides.insert(0, ride);
    await _saveRides(prefs, rides);
    await NotificationInboxService.instance.captureLocalAlert(
      title: 'Ride Published',
      body: '$title is now live in the community.',
      source: 'ride_community',
      data: const {'type': 'ride_created'},
    );
  }

  Future<void> requestToJoin(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final rides = await getRides();
    final userKey = await _currentUserKey();
    final riderName = await _currentUserLabel();
    final updated = rides.map((ride) {
      if (ride.id != rideId) return ride;
      final already = ride.participants.any((p) => p.userId == userKey);
      if (already) return ride;
      return ride.copyWith(
        participants: [
          ...ride.participants,
          RideParticipant(
            userId: userKey,
            userName: riderName,
            status: RideJoinStatus.pending,
            requestedAt: DateTime.now(),
          ),
        ],
      );
    }).toList();
    await _saveRides(prefs, updated);
    final ride = updated.firstWhere((r) => r.id == rideId);
    await NotificationInboxService.instance.captureLocalAlert(
      title: 'Ride Request Sent',
      body: 'Your request to join ${ride.title} is waiting for approval.',
      source: 'ride_community',
      data: const {'type': 'ride_request_sent'},
    );
  }

  Future<void> updateRequestStatus({
    required String rideId,
    required String userId,
    required RideJoinStatus status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rides = await getRides();
    RideCommunityRide? targetRide;
    final updated = rides.map((ride) {
      if (ride.id != rideId) return ride;
      targetRide = ride;
      final participants = ride.participants
          .map((participant) => participant.userId == userId
              ? participant.copyWith(status: status)
              : participant)
          .toList();
      return ride.copyWith(participants: participants);
    }).toList();
    await _saveRides(prefs, updated);
    if (targetRide != null) {
      await NotificationInboxService.instance.captureLocalAlert(
        title: status == RideJoinStatus.approved
            ? 'Ride Request Approved'
            : 'Ride Request Updated',
        body: status == RideJoinStatus.approved
            ? 'A rider was approved for ${targetRide!.title}.'
            : 'A ride request was updated for ${targetRide!.title}.',
        source: 'ride_community',
        data: const {'type': 'ride_request_update'},
      );
    }
  }

  Future<void> removeParticipant({
    required String rideId,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rides = await getRides();
    RideCommunityRide? targetRide;
    final updated = rides.map((ride) {
      if (ride.id != rideId) return ride;
      targetRide = ride;
      final participants = ride.participants
          .where((participant) => participant.userId != userId)
          .toList();
      return ride.copyWith(participants: participants);
    }).toList();
    await _saveRides(prefs, updated);
    if (targetRide != null) {
      await NotificationInboxService.instance.captureLocalAlert(
        title: 'Rider Removed',
        body: 'A rider was removed from ${targetRide!.title}.',
        source: 'ride_community',
        data: const {'type': 'ride_rider_removed'},
      );
    }
  }

  Future<void> deleteRide(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final rides = await getRides();
    final targetRide = rides.where((ride) => ride.id == rideId).toList();
    final updated = rides.where((ride) => ride.id != rideId).toList();
    await _saveRides(prefs, updated);

    final memories = await getRideMemories();
    final updatedMemories =
        memories.where((memory) => memory.rideId != rideId).toList();
    await prefs.setString(
      _memoriesKey,
      jsonEncode(updatedMemories.map((memory) => memory.toJson()).toList()),
    );

    if (targetRide.isNotEmpty) {
      await NotificationInboxService.instance.captureLocalAlert(
        title: 'Ride Deleted',
        body: '${targetRide.first.title} was removed from the community.',
        source: 'ride_community',
        data: const {'type': 'ride_deleted'},
      );
    }
  }

  Future<List<RideCommunityRide>> getJoinedRides() async {
    final userKey = await _currentUserKey();
    final rides = await getRides();
    return rides
        .where((ride) => ride.participants.any((p) => p.userId == userKey))
        .toList();
  }

  Future<List<RideCommunityRide>> getCreatedRides() async {
    final userKey = await _currentUserKey();
    final rides = await getRides();
    return rides.where((ride) => ride.organizerId == userKey).toList();
  }

  Future<List<RideMemorySubmission>> getRideMemories() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureMemorySeedData(prefs);
    final raw = (prefs.getString(_memoriesKey) ?? '').trim();
    if (raw.isEmpty) return <RideMemorySubmission>[];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((e) => RideMemorySubmission.fromJson(e.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      }
    } catch (_) {}
    return <RideMemorySubmission>[];
  }

  Future<void> updateMemoryStatus({
    required String memoryId,
    required RideMemoryStatus status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final memories = await getRideMemories();
    final updated = memories
        .map(
          (memory) => memory.id == memoryId
              ? memory.copyWith(status: status)
              : memory,
        )
        .toList();
    await prefs.setString(
      _memoriesKey,
      jsonEncode(updated.map((memory) => memory.toJson()).toList()),
    );
  }

  Future<Map<String, bool>> getAdminNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'new_ride_alerts': prefs.getBool(_newRideAlertsKey) ?? true,
      'ride_reminders': prefs.getBool(_rideRemindersKey) ?? true,
    };
  }

  Future<void> saveAdminNotificationSettings({
    bool? newRideAlerts,
    bool? rideReminders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (newRideAlerts != null) {
      await prefs.setBool(_newRideAlertsKey, newRideAlerts);
    }
    if (rideReminders != null) {
      await prefs.setBool(_rideRemindersKey, rideReminders);
    }
  }

  Future<String> currentUserKey() async {
    return _currentUserKey();
  }

  Future<String> _currentUserKey() async {
    final userId = (await _authService.getUserId() ?? '').trim();
    if (userId.isNotEmpty) return 'u:$userId';
    final prefs = await SharedPreferences.getInstance();
    final installId = (prefs.getString('anonymous_install_id') ?? '').trim();
    if (installId.isNotEmpty) return 'g:$installId';
    final generated = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('anonymous_install_id', generated);
    return 'g:$generated';
  }

  Future<String> _currentUserLabel() async {
    final userId = (await _authService.getUserId() ?? '').trim();
    if (userId.isNotEmpty) return 'Rider #$userId';
    return 'Guest Rider';
  }

  Future<void> _saveRides(
    SharedPreferences prefs,
    List<RideCommunityRide> rides,
  ) async {
    await prefs.setString(
      _ridesKey,
      jsonEncode(rides.map((ride) => ride.toJson()).toList()),
    );
  }

  Future<void> _ensureSeedData(SharedPreferences prefs) async {
    if (prefs.getBool(_seededKey) == true) return;
    final sample = <RideCommunityRide>[
      RideCommunityRide(
        id: 'ride_jaipur_sunday_breakfast',
        title: 'Jaipur Sunday Breakfast Ride',
        city: 'Jaipur',
        dateTime: DateTime.now().add(const Duration(days: 2, hours: 6)),
        startPoint: 'Patrakar Colony Circle',
        endPoint: 'Samode Bagh Breakfast Point',
        maxRiders: 18,
        whatsappLink: 'https://chat.whatsapp.com/jaipur-riders-breakfast',
        mapsLink:
            'https://www.google.com/maps/search/?api=1&query=Patrakar+Colony+Circle+Jaipur',
        routePreview: 'Ajmer Road warm-up, open highway pull, breakfast stop at Samode side',
        organizerId: 'u:rahul_shekhawat',
        organizerName: 'Rahul Shekhawat',
        emergencyContact: '+91 98290 44112',
        rideRules:
            'Full-face helmet required, no overtaking inside the group, arrive 15 minutes early, fuel up before rollout.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        rewardLabel: 'Organizer reward: featured organizer badge + breakfast coupon',
        safetyNote:
            'Ride safely. Follow local laws and wear proper safety gear. The app is not responsible for incidents or accidents.',
        participants: [
          RideParticipant(userId: 'r_jpr_1', userName: 'Amit Gurjar', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 10, 0)),
          RideParticipant(userId: 'r_jpr_2', userName: 'Deepak Meena', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 10, 30)),
          RideParticipant(userId: 'r_jpr_3', userName: 'Karan Choudhary', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 11, 15)),
          RideParticipant(userId: 'r_jpr_4', userName: 'Nitin Saini', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 12, 0)),
          RideParticipant(userId: 'r_jpr_5', userName: 'Piyush Sharma', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 12, 30)),
          RideParticipant(userId: 'r_jpr_6', userName: 'Rohit Jangid', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 13, 0)),
          RideParticipant(userId: 'r_jpr_7', userName: 'Sandeep Khandelwal', status: RideJoinStatus.pending, requestedAt: DateTime.utc(2026, 3, 25, 8, 0)),
        ],
      ),
      RideCommunityRide(
        id: 'ride_delhi_night_murthal',
        title: 'Delhi Night Ride to Murthal',
        city: 'Delhi',
        dateTime: DateTime.now().add(const Duration(days: 4, hours: 20)),
        startPoint: 'India Gate',
        endPoint: 'Murthal Stop',
        maxRiders: 25,
        whatsappLink: 'https://chat.whatsapp.com/delhi-night-murthal',
        mapsLink:
            'https://www.google.com/maps/search/?api=1&query=India+Gate+Delhi',
        routePreview: 'India Gate meet-up, outer ring exit, expressway cruise, Murthal food stop',
        organizerId: 'u:arjun_malhotra',
        organizerName: 'Arjun Malhotra',
        emergencyContact: '+91 98110 24761',
        rideRules:
            'No stunts, reflective jacket preferred, fuel tank above half, lane discipline mandatory.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        rewardLabel: 'Organizer reward: riding gloves voucher + featured story',
        safetyNote:
            'Ride safely. Follow local laws and wear proper safety gear. The app is not responsible for incidents or accidents.',
        participants: [
          RideParticipant(userId: 'r_del_1', userName: 'Sahil Verma', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 23, 18, 0)),
          RideParticipant(userId: 'r_del_2', userName: 'Harsh Batra', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 23, 18, 10)),
          RideParticipant(userId: 'r_del_3', userName: 'Rajat Khanna', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 23, 18, 25)),
          RideParticipant(userId: 'r_del_4', userName: 'Vikram Dahiya', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 23, 18, 40)),
          RideParticipant(userId: 'r_del_5', userName: 'Yash Oberoi', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 23, 19, 5)),
          RideParticipant(userId: 'r_del_6', userName: 'Mohit Rana', status: RideJoinStatus.pending, requestedAt: DateTime.utc(2026, 3, 25, 7, 45)),
        ],
      ),
      RideCommunityRide(
        id: 'ride_udaipur_lakeside_loop',
        title: 'Udaipur Lakeside Evening Loop',
        city: 'Udaipur',
        dateTime: DateTime.now().add(const Duration(days: 6, hours: 17)),
        startPoint: 'Fateh Sagar Pal',
        endPoint: 'Badi Lake View Point',
        maxRiders: 15,
        whatsappLink: 'https://chat.whatsapp.com/udaipur-lakeside-loop',
        mapsLink:
            'https://www.google.com/maps/search/?api=1&query=Fateh+Sagar+Pal+Udaipur',
        routePreview: 'Lakefront cruise, city bypass, sunset halt near Badi Lake',
        organizerId: 'u:manav_purohit',
        organizerName: 'Manav Purohit',
        emergencyContact: '+91 97722 51084',
        rideRules:
            'No loud revving in city zones, keep formation clean, sunset halt only at marked point.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        rewardLabel: 'Organizer reward: community spotlight + fuel coupon',
        safetyNote:
            'Ride safely. Follow local laws and wear proper safety gear. The app is not responsible for incidents or accidents.',
        participants: [
          RideParticipant(userId: 'r_udp_1', userName: 'Lakshya Joshi', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 9, 30)),
          RideParticipant(userId: 'r_udp_2', userName: 'Dev Solanki', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 10, 5)),
          RideParticipant(userId: 'r_udp_3', userName: 'Pranav Sisodia', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 24, 10, 20)),
          RideParticipant(userId: 'r_udp_4', userName: 'Rishabh Trivedi', status: RideJoinStatus.pending, requestedAt: DateTime.utc(2026, 3, 25, 9, 15)),
        ],
      ),
      RideCommunityRide(
        id: 'ride_jaipur_nahargarh_completed',
        title: 'Nahargarh Sunrise Climb',
        city: 'Jaipur',
        dateTime: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
        startPoint: 'Jal Mahal Parking',
        endPoint: 'Nahargarh Fort',
        maxRiders: 16,
        whatsappLink: 'https://chat.whatsapp.com/jaipur-nahargarh-completed',
        mapsLink:
            'https://www.google.com/maps/search/?api=1&query=Jal+Mahal+Jaipur',
        routePreview: 'Early climb, fort viewpoint stop, group breakfast finish',
        organizerId: 'u:chetan_rathore',
        organizerName: 'Chetan Rathore',
        emergencyContact: '+91 98876 11234',
        rideRules:
            'Tight uphill formation, no risky overtakes, descent in staggered order.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        rewardLabel: 'Organizer reward: top organizer leaderboard points',
        safetyNote:
            'Ride safely. Follow local laws and wear proper safety gear. The app is not responsible for incidents or accidents.',
        participants: [
          RideParticipant(userId: 'r_cmp_1', userName: 'Ankit Sharma', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 20, 7, 0)),
          RideParticipant(userId: 'r_cmp_2', userName: 'Bhavesh Tanwar', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 20, 7, 10)),
          RideParticipant(userId: 'r_cmp_3', userName: 'Dhruv Rajawat', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 20, 7, 20)),
          RideParticipant(userId: 'r_cmp_4', userName: 'Gaurav Pareek', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 20, 7, 40)),
          RideParticipant(userId: 'r_cmp_5', userName: 'Tushar Vyas', status: RideJoinStatus.approved, requestedAt: DateTime.utc(2026, 3, 20, 8, 0)),
        ],
      ),
    ];
    await _saveRides(prefs, sample);
    await prefs.setBool(_seededKey, true);
  }

  Future<void> _ensureMemorySeedData(SharedPreferences prefs) async {
    if (prefs.getBool(_memoriesSeededKey) == true) return;
    final sample = <RideMemorySubmission>[
      RideMemorySubmission(
        id: 'memory_jaipur_breakfast_1',
        rideId: 'ride_jaipur_sunday_breakfast',
        rideTitle: 'Jaipur Sunday Breakfast Ride',
        submittedBy: 'Amit Gurjar',
        mediaType: 'photo',
        previewLabel: 'Highway breakfast stop group shot',
        status: RideMemoryStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      RideMemorySubmission(
        id: 'memory_delhi_murthal_1',
        rideId: 'ride_delhi_night_murthal',
        rideTitle: 'Delhi Night Ride to Murthal',
        submittedBy: 'Vikram Dahiya',
        mediaType: 'video',
        previewLabel: 'Murthal arrival reel',
        status: RideMemoryStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      RideMemorySubmission(
        id: 'memory_completed_jaipur_1',
        rideId: 'ride_jaipur_nahargarh_completed',
        rideTitle: 'Nahargarh Sunrise Climb',
        submittedBy: 'Ankit Sharma',
        mediaType: 'photo',
        previewLabel: 'Completed ride fort lookout photo set',
        status: RideMemoryStatus.approved,
        submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    await prefs.setString(
      _memoriesKey,
      jsonEncode(sample.map((memory) => memory.toJson()).toList()),
    );
    await prefs.setBool(_memoriesSeededKey, true);
  }
}

class RideCommunityRide {
  const RideCommunityRide({
    required this.id,
    required this.title,
    required this.city,
    required this.dateTime,
    required this.startPoint,
    required this.endPoint,
    required this.maxRiders,
    required this.whatsappLink,
    required this.mapsLink,
    required this.routePreview,
    required this.organizerId,
    required this.organizerName,
    required this.emergencyContact,
    required this.rideRules,
    required this.createdAt,
    required this.rewardLabel,
    required this.safetyNote,
    required this.participants,
  });

  final String id;
  final String title;
  final String city;
  final DateTime dateTime;
  final String startPoint;
  final String endPoint;
  final int maxRiders;
  final String whatsappLink;
  final String mapsLink;
  final String routePreview;
  final String organizerId;
  final String organizerName;
  final String emergencyContact;
  final String rideRules;
  final DateTime createdAt;
  final String rewardLabel;
  final String safetyNote;
  final List<RideParticipant> participants;

  int get approvedCount =>
      participants.where((p) => p.status == RideJoinStatus.approved).length;

  int get pendingCount =>
      participants.where((p) => p.status == RideJoinStatus.pending).length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'city': city,
      'date_time': dateTime.toIso8601String(),
      'start_point': startPoint,
      'end_point': endPoint,
      'max_riders': maxRiders,
      'whatsapp_link': whatsappLink,
      'maps_link': mapsLink,
      'route_preview': routePreview,
      'organizer_id': organizerId,
      'organizer_name': organizerName,
      'emergency_contact': emergencyContact,
      'ride_rules': rideRules,
      'created_at': createdAt.toIso8601String(),
      'reward_label': rewardLabel,
      'safety_note': safetyNote,
      'participants': participants.map((e) => e.toJson()).toList(),
    };
  }

  factory RideCommunityRide.fromJson(Map<String, dynamic> json) {
    return RideCommunityRide(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      dateTime: DateTime.tryParse((json['date_time'] ?? '').toString()) ??
          DateTime.now(),
      startPoint: (json['start_point'] ?? '').toString(),
      endPoint: (json['end_point'] ?? '').toString(),
      maxRiders: int.tryParse((json['max_riders'] ?? '0').toString()) ?? 0,
      whatsappLink: (json['whatsapp_link'] ?? '').toString(),
      mapsLink: (json['maps_link'] ?? '').toString(),
      routePreview: (json['route_preview'] ?? '').toString(),
      organizerId: (json['organizer_id'] ?? '').toString(),
      organizerName: (json['organizer_name'] ?? '').toString(),
      emergencyContact: (json['emergency_contact'] ?? '').toString(),
      rideRules: (json['ride_rules'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      rewardLabel: (json['reward_label'] ?? '').toString(),
      safetyNote: (json['safety_note'] ?? '').toString(),
      participants: ((json['participants'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RideParticipant.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  RideCommunityRide copyWith({
    List<RideParticipant>? participants,
  }) {
    return RideCommunityRide(
      id: id,
      title: title,
      city: city,
      dateTime: dateTime,
      startPoint: startPoint,
      endPoint: endPoint,
      maxRiders: maxRiders,
      whatsappLink: whatsappLink,
      mapsLink: mapsLink,
      routePreview: routePreview,
      organizerId: organizerId,
      organizerName: organizerName,
      emergencyContact: emergencyContact,
      rideRules: rideRules,
      createdAt: createdAt,
      rewardLabel: rewardLabel,
      safetyNote: safetyNote,
      participants: participants ?? this.participants,
    );
  }
}

class RideParticipant {
  const RideParticipant({
    required this.userId,
    required this.userName,
    required this.status,
    required this.requestedAt,
  });

  final String userId;
  final String userName;
  final RideJoinStatus status;
  final DateTime requestedAt;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'status': status.name,
      'requested_at': requestedAt.toIso8601String(),
    };
  }

  factory RideParticipant.fromJson(Map<String, dynamic> json) {
    return RideParticipant(
      userId: (json['user_id'] ?? '').toString(),
      userName: (json['user_name'] ?? '').toString(),
      status: RideJoinStatus.values.firstWhere(
        (value) => value.name == (json['status'] ?? '').toString(),
        orElse: () => RideJoinStatus.pending,
      ),
      requestedAt: DateTime.tryParse((json['requested_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  RideParticipant copyWith({
    RideJoinStatus? status,
  }) {
    return RideParticipant(
      userId: userId,
      userName: userName,
      status: status ?? this.status,
      requestedAt: requestedAt,
    );
  }
}

enum RideJoinStatus { pending, approved, declined }

class RideMemorySubmission {
  const RideMemorySubmission({
    required this.id,
    required this.rideId,
    required this.rideTitle,
    required this.submittedBy,
    required this.mediaType,
    required this.previewLabel,
    required this.status,
    required this.submittedAt,
  });

  final String id;
  final String rideId;
  final String rideTitle;
  final String submittedBy;
  final String mediaType;
  final String previewLabel;
  final RideMemoryStatus status;
  final DateTime submittedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'ride_title': rideTitle,
      'submitted_by': submittedBy,
      'media_type': mediaType,
      'preview_label': previewLabel,
      'status': status.name,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }

  factory RideMemorySubmission.fromJson(Map<String, dynamic> json) {
    return RideMemorySubmission(
      id: (json['id'] ?? '').toString(),
      rideId: (json['ride_id'] ?? '').toString(),
      rideTitle: (json['ride_title'] ?? '').toString(),
      submittedBy: (json['submitted_by'] ?? '').toString(),
      mediaType: (json['media_type'] ?? '').toString(),
      previewLabel: (json['preview_label'] ?? '').toString(),
      status: RideMemoryStatus.values.firstWhere(
        (value) => value.name == (json['status'] ?? '').toString(),
        orElse: () => RideMemoryStatus.pending,
      ),
      submittedAt: DateTime.tryParse((json['submitted_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  RideMemorySubmission copyWith({
    RideMemoryStatus? status,
  }) {
    return RideMemorySubmission(
      id: id,
      rideId: rideId,
      rideTitle: rideTitle,
      submittedBy: submittedBy,
      mediaType: mediaType,
      previewLabel: previewLabel,
      status: status ?? this.status,
      submittedAt: submittedAt,
    );
  }
}

enum RideMemoryStatus { pending, approved, rejected }
