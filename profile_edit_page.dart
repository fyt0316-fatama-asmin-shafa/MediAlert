import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'common_widgets.dart';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileEditPage({super.key, required this.userData});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  File? _imageFile;
  Uint8List? _webImage;
  bool isLoading = false;
  String? _profileImageBase64;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    emailController = TextEditingController(text: widget.userData['email'] ?? '');
    phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    addressController = TextEditingController(text: widget.userData['address'] ?? '');
    _profileImageBase64 = widget.userData['profileImage'];
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      if (kIsWeb) {
        Uint8List bytes = await image.readAsBytes();

        setState(() {
          _webImage = bytes;
        });

        await _saveImageAsBase64(bytes);
      } else {
        File file = File(image.path);

        setState(() {
          _imageFile = file;
        });

        Uint8List bytes = await file.readAsBytes();
        await _saveImageAsBase64(bytes);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image selected successfully!')),
      );
    } catch (e) {
      print('Image picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
  Future<void> _saveImageAsBase64(Uint8List imageBytes) async {
    setState(() => isLoading = true);

    try {
      String base64Image = base64Encode(imageBytes);

      if (base64Image.length > 1000000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image is too large. Please choose a smaller image.')),
        );
        setState(() => isLoading = false);
        return;
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('medi')
            .doc(user.uid)
            .update({
          'profileImage': base64Image,
          'profileImageUpdatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _profileImageBase64 = base64Image;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully!')),
        );
      }
    } catch (e) {
      print('Error saving image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  ImageProvider? _getProfileImage() {
    if (_webImage != null) {
      return MemoryImage(_webImage!);
    }
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    }
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        Uint8List bytes = base64Decode(_profileImageBase64!);
        return MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> _saveProfile() async {
    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('medi')
            .doc(user.uid)
            .update({
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkBgEnd,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackground(),  // আপডেটেড: underscore বাদ
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      buildGlowingLogoSmall(),  // আপডেটেড: underscore বাদ
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: _logout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'EDIT PROFILE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryMagenta, width: 3),
                            image: _getProfileImage() != null
                                ? DecorationImage(
                              image: _getProfileImage()!,
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: _getProfileImage() == null
                              ? Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryMagenta, primaryPurple],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  buildSectionBox(  // আপডেটেড: underscore বাদ
                    title: 'PERSONAL INFORMATION',
                    child: Column(
                      children: [
                        buildGlassInput(  // আপডেটেড: underscore বাদ
                          icon: Icons.person,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          controller: nameController,
                        ),
                        const SizedBox(height: 16),
                        buildGlassInput(  // আপডেটেড: underscore বাদ
                          icon: Icons.email,
                          label: 'Email',
                          hint: 'email@example.com',
                          controller: emailController,
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                        buildGlassInput(  // আপডেটেড: underscore বাদ
                          icon: Icons.phone,
                          label: 'Phone Number',
                          hint: 'Enter phone number',
                          controller: phoneController,
                        ),
                        const SizedBox(height: 16),
                        buildGlassInput(  // আপডেটেড: underscore বাদ
                          icon: Icons.location_on,
                          label: 'Address',
                          hint: 'Enter your address',
                          controller: addressController,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 55,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: const Center(
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: isLoading ? null : _saveProfile,
                          child: Container(
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryMagenta, primaryPurple],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                isLoading ? 'SAVING...' : 'SAVE CHANGES',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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