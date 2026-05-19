import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/riding_groups_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class RidingGroupsScreen extends StatefulWidget {
  const RidingGroupsScreen({super.key});

  @override
  State<RidingGroupsScreen> createState() => _RidingGroupsScreenState();
}

class _RidingGroupsScreenState extends State<RidingGroupsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF0D0D0D);
  static const Color _panel = Color(0xFF171717);
  static const Color _accent = Color(0xFFD7FC70);
  AppThemePalette get palette => context.appPalette;

  late TabController _tabController;
  final _searchController = TextEditingController();

  List<RidingGroup> _groups = const [];
  List<GroupReport> _reports = const [];
  bool _loading = true;
  bool _isPrivilegedAdmin = false;
  String _currentUserId = 'guest';
  String _selectedCity = 'All Cities';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final groups = await RidingGroupsService.instance.getGroups();
    final reports = await RidingGroupsService.instance.getReports();
    final currentUserId = await RidingGroupsService.instance.currentUserId();
    final isPrivilegedAdmin = await AuthService().isPrivilegedAdmin();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _reports = reports;
      _currentUserId = currentUserId;
      _isPrivilegedAdmin = isPrivilegedAdmin;
      _loading = false;
    });
  }

  Future<void> _refresh() => _bootstrap();

  bool get _loggedIn => _currentUserId != 'guest';

  List<RidingGroup> get _visibleGroups {
    final query = _searchController.text.trim().toLowerCase();
    return _groups.where((group) {
      if (group.isDisabled) return false;
      if (_selectedCity != 'All Cities' && group.city != _selectedCity) {
        return false;
      }
      if (query.isEmpty) return true;
      return group.name.toLowerCase().contains(query) ||
          group.city.toLowerCase().contains(query);
    }).toList();
  }

  List<RidingGroup> get _myGroups =>
      _groups.where((group) => group.adminUserId == _currentUserId).toList();

  Future<void> _ensureLoggedIn() async {
    if (_loggedIn) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
    await _bootstrap();
  }

  Future<void> _openJoinAction(RidingGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join Options',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (group.instagramHandle.trim().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchInstagram(group.instagramHandle),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE1306C),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text('Open ${group.instagramHandle}'),
                  ),
                ),
              if (group.whatsappLink.trim().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchExternal(group.whatsappLink),
                    style: ElevatedButton.styleFrom(backgroundColor: _accent),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Open WhatsApp'),
                  ),
                ),
              if (group.adminPhone.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchExternal('tel:${group.adminPhone}'),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call Admin'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _joinGroup(RidingGroup group) async {
    await _ensureLoggedIn();
    if (!_loggedIn) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: const Text(
          'Join karne ke baad Instagram, WhatsApp ya admin contact option open hoga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await RidingGroupsService.instance.joinGroup(group.id);
    await _bootstrap();
    if (!mounted) return;
    await _openJoinAction(group);
  }

  Future<void> _rateGroup(RidingGroup group, int stars) async {
    await _ensureLoggedIn();
    if (!_loggedIn) return;
    await RidingGroupsService.instance.submitRating(groupId: group.id, stars: stars);
    await _bootstrap();
    _showSnack('Rating submitted.');
  }

  Future<void> _reportGroup(RidingGroup group) async {
    await _ensureLoggedIn();
    if (!_loggedIn) return;
    await RidingGroupsService.instance.reportGroup(
      groupId: group.id,
      reason: 'Reported from group directory',
    );
    await _bootstrap();
    _showSnack('Group reported.');
  }

  Future<void> _deleteGroup(RidingGroup group) async {
    await RidingGroupsService.instance.deleteGroup(group.id);
    await _bootstrap();
    _showSnack('Group deleted.');
  }

  Future<void> _toggleDisabled(RidingGroup group) async {
    await RidingGroupsService.instance.setGroupDisabled(
      groupId: group.id,
      disabled: !group.isDisabled,
    );
    await _bootstrap();
    _showSnack(group.isDisabled ? 'Group enabled.' : 'Group disabled.');
  }

  Future<void> _openGroupEditor({RidingGroup? group}) async {
    await _ensureLoggedIn();
    if (!_loggedIn) return;
    final name = TextEditingController(text: group?.name ?? '');
    final city = TextEditingController(text: group?.city ?? '');
    final description = TextEditingController(text: group?.description ?? '');
    final bikeType = TextEditingController(text: group?.bikeType ?? '');
    final instagram = TextEditingController(text: group?.instagramHandle ?? '');
    final whatsapp = TextEditingController(text: group?.whatsappLink ?? '');
    final phone = TextEditingController(text: group?.adminPhone ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group == null ? 'Register Group' : 'Edit Group',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _inputField(name, 'Group Name'),
                const SizedBox(height: 12),
                _inputField(city, 'City'),
                const SizedBox(height: 12),
                _inputField(description, 'Description', maxLines: 4),
                const SizedBox(height: 12),
                _inputField(bikeType, 'Bike Type (optional)'),
                const SizedBox(height: 12),
                _inputField(instagram, 'Instagram Handle'),
                const SizedBox(height: 12),
                _inputField(whatsapp, 'WhatsApp Link'),
                const SizedBox(height: 12),
                _inputField(phone, 'Admin Mobile Number'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty ||
                          city.text.trim().isEmpty ||
                          description.text.trim().isEmpty ||
                          (instagram.text.trim().isEmpty &&
                              whatsapp.text.trim().isEmpty &&
                              phone.text.trim().isEmpty)) {
                        _showSnack('Required fields missing.');
                        return;
                      }
                      if (group == null) {
                        await RidingGroupsService.instance.createGroup(
                          name: name.text.trim(),
                          city: city.text.trim(),
                          description: description.text.trim(),
                          bikeType: bikeType.text.trim(),
                          instagramHandle: instagram.text.trim(),
                          joinType: instagram.text.trim().isNotEmpty
                              ? 'DM on Instagram'
                              : 'Direct contact',
                          whatsappLink: whatsapp.text.trim(),
                          adminPhone: phone.text.trim(),
                          profileImage: '',
                        );
                      } else {
                        await RidingGroupsService.instance.updateGroup(
                          groupId: group.id,
                          name: name.text.trim(),
                          city: city.text.trim(),
                          description: description.text.trim(),
                          bikeType: bikeType.text.trim(),
                          instagramHandle: instagram.text.trim(),
                          joinType: instagram.text.trim().isNotEmpty
                              ? 'DM on Instagram'
                              : 'Direct contact',
                          whatsappLink: whatsapp.text.trim(),
                          adminPhone: phone.text.trim(),
                          profileImage: '',
                        );
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                      await _bootstrap();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _accent),
                    child: Text(group == null ? 'Publish Group' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showGroupDetail(RidingGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      builder: (context) {
        final joined = group.hasUserJoined(_currentUserId);
        final myRating = group.ratingByUser(_currentUserId);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${group.city} | ${group.membersCount} members',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                _detailLine('Description', group.description),
                _detailLine('Bike Type', group.bikeType.isEmpty ? 'All bikes' : group.bikeType),
                _detailLine('Group Admin', group.adminName),
                _detailLine(
                  'Join Type',
                  group.joinType.isEmpty ? 'Direct contact' : group.joinType,
                ),
                _detailLine(
                  'Average Rating',
                  '${group.averageRating.toStringAsFixed(1)} / 5',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: joined ? () => _openJoinAction(group) : () => _joinGroup(group),
                      style: ElevatedButton.styleFrom(backgroundColor: _accent),
                      icon: Icon(joined ? Icons.chat_rounded : Icons.group_add_rounded),
                      label: Text(joined ? 'Open Join Options' : 'Join Group'),
                    ),
                    TextButton.icon(
                      onPressed: () => _reportGroup(group),
                      icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent),
                      label: const Text(
                        'Report Group',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
                if (joined) ...[
                  const SizedBox(height: 14),
                  if (group.instagramHandle.trim().isNotEmpty)
                    _detailLine('Instagram', group.instagramHandle),
                  Wrap(
                    spacing: 8,
                    children: List.generate(
                      5,
                      (index) => ChoiceChip(
                        label: Text('${index + 1}★'),
                        selected: myRating == index + 1,
                        selectedColor: _accent,
                        labelStyle: TextStyle(
                          color: myRating == index + 1 ? Colors.white : Colors.white70,
                        ),
                        onSelected: (_) => _rateGroup(group, index + 1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    if (_loading) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text('Riding Groups', style: TextStyle(color: palette.textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: palette.accent,
          labelColor: palette.textPrimary,
          unselectedLabelColor: palette.textMuted,
          tabs: const [
            Tab(text: 'Explore'),
            Tab(text: 'Register'),
            Tab(text: 'My Groups'),
            Tab(text: 'Admin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExploreTab(),
          _buildRegisterTab(),
          _buildMyGroupsTab(),
          _buildAdminTab(),
        ],
      ),
    );
  }

  Widget _buildExploreTab() {
    final cities = <String>{
      'All Cities',
      ..._groups.where((group) => !group.isDisabled).map((group) => group.city),
    }.toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionCard(
            title: 'India Riding Groups Directory',
            subtitle: 'Search riding groups by city and join after login.',
            child: Column(
              children: [
                _inputField(
                  _searchController,
                  'Search by group name',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cities.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      return ChoiceChip(
                        label: Text(city),
                        selected: _selectedCity == city,
                        selectedColor: palette.accent,
                        labelStyle: TextStyle(
                          color: _selectedCity == city ? Colors.black : palette.textPrimary,
                        ),
                        backgroundColor: palette.surface,
                        onSelected: (_) => setState(() => _selectedCity = city),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_visibleGroups.isEmpty)
            _emptyCard('No groups found.')
          else
            ..._visibleGroups.map((group) => _groupCard(group)),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _sectionCard(
          title: 'Register Your Group',
          subtitle: 'WordPress login is required before publishing a group.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoPill(_loggedIn ? 'Logged in' : 'Login required'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openGroupEditor(),
                  style: ElevatedButton.styleFrom(backgroundColor: _accent),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add Group'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyGroupsTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionCard(
            title: 'My Groups',
            subtitle: 'Manage the groups you created.',
            child: !_loggedIn
                ? _emptyCard('Login to manage your groups.')
                : _myGroups.isEmpty
                    ? _emptyCard('You have not created any groups yet.')
                    : Column(
                        children: _myGroups
                            .map(
                              (group) => _groupCard(
                                group,
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _openGroupEditor(group: group),
                                      child: const Text('Edit'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _deleteGroup(group),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFFCA5A5),
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTab() {
    if (!_isPrivilegedAdmin) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [_emptyCard('This section is available to the app admin only.')],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionCard(
            title: 'All Groups',
            subtitle: 'Disable, enable, or delete listed groups.',
            child: Column(
              children: _groups
                  .map(
                    (group) => _groupCard(
                      group,
                      trailing: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_reports.where((report) => report.groupId == group.id).isNotEmpty)
                            _infoPill(
                              '${_reports.where((report) => report.groupId == group.id).length} reports',
                            ),
                          OutlinedButton(
                            onPressed: () => _toggleDisabled(group),
                            child: Text(group.isDisabled ? 'Enable' : 'Disable'),
                          ),
                          OutlinedButton(
                            onPressed: () => _deleteGroup(group),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFCA5A5),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Reports',
            subtitle: 'Review reported groups and remove fake listings.',
            child: _reports.isEmpty
                ? _emptyCard('No reports found.')
                : Column(
                    children: _reports.map((report) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Group: ${report.groupId}\nUser: ${report.userId}\nReason: ${report.reason}',
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(RidingGroup group, {Widget? trailing}) {
    return InkWell(
      onTap: () => _showGroupDetail(group),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFD166),
                  child: Text(
                    group.name.isEmpty ? 'G' : group.name.substring(0, 1),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.city} | ${group.membersCount} members',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _ratingPill(group.averageRating),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              group.description,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoPill(group.bikeType.isEmpty ? 'All bikes' : group.bikeType),
                if (group.joinType.isNotEmpty) _infoPill(group.joinType),
                if (group.isDisabled) _infoPill('Disabled'),
              ],
            ),
            if (trailing != null) ...[
              const SizedBox(height: 12),
              trailing,
            ],
          ],
        ),
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

  Widget _inputField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _accent),
        ),
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

  Widget _infoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _ratingPill(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD166).withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '⭐ ${rating.toStringAsFixed(1)}',
        style: const TextStyle(
          color: Color(0xFFFFD166),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700),
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

  Future<void> _launchExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchInstagram(String handle) async {
    final normalized = handle.trim().replaceFirst('@', '');
    if (normalized.isEmpty) return;
    await _launchExternal('https://instagram.com/$normalized');
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
