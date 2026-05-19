import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/ride_community_service.dart';
import '../widgets/skeletons.dart';

class AdminRideCommunityControlScreen extends StatefulWidget {
  const AdminRideCommunityControlScreen({super.key});

  @override
  State<AdminRideCommunityControlScreen> createState() =>
      _AdminRideCommunityControlScreenState();
}

class _AdminRideCommunityControlScreenState
    extends State<AdminRideCommunityControlScreen> {
  bool _loading = true;
  bool _allowed = false;
  bool _busy = false;
  String _error = '';
  String _status = '';

  List<RideCommunityRide> _rides = const [];
  List<RideMemorySubmission> _memories = const [];
  bool _newRideAlerts = true;
  bool _rideReminders = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final allowed = await AuthService().isPrivilegedAdmin();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _allowed = false;
        _loading = false;
      });
      return;
    }

    setState(() {
      _allowed = true;
      _loading = true;
      _error = '';
    });

    try {
      final results = await Future.wait([
        RideCommunityService.instance.getRides(),
        RideCommunityService.instance.getRideMemories(),
        RideCommunityService.instance.getAdminNotificationSettings(),
      ]);
      if (!mounted) return;
      final settings = results[2] as Map<String, bool>;
      setState(() {
        _rides = results[0] as List<RideCommunityRide>;
        _memories = results[1] as List<RideMemorySubmission>;
        _newRideAlerts = settings['new_ride_alerts'] ?? true;
        _rideReminders = settings['ride_reminders'] ?? true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<_PendingRideApproval> get _pendingApprovals {
    final rows = <_PendingRideApproval>[];
    for (final ride in _rides) {
      for (final participant in ride.participants) {
        if (participant.status == RideJoinStatus.pending) {
          rows.add(
            _PendingRideApproval(
              ride: ride,
              participant: participant,
            ),
          );
        }
      }
    }
    rows.sort(
      (a, b) => b.participant.requestedAt.compareTo(a.participant.requestedAt),
    );
    return rows;
  }

  List<MapEntry<String, int>> get _topCities {
    final counts = <String, int>{};
    for (final ride in _rides) {
      counts.update(ride.city, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(4).toList();
  }

  List<_OrganizerSummary> get _topOrganizers {
    final summaries = <String, _OrganizerSummary>{};
    for (final ride in _rides) {
      final current = summaries[ride.organizerId];
      if (current == null) {
        summaries[ride.organizerId] = _OrganizerSummary(
          organizerId: ride.organizerId,
          organizerName: ride.organizerName,
          ridesCreated: 1,
          approvedRiders: ride.approvedCount,
          rewardLabel: ride.rewardLabel,
        );
      } else {
        summaries[ride.organizerId] = current.copyWith(
          ridesCreated: current.ridesCreated + 1,
          approvedRiders: current.approvedRiders + ride.approvedCount,
        );
      }
    }
    final entries = summaries.values.toList()
      ..sort((a, b) => b.approvedRiders.compareTo(a.approvedRiders));
    return entries.take(4).toList();
  }

  List<_RewardSummary> get _rewardSummaries {
    return _topOrganizers.map((organizer) {
      final rewardReady = organizer.approvedRiders >= 10;
      return _RewardSummary(
        organizerName: organizer.organizerName,
        rewardLabel: organizer.rewardLabel,
        ridesCreated: organizer.ridesCreated,
        approvedRiders: organizer.approvedRiders,
        status: rewardReady ? 'Ready to grant' : 'Monitor threshold',
      );
    }).toList();
  }

  List<RideMemorySubmission> get _pendingMemories => _memories
      .where((memory) => memory.status == RideMemoryStatus.pending)
      .toList();

  Future<void> _updateRequest(
    _PendingRideApproval row,
    RideJoinStatus status,
  ) async {
    setState(() {
      _busy = true;
      _status = '';
      _error = '';
    });
    await RideCommunityService.instance.updateRequestStatus(
      rideId: row.ride.id,
      userId: row.participant.userId,
      status: status,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status == RideJoinStatus.approved
          ? 'Join request approved for ${row.participant.userName}.'
          : 'Join request declined for ${row.participant.userName}.';
    });
    await _bootstrap();
  }

  Future<void> _removeRider(_PendingRideApproval row) async {
    setState(() {
      _busy = true;
      _status = '';
      _error = '';
    });
    await RideCommunityService.instance.removeParticipant(
      rideId: row.ride.id,
      userId: row.participant.userId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = 'Rider removed from ${row.ride.title}.';
    });
    await _bootstrap();
  }

  Future<void> _deleteRide(RideCommunityRide ride) async {
    setState(() {
      _busy = true;
      _status = '';
      _error = '';
    });
    await RideCommunityService.instance.deleteRide(ride.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = '${ride.title} was deleted from Ride Community.';
    });
    await _bootstrap();
  }

  Future<void> _updateMemory(
    RideMemorySubmission memory,
    RideMemoryStatus status,
  ) async {
    setState(() {
      _busy = true;
      _status = '';
      _error = '';
    });
    await RideCommunityService.instance.updateMemoryStatus(
      memoryId: memory.id,
      status: status,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status == RideMemoryStatus.approved
          ? 'Memory approved for ${memory.rideTitle}.'
          : 'Memory rejected for ${memory.rideTitle}.';
    });
    await _bootstrap();
  }

  Future<void> _savePushSettings({
    bool? newRideAlerts,
    bool? rideReminders,
  }) async {
    setState(() {
      _busy = true;
      _status = '';
      _error = '';
    });
    await RideCommunityService.instance.saveAdminNotificationSettings(
      newRideAlerts: newRideAlerts,
      rideReminders: rideReminders,
    );
    if (!mounted) return;
    setState(() {
      if (newRideAlerts != null) _newRideAlerts = newRideAlerts;
      if (rideReminders != null) _rideReminders = rideReminders;
      _busy = false;
      _status = 'Ride community notification controls updated.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingApprovals = _pendingApprovals;
    final topCities = _topCities;
    final topOrganizers = _topOrganizers;
    final rewardSummaries = _rewardSummaries;
    final pendingMemories = _pendingMemories;

    return Scaffold(
      backgroundColor: const Color(0xFF090B13),
      appBar: AppBar(
        title: const Text('Ride Community Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const FullPageSkeleton()
          : !_allowed
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This section is available to privileged admins only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _bootstrap,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ride Community Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Approve riders, monitor top cities and organizers, manage rewards, moderate ride memories, and control ride alerts from one admin panel.',
                              style: TextStyle(color: Colors.white70, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _statusChip(
                                  'Rides ${_rides.length}',
                                  const Color(0xFFFF8A2B),
                                ),
                                _statusChip(
                                  'Pending approvals ${pendingApprovals.length}',
                                  const Color(0xFF38BDF8),
                                ),
                                _statusChip(
                                  'Pending memories ${pendingMemories.length}',
                                  const Color(0xFF22C55E),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Pending Join Approvals',
                              'Review riders waiting for organizer approval.',
                            ),
                            const SizedBox(height: 14),
                            if (pendingApprovals.isEmpty)
                              _emptyState('No ride join requests are pending right now.')
                            else
                              ...pendingApprovals.map(_approvalTile),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Ride Deletion Control',
                              'Delete any published ride if it should no longer appear in the community.',
                            ),
                            const SizedBox(height: 14),
                            if (_rides.isEmpty)
                              _emptyState('No rides are available to delete right now.')
                            else
                              ..._rides.map(
                                (ride) => _infoActionTile(
                                  title: ride.title,
                                  subtitle:
                                      '${ride.city} | ${ride.approvedCount}/${ride.maxRiders} riders joined',
                                  actionLabel: 'Delete Ride',
                                  actionColor: const Color(0xFFFCA5A5),
                                  onPressed:
                                      _busy ? null : () => _deleteRide(ride),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Top Cities and Organizers',
                              'See where the community is growing fastest.',
                            ),
                            const SizedBox(height: 14),
                            if (topCities.isEmpty && topOrganizers.isEmpty)
                              _emptyState('No ride performance data is available yet.')
                            else ...[
                              if (topCities.isNotEmpty) ...[
                                const Text(
                                  'Top Cities',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...topCities.map(
                                  (entry) => _infoTile(
                                    title: entry.key,
                                    subtitle: '${entry.value} published rides',
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (topOrganizers.isNotEmpty) ...[
                                const Text(
                                  'Top Organizers',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...topOrganizers.map(
                                  (organizer) => _infoTile(
                                    title: organizer.organizerName,
                                    subtitle:
                                        'Rides: ${organizer.ridesCreated} | Approved riders: ${organizer.approvedRiders}',
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Reward Distribution View',
                              'Track which organizers are close to or ready for rewards.',
                            ),
                            const SizedBox(height: 14),
                            if (rewardSummaries.isEmpty)
                              _emptyState('No organizer reward signals are available yet.')
                            else
                              ...rewardSummaries.map(
                                (reward) => _infoTile(
                                  title: reward.organizerName,
                                  subtitle:
                                      '${reward.rewardLabel}\nRides: ${reward.ridesCreated} | Approved riders: ${reward.approvedRiders}\nStatus: ${reward.status}',
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Ride Memories Moderation',
                              'Approve or reject post-ride photos and videos before they go public.',
                            ),
                            const SizedBox(height: 14),
                            if (pendingMemories.isEmpty)
                              _emptyState('No ride memories are waiting for moderation.')
                            else
                              ...pendingMemories.map(_memoryTile),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Push Notification Controls',
                              'Manage community alerts for ride discovery and ride-day reminders.',
                            ),
                            const SizedBox(height: 14),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _newRideAlerts,
                              activeColor: const Color(0xFFFF8A2B),
                              title: const Text(
                                'New ride alerts',
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: const Text(
                                'Notify riders when fresh rides are published in the community.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) => _savePushSettings(
                                        newRideAlerts: value,
                                      ),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _rideReminders,
                              activeColor: const Color(0xFFFF8A2B),
                              title: const Text(
                                'Ride reminders',
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: const Text(
                                'Send reminders before approved riders head out for the event.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) => _savePushSettings(
                                        rideReminders: value,
                                      ),
                            ),
                          ],
                        ),
                      ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _statusMessage(
                          _status,
                          const Color(0xFF0F2A1D),
                          const Color(0xFF14532D),
                          const Color(0xFF86EFAC),
                        ),
                      ],
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _statusMessage(
                          _error,
                          const Color(0xFF3A1217),
                          const Color(0xFF7F1D1D),
                          const Color(0xFFFCA5A5),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _shellCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF171B28), Color(0xFF111522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.36)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _approvalTile(_PendingRideApproval row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.participant.userName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${row.ride.title} | ${row.ride.city}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'Organizer: ${row.ride.organizerName}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _updateRequest(row, RideJoinStatus.approved),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _updateRequest(row, RideJoinStatus.declined),
                child: const Text('Decline'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _removeRider(row),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFCA5A5),
                ),
                child: const Text('Delete Rider'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memoryTile(RideMemorySubmission memory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            memory.previewLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${memory.rideTitle} | ${memory.mediaType.toUpperCase()}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'Submitted by ${memory.submittedBy}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _updateMemory(memory, RideMemoryStatus.approved),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _updateMemory(memory, RideMemoryStatus.rejected),
                child: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _infoActionTile({
    required String title,
    required String subtitle,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: actionColor,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _statusMessage(
    String text,
    Color background,
    Color border,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(color: foreground),
      ),
    );
  }
}

class _PendingRideApproval {
  const _PendingRideApproval({
    required this.ride,
    required this.participant,
  });

  final RideCommunityRide ride;
  final RideParticipant participant;
}

class _OrganizerSummary {
  const _OrganizerSummary({
    required this.organizerId,
    required this.organizerName,
    required this.ridesCreated,
    required this.approvedRiders,
    required this.rewardLabel,
  });

  final String organizerId;
  final String organizerName;
  final int ridesCreated;
  final int approvedRiders;
  final String rewardLabel;

  _OrganizerSummary copyWith({
    int? ridesCreated,
    int? approvedRiders,
  }) {
    return _OrganizerSummary(
      organizerId: organizerId,
      organizerName: organizerName,
      ridesCreated: ridesCreated ?? this.ridesCreated,
      approvedRiders: approvedRiders ?? this.approvedRiders,
      rewardLabel: rewardLabel,
    );
  }
}

class _RewardSummary {
  const _RewardSummary({
    required this.organizerName,
    required this.rewardLabel,
    required this.ridesCreated,
    required this.approvedRiders,
    required this.status,
  });

  final String organizerName;
  final String rewardLabel;
  final int ridesCreated;
  final int approvedRiders;
  final String status;
}
