import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgot_password_page.dart';
import 'common_widgets.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onToggle;

  const LoginPage({super.key, required this.onToggle});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  bool obscurePassword = true;

  // Store login timestamp after successful authentication
  Future<void> _storeLoginTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_login_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Please fill all fields';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      // Store timestamp after successful login
      await _storeLoginTimestamp();
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found with this email.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Wrong password.';
        } else {
          errorMessage = e.message;
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildSectionBox(
      title: 'LOGIN',
      child: Column(
        children: [
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          buildGlassInput(
            icon: Icons.email_rounded,
            label: 'Email',
            hint: 'example@mail.com',
            controller: emailController,
          ),
          const SizedBox(height: 14),
          buildGlassInput(
            icon: Icons.lock_rounded,
            label: 'Password',
            hint: '••••••••',
            isPassword: true,
            controller: passwordController,
            obscureText: obscurePassword,
            onToggleObscure: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _navigateToForgotPassword,
              child: const Text(
                'Forget Password?',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: isLoading ? null : _login,
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFBE185D),
                    Color(0xFF6B21A8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBE185D).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isLoading ? 'LOGGING IN...' : 'LOGIN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.white),
              ),
              GestureDetector(
                onTap: widget.onToggle,
                child: Text(
                  'Register',
                  style: TextStyle(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
