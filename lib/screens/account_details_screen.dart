import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/woo_service.dart';

class AccountDetailsScreen extends StatefulWidget {
  final int customerId;
  const AccountDetailsScreen({super.key, required this.customerId});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final _authService = AuthService();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Account Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: "First Name")),
            TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: "Last Name")),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email")),
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await WooService().updateAccountDetails(
                  customerId: widget.customerId,
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  email: emailController.text,
                  phone: phoneController.text,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Account Updated")),
                );
              },
              child: const Text("Save Changes"),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _showChangePasswordDialog,
              child: const Text("Change Password"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (newPassword.length < 8) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text("Password must be at least 8 characters"),
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text("Passwords do not match")),
                );
                return;
              }

              setState(() => isSubmitting = true);
              final updated = await _authService.changePassword(
                newPassword: newPassword,
              );
              if (!mounted) return;
              setState(() => isSubmitting = false);

              if (!updated) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text("Unable to change password")),
                );
                return;
              }

              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text("Password updated successfully")),
              );
            }

            return AlertDialog(
              title: const Text("Change Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "New Password",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                    ),
                    onSubmitted: (_) {
                      if (!isSubmitting) {
                        submit();
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: Text(isSubmitting ? "Updating..." : "Update"),
                ),
              ],
            );
          },
        );
      },
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }
}
