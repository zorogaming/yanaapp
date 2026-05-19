import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();
  bool _isSubmitting = false;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 8 characters"),
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final updated = await _authService.changePassword(
      newPassword: newPassword,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to change password")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password updated successfully")),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Password app ke andar hi update hoga. WordPress page par redirect nahi hoga.",
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordController,
            obscureText: _hideNewPassword,
            decoration: InputDecoration(
              labelText: "New Password",
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _hideNewPassword = !_hideNewPassword);
                },
                icon: Icon(
                  _hideNewPassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _hideConfirmPassword,
            decoration: InputDecoration(
              labelText: "Confirm Password",
              suffixIcon: IconButton(
                onPressed: () {
                  setState(
                    () => _hideConfirmPassword = !_hideConfirmPassword,
                  );
                },
                icon: Icon(
                  _hideConfirmPassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
            onSubmitted: (_) {
              if (!_isSubmitting) {
                _submit();
              }
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? "Updating..." : "Update Password"),
            ),
          ),
        ],
      ),
    );
  }
}
