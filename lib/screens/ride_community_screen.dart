import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ride_community_service.dart';
import '../theme/app_theme.dart';

class RideCommunityScreen extends StatefulWidget {
  const RideCommunityScreen({super.key});

  @override
  State<RideCommunityScreen> createState() => _RideCommunityScreenState();
}

class _RideCommunityScreenState extends State<RideCommunityScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF0D0D0D);
  static const Color _panel = Color(0xFF171717);
  static const Color _accent = Color(0xFFD7FC70);
  static const Color _gold = Color(0xFFD7FC70);
  AppThemePalette get palette => context.appPalette;

  late final TabController _tabController;
  late Future<List<RideCommunityRide>> _ridesFuture;

  final _titleController = TextEditingController();
  final _cityController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _maxRidersController = TextEditingController(text: '20');
  final _whatsappController = TextEditingController();
  final _mapsController = TextEditingController();
  final _routeController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _rulesController = TextEditingController();

  String _selectedCity = 'All Cities';
  bool _acceptSafetyTerms = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ridesFuture = RideCommunityService.instance.getRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _cityController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _startController.dispose();
    _endController.dispose();
    _maxRidersController.dispose();
    _whatsappController.dispose();
    _mapsController.dispose();
    _routeController.dispose();
    _emergencyController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text('Ride Community', style: TextStyle(color: palette.textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: palette.accent,
          labelColor: palette.textPrimary,
          unselectedLabelColor: palette.textMuted,
          tabs: const [
            Tab(text: 'Upcoming Rides'),
            Tab(text: 'Create Ride'),
            Tab(text: 'My Rides'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingTab(),
          _buildCreateTab(),
          _buildMyRidesTab(),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab() {
    return FutureBuilder<List<RideCommunityRide>>(
      future: _ridesFuture,
      builder: (context, snapshot) {
        final rides = snapshot.data ?? const <RideCommunityRide>[];
        final cities = <String>{
          'All Cities',
          ...rides.map((ride) => ride.city).where((city) => city.trim().isNotEmpty),
        }.toList();
        final visibleRides = _selectedCity == 'All Cities'
            ? rides
            : rides.where((ride) => ride.city == _selectedCity).toList();

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _heroBanner(),
              const SizedBox(height: 16),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final city = cities[index];
                    final selected = city == _selectedCity;
                    return ChoiceChip(
                      label: Text(city),
                      selected: selected,
                      selectedColor: palette.accent,
                      backgroundColor: palette.surface,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() => _selectedCity = city),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _communityHighlights(rides),
              const SizedBox(height: 16),
              if (visibleRides.isEmpty)
                _emptyCard(
                  'No rides found for this city yet. Switch cities or create the next ride.',
                )
              else
                ...visibleRides.map(
                  (ride) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _rideCard(ride: ride, allowOrganizerActions: false),
                  ),
                ),
              const SizedBox(height: 6),
              _safetyCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _sectionCard(
          title: 'Create a New Ride',
          subtitle:
              'Publish a community ride with route details, rider limits, WhatsApp access, and safety information.',
          child: Column(
            children: [
              _field(_titleController, 'Ride Name'),
              const SizedBox(height: 12),
              _field(_cityController, 'City'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_dateController, 'Date (DD/MM/YYYY)')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_timeController, 'Time (07:00 AM)')),
                ],
              ),
              const SizedBox(height: 12),
              _field(_startController, 'Starting Point'),
              const SizedBox(height: 12),
              _field(_endController, 'Ending Point'),
              const SizedBox(height: 12),
              _field(_maxRidersController, 'Max Riders', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _field(_whatsappController, 'WhatsApp Group Link'),
              const SizedBox(height: 12),
              _field(_mapsController, 'Google Maps Link'),
              const SizedBox(height: 12),
              _field(_routeController, 'Route Preview'),
              const SizedBox(height: 12),
              _field(_emergencyController, 'Emergency Contact'),
              const SizedBox(height: 12),
              _field(_rulesController, 'Ride Rules', maxLines: 4),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptSafetyTerms,
                activeColor: _accent,
                onChanged: (value) =>
                    setState(() => _acceptSafetyTerms = value ?? false),
                title: const Text(
                  'I agree to show safety rules and the accident disclaimer for this ride.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleCreateRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_submitting ? 'Publishing...' : 'Publish Ride'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyRidesTab() {
    return FutureBuilder<List<List<RideCommunityRide>>>(
      future: Future.wait([
        RideCommunityService.instance.getJoinedRides(),
        RideCommunityService.instance.getCreatedRides(),
      ]),
      builder: (context, snapshot) {
        final joined = snapshot.data?.isNotEmpty == true
            ? snapshot.data!.first
            : const <RideCommunityRide>[];
        final created = snapshot.data?.length == 2
            ? snapshot.data![1]
            : const <RideCommunityRide>[];

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _sectionCard(
                title: 'My Joined Rides',
                subtitle: 'Track approvals, reminders, and quick WhatsApp access.',
                child: joined.isEmpty
                    ? _emptyCard('You have not joined any rides yet.')
                    : Column(
                        children: joined
                            .map(
                              (ride) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _rideCard(
                                  ride: ride,
                                  allowOrganizerActions: false,
                                  compact: true,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'My Created Rides',
                subtitle:
                    'Approve requests, manage your community, and track organizer rewards.',
                child: created.isEmpty
                    ? _emptyCard('You have not created any rides yet.')
                    : Column(
                        children: created
                            .map(
                              (ride) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _rideCard(
                                  ride: ride,
                                  allowOrganizerActions: true,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Community Power-Ups',
                subtitle:
                    'Extra features that give the planner a true riding-community feel.',
                child: Column(
                  children: [
                    _miniFeature(
                      'Leaderboard',
                      'Highlight top organizers and the most active riders.',
                    ),
                    _miniFeature(
                      'Ride Memories',
                      'Add ride photos and videos after every event for social momentum.',
                    ),
                    _miniFeature(
                      'Safety Hub',
                      'Keep emergency contacts, ride rules, and discipline visible to every rider.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF182134), Color(0xFF111522), Color(0xFF2A160A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join Riding Community',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Discover city rides, request to join, create your own route, and move the whole crew to WhatsApp after approval.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _communityHighlights(List<RideCommunityRide> rides) {
    final totalApproved =
        rides.fold<int>(0, (sum, ride) => sum + ride.approvedCount);
    final topOrganizer =
        rides.isEmpty ? 'Community Team' : rides.first.organizerName;
    return _sectionCard(
      title: 'Community Highlights',
      subtitle: 'Built to increase repeat usage, trust, and rider retention.',
      child: Row(
        children: [
          Expanded(child: _statTile('Top Organizer', topOrganizer)),
          const SizedBox(width: 10),
          Expanded(child: _statTile('Active Riders', '$totalApproved joined')),
        ],
      ),
    );
  }

  Widget _rideCard({
    required RideCommunityRide ride,
    required bool allowOrganizerActions,
    bool compact = false,
  }) {
    return FutureBuilder<String>(
      future: RideCommunityService.instance.currentUserKey(),
      builder: (context, snapshot) {
        final currentUserId = snapshot.data ?? '';
        RideParticipant? myRequest;
        for (final participant in ride.participants) {
          if (participant.userId == currentUserId) {
            myRequest = participant;
            break;
          }
        }
        final canRequest = myRequest == null && ride.organizerId != currentUserId;
        final isApproved = myRequest?.status == RideJoinStatus.approved;
        final isPending = myRequest?.status == RideJoinStatus.pending;
        final isCompleted = ride.dateTime.isBefore(DateTime.now());
        final pendingRequests = allowOrganizerActions
            ? ride.participants
                .where((p) => p.status == RideJoinStatus.pending)
                .toList()
            : const <RideParticipant>[];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ride.city} | ${_formatDate(ride.dateTime)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${ride.approvedCount}/${ride.maxRiders} Riders Joined',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusPill(
                    isCompleted ? 'Completed Ride' : 'Upcoming Ride',
                    isCompleted
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF22C55E),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _line('Organizer', ride.organizerName),
              _line('Start', ride.startPoint),
              _line('End', ride.endPoint),
              _line('Route Preview', ride.routePreview),
              if (!compact) _line('Emergency Contact', ride.emergencyContact),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _launchExternal(ride.mapsLink),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Route Preview'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _shareRide(ride),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share Ride'),
                  ),
                  if (isApproved)
                    ElevatedButton.icon(
                      onPressed: () => _launchExternal(ride.whatsappLink),
                      icon: const Icon(Icons.forum_rounded),
                      label: const Text('Join WhatsApp Group'),
                    )
                  else if (canRequest)
                    ElevatedButton.icon(
                      onPressed: () => _requestJoin(ride.id),
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: const Text('Request to Join'),
                    )
                  else if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Request Pending',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  ride.safetyNote,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ),
              if (allowOrganizerActions) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    ride.rewardLabel,
                    style: const TextStyle(color: Color(0xFFFFC58B), fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteRide(ride.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFCA5A5),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete Ride'),
                  ),
                ),
                const SizedBox(height: 12),
                if (pendingRequests.isEmpty)
                  _emptyCard('No pending join requests for this ride yet.')
                else
                  ...pendingRequests.map((request) => _pendingRequestCard(ride.id, request)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _pendingRequestCard(String rideId, RideParticipant request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.userName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested on ${_formatDate(request.requestedAt)}',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _updateRequest(
                  rideId,
                  request.userId,
                  RideJoinStatus.approved,
                ),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: () => _updateRequest(
                  rideId,
                  request.userId,
                  RideJoinStatus.declined,
                ),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _safetyCard() {
    return _sectionCard(
      title: 'Safety & Terms',
      subtitle: 'Important before riders join a community ride.',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency contact, ride rules, and organizer details should always be shared clearly.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          SizedBox(height: 8),
          Text(
            'The app is not responsible for accidents, injuries, or route-related issues during any community ride.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _accent),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _miniFeature(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.35)),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _handleCreateRide() async {
    final title = _titleController.text.trim();
    final city = _cityController.text.trim();
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();
    final startPoint = _startController.text.trim();
    final endPoint = _endController.text.trim();
    final maxRiders = int.tryParse(_maxRidersController.text.trim()) ?? 0;
    if (title.isEmpty ||
        city.isEmpty ||
        date.isEmpty ||
        time.isEmpty ||
        startPoint.isEmpty ||
        endPoint.isEmpty ||
        maxRiders <= 0 ||
        _whatsappController.text.trim().isEmpty ||
        _mapsController.text.trim().isEmpty ||
        !_acceptSafetyTerms) {
      _showSnack('Complete all fields and accept the safety terms before publishing.');
      return;
    }

    final dateTime = _parseDateTime(date, time);
    if (dateTime == null) {
      _showSnack('Use a valid date and time format.');
      return;
    }

    setState(() => _submitting = true);
    await RideCommunityService.instance.createRide(
      title: title,
      city: city,
      dateTime: dateTime,
      startPoint: startPoint,
      endPoint: endPoint,
      maxRiders: maxRiders,
      whatsappLink: _whatsappController.text.trim(),
      mapsLink: _mapsController.text.trim(),
      routePreview: _routeController.text.trim(),
      emergencyContact: _emergencyController.text.trim(),
      rideRules: _rulesController.text.trim(),
    );
    if (!mounted) return;
    _clearCreateForm();
    setState(() {
      _submitting = false;
      _tabController.index = 2;
      _ridesFuture = RideCommunityService.instance.getRides();
    });
    _showSnack('Ride published successfully.');
  }

  Future<void> _requestJoin(String rideId) async {
    await RideCommunityService.instance.requestToJoin(rideId);
    if (!mounted) return;
    await _refresh();
    _showSnack('Join request sent to the organizer.');
  }

  Future<void> _updateRequest(
    String rideId,
    String userId,
    RideJoinStatus status,
  ) async {
    await RideCommunityService.instance.updateRequestStatus(
      rideId: rideId,
      userId: userId,
      status: status,
    );
    if (!mounted) return;
    await _refresh();
    _showSnack(status == RideJoinStatus.approved ? 'Rider approved.' : 'Request declined.');
  }

  Future<void> _deleteRide(String rideId) async {
    await RideCommunityService.instance.deleteRide(rideId);
    if (!mounted) return;
    await _refresh();
    _showSnack('Ride deleted successfully.');
  }

  Future<void> _launchExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      _showSnack('Invalid link.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareRide(RideCommunityRide ride) async {
    final message = [
      'Join me on ${ride.title}',
      '',
      'City: ${ride.city}',
      'When: ${_formatDate(ride.dateTime)}',
      'Start: ${ride.startPoint}',
      'End: ${ride.endPoint}',
      'Seats: ${ride.approvedCount}/${ride.maxRiders} riders joined',
      'Route: ${ride.routePreview}',
      '',
      'Download the Yana app, open Ride Community, and request to join this ride.',
      'Ride reference: ${ride.id}',
      if (ride.mapsLink.trim().isNotEmpty) 'Maps: ${ride.mapsLink.trim()}',
    ].join('\n');
    await Share.share(message, subject: ride.title);
  }

  Future<void> _refresh() async {
    setState(() => _ridesFuture = RideCommunityService.instance.getRides());
    await _ridesFuture;
  }

  void _clearCreateForm() {
    _titleController.clear();
    _cityController.clear();
    _dateController.clear();
    _timeController.clear();
    _startController.clear();
    _endController.clear();
    _maxRidersController.text = '20';
    _whatsappController.clear();
    _mapsController.clear();
    _routeController.clear();
    _emergencyController.clear();
    _rulesController.clear();
    _acceptSafetyTerms = false;
  }

  DateTime? _parseDateTime(String date, String time) {
    try {
      final dateParts = date.split('/');
      if (dateParts.length != 3) return null;
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      final timeParts = time.split(' ');
      final clock = timeParts.first.split(':');
      if (clock.length != 2) return null;
      var hour = int.parse(clock[0]);
      final minute = int.parse(clock[1]);
      final meridiem = timeParts.length > 1 ? timeParts[1].toUpperCase() : '';
      if (meridiem == 'PM' && hour < 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime dateTime) {
    final months = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final meridiem = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} • $hour:$minute $meridiem';
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
