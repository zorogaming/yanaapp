import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/woo_service.dart';
import '../widgets/skeletons.dart';

class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  static const String _supportPhone = "919166666554";
  static const String _supportEmail = "support@yanaworldwide.store";

  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _screenController = TextEditingController();

  final AuthService _authService = AuthService();
  final WooService _wooService = WooService();

  bool _isLoading = true;
  String _debugInfo = "";

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  @override
  void dispose() {
    _issueController.dispose();
    _screenController.dispose();
    super.dispose();
  }

  Future<void> _loadDebugInfo() async {
    final userId = await _authService.getUserId();
    final userEmail = await _authService.getUserEmail();
    final appVersion = await _wooService.fetchAppVersion();
    final os = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;

    final lines = <String>[
      "Time: ${DateTime.now().toIso8601String()}",
      "User ID: ${userId ?? "Guest"}",
      "User Email: ${userEmail ?? "Not available"}",
      "Platform: $os",
      "OS Version: $osVersion",
      "Latest App Version (Server): ${appVersion ?? "Unknown"}",
      "Screen: ${_screenController.text.trim().isEmpty ? "Not specified" : _screenController.text.trim()}",
      "Issue: ${_issueController.text.trim().isEmpty ? "Not specified" : _issueController.text.trim()}",
    ];

    if (!mounted) return;
    setState(() {
      _debugInfo = lines.join("\n");
      _isLoading = false;
    });
  }

  Future<void> _sendOnWhatsApp() async {
    await _loadDebugInfo();
    final message = Uri.encodeComponent(
      "Bug Report - Yana App\n\n$_debugInfo\n\nScreenshot: Please attach screenshot/video with this message.",
    );
    final uri = Uri.parse("https://wa.me/$_supportPhone?text=$message");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendOnEmail() async {
    await _loadDebugInfo();
    final subject = Uri.encodeComponent("Bug Report - Yana App");
    final body = Uri.encodeComponent(
      "$_debugInfo\n\nScreenshot: Please attach screenshot/video before sending.",
    );
    final uri = Uri.parse("mailto:$_supportEmail?subject=$subject&body=$body");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyDebugInfo() async {
    await _loadDebugInfo();
    await Clipboard.setData(ClipboardData(text: _debugInfo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Debug details copied")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text("Report a Bug"),
        backgroundColor: const Color(0xFF1C1F2E),
      ),
      body: _isLoading
          ? const FullPageSkeleton()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Issue Details",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _screenController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Which screen has bug?"),
                  onChanged: (_) => _loadDebugInfo(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _issueController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: _inputDecoration("What issue are you facing?"),
                  onChanged: (_) => _loadDebugInfo(),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Debug Data (auto attached)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _debugInfo,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _sendOnWhatsApp,
                  icon: const Icon(Icons.chat),
                  label: const Text("Send on WhatsApp"),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _sendOnEmail,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text("Send on Email"),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _copyDebugInfo,
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy Debug Data"),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Tip: WhatsApp/Email open hone ke baad screenshot ya short video attach karke bhej dein.",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}
