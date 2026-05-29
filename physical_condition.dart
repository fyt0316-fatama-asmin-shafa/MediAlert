import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../common_widgets.dart';

class PhysicalConditionScreen extends StatefulWidget {
  const PhysicalConditionScreen({super.key});

  @override
  State<PhysicalConditionScreen> createState() => _PhysicalConditionScreenState();
}

class _PhysicalConditionScreenState extends State<PhysicalConditionScreen> {
  Map<String, dynamic> _healthData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('medi')
          .doc(user.uid)
          .collection('health')
          .doc('metrics')
          .get();

      if (doc.exists) {
        _healthData = doc.data() as Map<String, dynamic>;
      } else {
        _healthData = {
          'bloodPressure': '120/80',
          'heartRate': 72,
          'sleep': 7.5,
          'water': 6,
          'lastUpdated': Timestamp.now(),
        };
      }
    } catch (e) {
      print('Error loading health data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateHealthData(String key, dynamic value) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _healthData[key] = value;
      _healthData['lastUpdated'] = Timestamp.now();
    });

    await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('health')
        .doc('metrics')
        .set({
      key: value,
      'lastUpdated': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  String _formatLastUpdated(dynamic lastUpdated) {
    if (lastUpdated == null) return 'Not updated yet';
    try {
      if (lastUpdated is Timestamp) {
        DateTime dateTime = lastUpdated.toDate();
        return DateFormat('MMM dd, hh:mm a').format(dateTime);
      }
      return 'Not updated yet';
    } catch (e) {
      return 'Not updated yet';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            buildBackground(),
            Container(color: Colors.black.withOpacity(0.5)),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    String lastUpdatedText =
    _formatLastUpdated(_healthData['lastUpdated']);

    return Scaffold(
      body: Stack(
        children: [
          buildBackground(),
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, color: primaryMagenta, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Physical Condition',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Last updated: $lastUpdatedText',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),

                  const SizedBox(height: 30),

                  // Blood Pressure
                  _buildHealthCard(
                    title: 'Blood Pressure',
                    value: _healthData['bloodPressure']?.toString() ?? '120/80',
                    unit: 'mmHg',
                    icon: Icons.favorite,
                    color: Colors.red,
                    onEdit: () => _showEditDialog('Blood Pressure', 'bloodPressure'),
                  ),

                  const SizedBox(height: 16),

                  // Heart Rate
                  _buildHealthCard(
                    title: 'Heart Rate',
                    value: (_healthData['heartRate'] ?? 72).toString(),
                    unit: 'BPM',
                    icon: Icons.favorite_border,
                    color: Colors.pink,
                    onEdit: () => _showEditDialog('Heart Rate', 'heartRate', isNumber: true),
                  ),

                  const SizedBox(height: 16),

                  // Sleep
                  _buildHealthCard(
                    title: 'Sleep',
                    value: (_healthData['sleep'] ?? 7.5).toString(),
                    unit: 'hours',
                    icon: Icons.bedtime,
                    color: Colors.purple,
                    onEdit: () => _showEditDialog('Sleep', 'sleep', isNumber: true),
                  ),

                  const SizedBox(height: 16),

                  // Water
                  _buildHealthCard(
                    title: 'Water',
                    value: (_healthData['water'] ?? 6).toString(),
                    unit: 'glasses',
                    icon: Icons.water_drop,
                    color: Colors.cyan,
                    onEdit: () => _showEditDialog('Water', 'water', isNumber: true),
                  ),

                  const SizedBox(height: 20),

                  // Health Tip
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Text(
                      'Take your medicines on time and stay hydrated!',
                      style: TextStyle(color: Colors.white70),
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

  Widget _buildHealthCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70)),
                Text(
                  '$value $unit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String title, String field, {bool isNumber = false}) {
    TextEditingController controller = TextEditingController(
      text: _healthData[field]?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkBgEnd,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType:
          isNumber ? TextInputType.number : TextInputType.text,
          decoration: const InputDecoration(
            hintText: 'Enter value',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text;

              if (isNumber) {
                final numValue = double.tryParse(value);
                if (numValue != null) {
                  _updateHealthData(field, numValue);
                }
              } else {
                _updateHealthData(field, value);
              }

              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}