// lib/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'common_widgets.dart';  // সব ফাংশন ইম্পোর্ট হচ্ছে

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool showLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackground(),  // _buildBackground() না হয়ে buildBackground() (underscore বাদ)
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  buildGlowingLogo(),  // underscore বাদ
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: showLogin
                        ? LoginPage(
                      key: const ValueKey('login'),
                      onToggle: () {
                        setState(() {
                          showLogin = false;
                        });
                      },
                    )
                        : RegisterPage(
                      key: const ValueKey('register'),
                      onToggle: () {
                        setState(() {
                          showLogin = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}