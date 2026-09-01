import 'package:flutter/material.dart';

import '../services/notification_inbox_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  bool _loading = true;
  List<NotificationInboxItem> _items = const [];

  @override
  void initState() {
    super.initState();
    NotificationInboxService.instance.inboxChangeNotifier.addListener(
      _handleInboxChanged,
    );
    _load(markRead: true);
  }

  @override
  void dispose() {
    NotificationInboxService.instance.inboxChangeNotifier.removeListener(
      _handleInboxChanged,
    );
    super.dispose();
  }

  void _handleInboxChanged() {
    _load(markRead: true);
  }

  Future<void> _load({bool markRead = false}) async {
    final items = await NotificationInboxService.instance.getItems();
    if (markRead) {
      await NotificationInboxService.instance.markAllRead();
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    await NotificationInboxService.instance.clearAll();
    if (!mounted) return;
    setState(() {
      _items = const [];
    });
  }

  String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          'Notifications',
          style: TextStyle(color: palette.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Clear all',
            onPressed: _items.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: _loading
          ? const FullPageSkeleton(padding: EdgeInsets.all(12))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No notifications yet.',
                            style: TextStyle(color: palette.textMuted, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                           decoration: BoxDecoration(
                             color: palette.surface,
                             borderRadius: BorderRadius.circular(14),
                             border: Border.all(color: palette.border),
                           ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                       style: TextStyle(
                                         color: palette.textPrimary,
                                         fontSize: 15,
                                         fontWeight: FontWeight.w700,
                                       ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.body,
                               style: TextStyle(color: palette.textMuted, fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formatTime(item.receivedAtMs),
                                 style: TextStyle(
                                   color: palette.textMuted.withOpacity(0.78),
                                   fontSize: 12,
                                 ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
