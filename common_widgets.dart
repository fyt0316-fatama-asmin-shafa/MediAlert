import 'dart:ui';
import 'package:flutter/material.dart';

// কালার কনস্ট্যান্ট
const Color primaryMagenta = Color(0xFFFBCFE8);
const Color primaryPurple = Color(0xFFF3E8FF);
const Color primaryPink = Color(0xFFFDF2F8);
const Color darkBgStart = Color(0xFFA855F7);
const Color darkBgEnd = Color(0xFFF472B6);

Widget buildBackground() {
  return Container(
    height: double.infinity,
    width: double.infinity,
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/background.png'),
        fit: BoxFit.cover,
      ),
    ),
  );
}

Widget buildGlowingLogo() {
  return Stack(
    alignment: Alignment.center,
    children: [
      Container(
        height: 160,
        width: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryMagenta.withOpacity(0.5),
              blurRadius: 60,
              spreadRadius: 12,
            )
          ],
        ),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(45),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(45),
              border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
            ),
          ),
        ),
      ),
      Container(
        height: 130,
        width: 130,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Image.asset('assets/mediAlert_logo.png', fit: BoxFit.cover),
        ),
      ),
    ],
  );
}

Widget buildGlowingLogoSmall() {
  return Container(
    height: 50,
    width: 50,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: primaryMagenta.withOpacity(0.5),
          blurRadius: 20,
          spreadRadius: 5,
        )
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Image.asset('assets/mediAlert_logo.png', fit: BoxFit.cover),
    ),
  );
}

Widget buildSectionBox({required String title, required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(30),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: primaryMagenta.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryPurple.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: Color(0xFFFFD1FF),  // লাইট পিঙ্ক - স্পষ্ট দেখা যায়
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    ),
  );
}
// আপডেটেড buildPrimaryButton - হালকা ডার্ক
// আপডেটেড buildPrimaryButton - ডার্কার ভার্সন
Widget buildPrimaryButton({required String text}) {
  return Container(
    width: double.infinity,
    height: 60,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [
          Color(0xFFC026D3),  // ডার্ক ম্যাজেন্টা
          Color(0xFF7E22CE),  // ডার্ক পার্পল
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFC026D3).withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}
Widget buildGlassInput({
  required IconData icon,
  required String label,
  required String hint,
  required TextEditingController controller,
  bool isPassword = false,
  bool obscureText = true,
  VoidCallback? onToggleObscure,
  bool enabled = true,
}) {
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: primaryMagenta.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryMagenta, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword ? obscureText : false,
              enabled: enabled,
              style: const TextStyle(
                color: Colors.white,  // সাদা টেক্সট - স্পষ্ট দেখা যায়
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(
                  color: Color(0xFFFFD1FF),  // লাইট পিঙ্ক - স্পষ্ট
                  fontSize: 11,
                ),
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Colors.white,  // হালকা সাদা
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (isPassword && onToggleObscure != null)
            IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: primaryMagenta,
                size: 20,
              ),
              onPressed: onToggleObscure,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    ),
  );
}