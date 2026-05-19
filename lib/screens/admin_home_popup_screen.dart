import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class AdminHomePopupScreen extends StatefulWidget {
  const AdminHomePopupScreen({super.key});

  @override
  State<AdminHomePopupScreen> createState() => _AdminHomePopupScreenState();
}

class _AdminHomePopupScreenState extends State<AdminHomePopupScreen> {
  final AdminService _admin = AdminService();
  final TextEditingController _titleController = TextEditingController(
    text: "Important Update",
  );
  final TextEditingController _messageController = TextEditingController(
    text: "Aapke liye ek important message hai.",
  );
  final TextEditingController _buttonTextController = TextEditingController(
    text: "Got it",
  );
  final TextEditingController _actionUrlController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String _status = "";

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _buttonTextController.dispose();
    _actionUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final data = await _admin.getHomePopupConfig();
    if (!mounted) return;
    final state = (data["state"] is Map)
        ? Map<String, dynamic>.from(data["state"])
        : const <String, dynamic>{};

    if (state.isNotEmpty) {
      final title = (state["title"] ?? "").toString().trim();
      final message = (state["message"] ?? "").toString().trim();
      final buttonText = (state["button_text"] ?? "").toString().trim();
      final actionUrl = (state["action_url"] ?? "").toString().trim();
      if (title.isNotEmpty) _titleController.text = title;
      if (message.isNotEmpty) _messageController.text = message;
      if (buttonText.isNotEmpty) _buttonTextController.text = buttonText;
      _actionUrlController.text = actionUrl;
      _status =
          "Current: active=${state["active"] == true}, campaign_id=${state["campaign_id"] ?? 0}, updated_at=${state["updated_at"] ?? "-"}";
    } else {
      _status = "Could not fetch current popup state.";
    }

    setState(() => _loading = false);
  }

  Future<void> _triggerPopup() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final buttonText = _buttonTextController.text.trim();

    if (title.isEmpty || message.isEmpty || buttonText.isEmpty) {
      setState(() => _status = "Title, message and button text required.");
      return;
    }

    setState(() => _busy = true);
    final data = await _admin.triggerHomePopup(
      title: title,
      message: message,
      buttonText: buttonText,
      actionUrl: _actionUrlController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = data["ok"] == true
          ? "Home popup triggered. campaign_id=${(data["state"] ?? const {})["campaign_id"] ?? "-"}"
          : (data["message"] ?? "Failed to trigger popup").toString();
    });
  }

  Future<void> _disablePopup() async {
    setState(() => _busy = true);
    final data = await _admin.deactivateHomePopup();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = data["ok"] == true
          ? "Home popup disabled."
          : (data["message"] ?? "Failed to disable popup").toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text("Home Popup"),
        backgroundColor: const Color(0xFF1C1F2E),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _buildTextField("Popup Title", _titleController),
                const SizedBox(height: 10),
                _buildTextField("Popup Message", _messageController, maxLines: 4),
                const SizedBox(height: 10),
                _buildTextField("Button Text", _buttonTextController),
                const SizedBox(height: 10),
                _buildTextField("Action URL (optional)", _actionUrlController),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _busy ? null : _triggerPopup,
                  child: const Text("Send Home Popup"),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _disablePopup,
                  child: const Text("Disable Popup"),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
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
    );
  }
}
