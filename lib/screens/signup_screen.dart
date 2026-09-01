import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _showThemedSnackBar(String message, {bool isError = false}) {
    final palette = context.appPalette;
    final background = isError ? palette.accentStrong : palette.accent;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: palette.onAccent),
        ),
        backgroundColor: background,
      ),
    );
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://yanaworldwide.store/wp-json/wp/v2/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Basic c3VuaXRhOlpTVDQgVXc4MiBtTFlIIDFJRW4gSHRmbSBWWldJ',
        },
        body: jsonEncode({
          'username': emailController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'name': nameController.text.trim(),
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        if (!mounted) return;
        _showThemedSnackBar('Account Created Successfully!');
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;
      final errorData = jsonDecode(response.body);
      String errorMessage = errorData['message'] ?? 'Registration failed';
      if (errorMessage.contains('weak')) {
        errorMessage = 'Password is too weak. Try a stronger one.';
      }
      _showThemedSnackBar(errorMessage, isError: true);
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      _showThemedSnackBar('Error: $e', isError: true);
    }
  }

  InputDecoration _buildInputDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final palette = context.appPalette;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.textMuted),
      prefixIcon: Icon(icon, color: palette.accent),
      filled: true,
      fillColor: palette.surfaceStrong,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accentStrong),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.accentStrong, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'Sign Up',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: palette.surfaceStrong,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: palette.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        palette.heroStart.withValues(alpha: 0.94),
                        palette.heroEnd.withValues(alpha: 0.94),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: palette.border),
                    boxShadow: [
                      BoxShadow(
                        color: palette.textPrimary.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Rider',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your account and start shopping with the current app theme.',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: nameController,
                style: TextStyle(color: palette.textPrimary),
                decoration: _buildInputDecoration(
                  context,
                  'Full Name',
                  Icons.person_outline,
                ),
                cursorColor: palette.accent,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                style: TextStyle(color: palette.textPrimary),
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  context,
                  'Email',
                  Icons.email_outlined,
                ),
                cursorColor: palette.accent,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordController,
                style: TextStyle(color: palette.textPrimary),
                obscureText: !_isPasswordVisible,
                cursorColor: palette.accent,
                decoration: _buildInputDecoration(
                  context,
                  'Password',
                  Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: palette.textMuted,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password is too weak (Min 6 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isLoading ? null : registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  disabledBackgroundColor: palette.surfaceStrong,
                  disabledForegroundColor: palette.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: palette.onAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
