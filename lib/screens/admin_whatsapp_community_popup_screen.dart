import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/whatsapp_community_popup_service.dart';

class AdminWhatsAppCommunityPopupScreen extends StatefulWidget {
  const AdminWhatsAppCommunityPopupScreen({super.key});

  @override
  State<AdminWhatsAppCommunityPopupScreen> createState() =>
      _AdminWhatsAppCommunityPopupScreenState();
}

class _AdminWhatsAppCommunityPopupScreenState
    extends State<AdminWhatsAppCommunityPopupScreen> {
  static const String _defaultInviteUrl =
      WhatsAppCommunityPopupService.defaultInviteUrl;

  final TextEditingController _linkController = TextEditingController(
    text: _defaultInviteUrl,
  );

  bool _loading = true;
  bool _busy = false;
  bool _allowed = false;
  bool _active = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final allowed = await AuthService().isPrivilegedAdmin();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _allowed = false;
        _loading = false;
      });
      return;
    }

    final config = await WhatsAppCommunityPopupService.instance.getConfig();
    if (!mounted) return;

    setState(() {
      _allowed = true;
      _loading = false;
      _active = config.enabled;
      _linkController.text = config.inviteUrl;
      _status = 'Current: ${_active ? "enabled" : "disabled"}';
    });
  }

  Future<void> _save() async {
    final inviteUrl = _linkController.text.trim();
    final uri = Uri.tryParse(inviteUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _status = 'Valid WhatsApp invite link required.');
      return;
    }

    setState(() => _busy = true);
    await WhatsAppCommunityPopupService.instance.saveConfig(
      enabled: _active,
      inviteUrl: inviteUrl,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = 'WhatsApp community popup saved on this app.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text('WhatsApp Community Popup'),
        backgroundColor: const Color(0xFF1C1F2E),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_allowed
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ye setting sirf admin ko dikhayi jayegi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    SwitchListTile(
                      value: _active,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _active = value),
                      activeColor: const Color(0xFF25D366),
                      tileColor: const Color(0xFF1C1F2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: const Text(
                        'Enable popup',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Off karne par customers ko popup nahi dikhega.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'WhatsApp Invite Link',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF1C1F2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Settings'),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1F2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

