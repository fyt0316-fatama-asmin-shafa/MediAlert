import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'common_widgets.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onToggle;

  const RegisterPage({super.key, required this.onToggle});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  Future<void> _register() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        phoneController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setState(() {
        errorMessage = "Please fill all fields";
      });
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        errorMessage = "Passwords don't match";
      });
      return;
    }

    if (passwordController.text.length < 6) {
      setState(() {
        errorMessage = "Password should be at least 6 characters";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('medi')
          .doc(userCredential.user!.uid)
          .set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': '',
        'profileImage': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Now you can add your medicines.'),
            backgroundColor: primaryMagenta,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'An account already exists with that email.';
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

  @override
  Widget build(BuildContext context) {
    return buildSectionBox(  // _buildSectionBox থেকে buildSectionBox
      title: 'CREATE ACCOUNT',
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
          buildGlassInput(  // _buildGlassInput থেকে buildGlassInput
            icon: Icons.person_rounded,
            label: 'Full Name',
            hint: 'Enter your name',
            controller: nameController,
          ),
          const SizedBox(height: 14),
          buildGlassInput(  // _buildGlassInput থেকে buildGlassInput
            icon: Icons.email_rounded,
            label: 'Email',
            hint: 'example@mail.com',
            controller: emailController,
          ),
          const SizedBox(height: 14),
          buildGlassInput(  // _buildGlassInput থেকে buildGlassInput
            icon: Icons.phone_rounded,
            label: 'Phone Number',
            hint: 'Enter your phone number',
            controller: phoneController,
          ),
          const SizedBox(height: 14),
          buildGlassInput(  // _buildGlassInput থেকে buildGlassInput
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
          const SizedBox(height: 14),
          buildGlassInput(  // _buildGlassInput থেকে buildGlassInput
            icon: Icons.lock_clock_rounded,
            label: 'Confirm Password',
            hint: '••••••••',
            isPassword: true,
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            onToggleObscure: () {
              setState(() {
                obscureConfirmPassword = !obscureConfirmPassword;
              });
            },
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: isLoading ? null : _register,
            child: buildPrimaryButton(  // _buildPrimaryButton থেকে buildPrimaryButton
              text: isLoading ? 'REGISTERING...' : 'REGISTER',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Already have an account? ",
                style: TextStyle(color: Colors.white70),
              ),
              GestureDetector(
                onTap: widget.onToggle,
                child: Text(
                  'Login',
                  style: TextStyle(
                    color: primaryMagenta,
                    fontWeight: FontWeight.bold,
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
