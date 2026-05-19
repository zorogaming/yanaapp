import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class RidingGroupsService {
  RidingGroupsService._();

  static final RidingGroupsService instance = RidingGroupsService._();

  static const String _groupsKey = 'riding_groups_directory_v2';
  static const String _groupsSeededKey = 'riding_groups_directory_seeded_v2';
  static const String _reportsKey = 'riding_groups_reports_v1';

  final AuthService _authService = AuthService();

  Future<List<RidingGroup>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureSeedData(prefs);
    final raw = (prefs.getString(_groupsKey) ?? '').trim();
    if (raw.isEmpty) return <RidingGroup>[];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((item) => RidingGroup.fromJson(item.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.city.compareTo(b.city));
      }
    } catch (_) {}
    return <RidingGroup>[];
  }

  Future<void> createGroup({
    required String name,
    required String city,
    required String description,
    required String bikeType,
    required String instagramHandle,
    required String joinType,
    required String whatsappLink,
    required String adminPhone,
    required String profileImage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await getGroups();
    final userId = await currentUserId();
    final userLabel = await currentUserLabel();
    final group = RidingGroup(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      city: city,
      description: description,
      bikeType: bikeType,
      instagramHandle: instagramHandle,
      joinType: joinType,
      whatsappLink: whatsappLink,
      adminPhone: adminPhone,
      profileImage: profileImage,
      adminUserId: userId,
      adminName: userLabel,
      joinedUserIds: <String>[userId],
      ratings: const [],
      isDisabled: false,
    );
    groups.insert(0, group);
    await _saveGroups(prefs, groups);
  }

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String city,
    required String description,
    required String bikeType,
    required String instagramHandle,
    required String joinType,
    required String whatsappLink,
    required String adminPhone,
    required String profileImage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await getGroups();
    final updated = groups.map((group) {
      if (group.id != groupId) return group;
      return group.copyWith(
        name: name,
        city: city,
        description: description,
        bikeType: bikeType,
        instagramHandle: instagramHandle,
        joinType: joinType,
        whatsappLink: whatsappLink,
        adminPhone: adminPhone,
        profileImage: profileImage,
      );
    }).toList();
    await _saveGroups(prefs, updated);
  }

  Future<void> deleteGroup(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await getGroups();
    final updated = groups.where((group) => group.id != groupId).toList();
    await _saveGroups(prefs, updated);

    final reports = await getReports();
    final updatedReports =
        reports.where((report) => report.groupId != groupId).toList();
    await prefs.setString(
      _reportsKey,
      jsonEncode(updatedReports.map((report) => report.toJson()).toList()),
    );
  }

  Future<void> setGroupDisabled({
    required String groupId,
    required bool disabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await getGroups();
    final updated = groups.map((group) {
      if (group.id != groupId) return group;
      return group.copyWith(isDisabled: disabled);
    }).toList();
    await _saveGroups(prefs, updated);
  }

  Future<void> joinGroup(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await getGroups();
    final userId = await currentUserId();
    final updated = groups.map((group) {
      if (group.id != groupId) return group;
      if (group.joinedUserIds.contains(userId)) return group;
      return group.copyWith(joinedUserIds: [...group.joinedUserIds, userId]);
    }).toList();
    await _saveGroups(prefs, updated);
  }

  Future<void> submitRating({
    required String groupId,
    required int stars,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await getGroups();
    final userId = await currentUserId();
    final updated = groups.map((group) {
      if (group.id != groupId) return group;
      final ratings = group.ratings
          .where((rating) => rating.userId != userId)
          .toList();
      ratings.add(GroupRating(userId: userId, stars: stars));
      return group.copyWith(ratings: ratings);
    }).toList();
    await _saveGroups(prefs, updated);
  }

  Future<void> reportGroup({
    required String groupId,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await getReports();
    final userId = await currentUserId();
    reports.insert(
      0,
      GroupReport(
        id: 'report_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        userId: userId,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );
    await prefs.setString(
      _reportsKey,
      jsonEncode(reports.map((report) => report.toJson()).toList()),
    );
  }

  Future<List<GroupReport>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_reportsKey) ?? '').trim();
    if (raw.isEmpty) return <GroupReport>[];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((item) => GroupReport.fromJson(item.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (_) {}
    return <GroupReport>[];
  }

  Future<List<RidingGroup>> getMyGroups() async {
    final userId = await currentUserId();
    final groups = await getGroups();
    return groups.where((group) => group.adminUserId == userId).toList();
  }

  Future<String?> getToken() => _authService.getToken();

  Future<String> currentUserId() async {
    final userId = (await _authService.getUserId() ?? '').trim();
    return userId.isEmpty ? 'guest' : userId;
  }

  Future<String> currentUserLabel() async {
    final userId = (await _authService.getUserId() ?? '').trim();
    return userId.isEmpty ? 'Group Owner' : 'User #$userId';
  }

  Future<void> _saveGroups(
    SharedPreferences prefs,
    List<RidingGroup> groups,
  ) async {
    await prefs.setString(
      _groupsKey,
      jsonEncode(groups.map((group) => group.toJson()).toList()),
    );
  }

  Future<void> _ensureSeedData(SharedPreferences prefs) async {
    if (prefs.getBool(_groupsSeededKey) == true) return;
    final rawGroups = const [
      {'name': 'India Bull Riders', 'city': 'Pan India', 'instagram': '@indiabullriders'},
      {'name': 'Bikers Brotherhood Club', 'city': 'Delhi', 'instagram': '@bikersbrotherhoodclub'},
      {'name': 'Mumbai Riders Club', 'city': 'Mumbai', 'instagram': '@mumbairidersclub'},
      {'name': 'Pune Motorcycle Club', 'city': 'Pune', 'instagram': '@punemotorcycleclubofficial'},
      {'name': 'Goa Motorcycle Club', 'city': 'Goa', 'instagram': '@goa.mc'},
      {'name': 'The Bikerni', 'city': 'Pan India', 'instagram': '@thebikerni'},
      {'name': 'Wheels Of Lost Freedom', 'city': 'Delhi', 'instagram': '@wheels_of_lost_freedom'},
      {'name': 'The Brave Riders', 'city': 'Bangalore', 'instagram': '@thebraveridersindia'},
      {'name': 'Community Riders Federation', 'city': 'Pan India', 'instagram': '@crf_motorcycle_club'},
      {'name': 'Riders Brotherhood Club', 'city': 'Mumbai', 'instagram': '@ridersbrotherhoodclub'},
      {'name': 'D Town Riders Club', 'city': 'Hyderabad', 'instagram': '@dtownridersclub'},
      {'name': 'GODS Superbikers', 'city': 'Delhi', 'instagram': '@groupofdelhisuperbikers'},
      {'name': 'M17 Bikers Club', 'city': 'Mumbai', 'instagram': '@m17bikersclubmumbai'},
      {'name': 'Indian Bikers Club', 'city': 'Pan India', 'instagram': '@indian_bikers_club_'},
      {'name': 'Diverse Rider Alliance', 'city': 'Pan India', 'instagram': '@diverse_rider_alliance'},
      {'name': 'All India Bikers Community', 'city': 'Pan India', 'instagram': '@allindiabikerscommunity'},
      {'name': 'Madras Bulls', 'city': 'Chennai', 'instagram': '@madrasbulls'},
      {'name': 'Road Thrill', 'city': 'Delhi', 'instagram': '@roadthrill'},
      {'name': 'Bullet Buddhas', 'city': 'Kochi', 'instagram': '@bulletbuddhas'},
      {'name': 'GEARS Goa', 'city': 'Goa', 'instagram': '@gears_goa'},
      {'name': 'Bangalore Riders Club', 'city': 'Bangalore', 'instagram': '@bangaloreridersclub'},
      {'name': 'Delhi Night Riders', 'city': 'Delhi', 'instagram': '@delhinightriders'},
      {'name': 'Jaipur Riders Club', 'city': 'Jaipur', 'instagram': '@jaipurridersclub'},
      {'name': 'Udaipur Riders', 'city': 'Udaipur', 'instagram': '@udaipurriders'},
      {'name': 'Kolkata Bikers', 'city': 'Kolkata', 'instagram': '@kolkatabikers'},
      {'name': 'Ahmedabad Riders Club', 'city': 'Ahmedabad', 'instagram': '@ahmedabadridersclub'},
      {'name': 'Surat Riders', 'city': 'Surat', 'instagram': '@suratriders'},
      {'name': 'Nagpur Riders', 'city': 'Nagpur', 'instagram': '@nagpurriders'},
      {'name': 'Lucknow Bikers Club', 'city': 'Lucknow', 'instagram': '@lucknowbikersclub'},
      {'name': 'Chandigarh Riders Club', 'city': 'Chandigarh', 'instagram': '@chandigarhridersclub'},
      {'name': 'Dehradun Riders Club', 'city': 'Dehradun', 'instagram': '@dehradunridersclub'},
      {'name': 'Manali Riders Club', 'city': 'Manali', 'instagram': '@manaliridersclub'},
      {'name': 'Leh Riders Club', 'city': 'Leh', 'instagram': '@lehridersclub'},
      {'name': 'Goa Riders United', 'city': 'Goa', 'instagram': '@goaridersunited'},
      {'name': 'Kerala Riders', 'city': 'Kerala', 'instagram': '@keralariders'},
      {'name': 'Trivandrum Riders', 'city': 'Trivandrum', 'instagram': '@trivandrumriders'},
      {'name': 'Mysore Riders', 'city': 'Mysore', 'instagram': '@mysoreriders'},
      {'name': 'Coimbatore Riders', 'city': 'Coimbatore', 'instagram': '@coimbatoreriders'},
      {'name': 'Hyderabad Bikers', 'city': 'Hyderabad', 'instagram': '@hyderabadbikers'},
      {'name': 'Vizag Riders', 'city': 'Vizag', 'instagram': '@vizagriders'},
      {'name': 'Patna Riders Club', 'city': 'Patna', 'instagram': '@patnaridersclub'},
      {'name': 'Ranchi Riders', 'city': 'Ranchi', 'instagram': '@ranchiriders'},
      {'name': 'Raipur Riders', 'city': 'Raipur', 'instagram': '@raipurriders'},
      {'name': 'Bhopal Riders Club', 'city': 'Bhopal', 'instagram': '@bhopalridersclub'},
      {'name': 'Indore Riders', 'city': 'Indore', 'instagram': '@indoreriders'},
      {'name': 'Gwalior Riders', 'city': 'Gwalior', 'instagram': '@gwaliorriders'},
      {'name': 'Agra Riders Club', 'city': 'Agra', 'instagram': '@agraridersclub'},
      {'name': 'Varanasi Riders', 'city': 'Varanasi', 'instagram': '@varanasiriders'},
      {'name': 'Noida Riders', 'city': 'Noida', 'instagram': '@noidariders'},
      {'name': 'Gurgaon Riders', 'city': 'Gurgaon', 'instagram': '@gurgaonriders'},
    ];
    final sample = <RidingGroup>[];
    for (var i = 0; i < rawGroups.length; i++) {
      final item = rawGroups[i];
      final name = (item['name'] ?? '').toString();
      final city = (item['city'] ?? '').toString();
      final instagram = (item['instagram'] ?? '').toString();
      sample.add(
        RidingGroup(
          id: 'group_seed_$i',
          name: name,
          city: city,
          description:
              '$name is listed in the Yana riding groups directory for $city riders. Join through Instagram DM and connect with the admin team.',
          bikeType: 'Mixed',
          instagramHandle: instagram,
          joinType: 'DM on Instagram',
          whatsappLink: '',
          adminPhone: '',
          profileImage: '',
          adminUserId: 'seed_owner_$i',
          adminName: name,
          joinedUserIds: <String>['seed_owner_$i'],
          ratings: const [
            GroupRating(userId: 'seed_rating_1', stars: 4),
            GroupRating(userId: 'seed_rating_2', stars: 5),
          ],
          isDisabled: false,
        ),
      );
    }
    await _saveGroups(prefs, sample);
    await prefs.setString(_reportsKey, '[]');
    await prefs.setBool(_groupsSeededKey, true);
  }
}

class RidingGroup {
  const RidingGroup({
    required this.id,
    required this.name,
    required this.city,
    required this.description,
    required this.bikeType,
    required this.instagramHandle,
    required this.joinType,
    required this.whatsappLink,
    required this.adminPhone,
    required this.profileImage,
    required this.adminUserId,
    required this.adminName,
    required this.joinedUserIds,
    required this.ratings,
    required this.isDisabled,
  });

  final String id;
  final String name;
  final String city;
  final String description;
  final String bikeType;
  final String instagramHandle;
  final String joinType;
  final String whatsappLink;
  final String adminPhone;
  final String profileImage;
  final String adminUserId;
  final String adminName;
  final List<String> joinedUserIds;
  final List<GroupRating> ratings;
  final bool isDisabled;

  int get membersCount => joinedUserIds.length;

  double get averageRating {
    if (ratings.isEmpty) return 0;
    final total = ratings.fold<int>(0, (sum, rating) => sum + rating.stars);
    return total / ratings.length;
  }

  bool hasUserJoined(String userId) => joinedUserIds.contains(userId);

  int? ratingByUser(String userId) {
    for (final rating in ratings) {
      if (rating.userId == userId) return rating.stars;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'description': description,
      'bike_type': bikeType,
      'instagram_handle': instagramHandle,
      'join_type': joinType,
      'whatsapp_link': whatsappLink,
      'admin_phone': adminPhone,
      'profile_image': profileImage,
      'admin_user_id': adminUserId,
      'admin_name': adminName,
      'joined_user_ids': joinedUserIds,
      'ratings': ratings.map((rating) => rating.toJson()).toList(),
      'is_disabled': isDisabled,
    };
  }

  factory RidingGroup.fromJson(Map<String, dynamic> json) {
    return RidingGroup(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      bikeType: (json['bike_type'] ?? '').toString(),
      instagramHandle: (json['instagram_handle'] ?? '').toString(),
      joinType: (json['join_type'] ?? '').toString(),
      whatsappLink: (json['whatsapp_link'] ?? '').toString(),
      adminPhone: (json['admin_phone'] ?? '').toString(),
      profileImage: (json['profile_image'] ?? '').toString(),
      adminUserId: (json['admin_user_id'] ?? '').toString(),
      adminName: (json['admin_name'] ?? '').toString(),
      joinedUserIds: ((json['joined_user_ids'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      ratings: ((json['ratings'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => GroupRating.fromJson(item.cast<String, dynamic>()))
          .toList(),
      isDisabled: json['is_disabled'] == true,
    );
  }

  RidingGroup copyWith({
    String? name,
    String? city,
    String? description,
    String? bikeType,
    String? instagramHandle,
    String? joinType,
    String? whatsappLink,
    String? adminPhone,
    String? profileImage,
    List<String>? joinedUserIds,
    List<GroupRating>? ratings,
    bool? isDisabled,
  }) {
    return RidingGroup(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      description: description ?? this.description,
      bikeType: bikeType ?? this.bikeType,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      joinType: joinType ?? this.joinType,
      whatsappLink: whatsappLink ?? this.whatsappLink,
      adminPhone: adminPhone ?? this.adminPhone,
      profileImage: profileImage ?? this.profileImage,
      adminUserId: adminUserId,
      adminName: adminName,
      joinedUserIds: joinedUserIds ?? this.joinedUserIds,
      ratings: ratings ?? this.ratings,
      isDisabled: isDisabled ?? this.isDisabled,
    );
  }
}

class GroupRating {
  const GroupRating({
    required this.userId,
    required this.stars,
  });

  final String userId;
  final int stars;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'stars': stars,
    };
  }

  factory GroupRating.fromJson(Map<String, dynamic> json) {
    return GroupRating(
      userId: (json['user_id'] ?? '').toString(),
      stars: int.tryParse((json['stars'] ?? '0').toString()) ?? 0,
    );
  }
}

class GroupReport {
  const GroupReport({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final String reason;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GroupReport.fromJson(Map<String, dynamic> json) {
    return GroupReport(
      id: (json['id'] ?? '').toString(),
      groupId: (json['group_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
