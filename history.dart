import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../common_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedFilter = 0; // 0: All, 1: Taken, 2: Missed
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryFromFirebase();
  }

  Future<void> _loadHistoryFromFirebase() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('medi')
          .doc(user.uid)
          .collection('medicines')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> history = [];

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Generate history entries based on medicine schedule
        DateTime startDate = (data['startDate'] as Timestamp).toDate();
        DateTime endDate = (data['endDate'] as Timestamp).toDate();
        DateTime now = DateTime.now();

        // Only show history for past dates
        if (endDate.isBefore(now)) {
          // For demo, mark some as taken and some as missed
          // In real app, you would track actual taken status
          history.add({
            'medicineName': data['medicineName'],
            'dose': data['dose'],
            'time': data['alarmTime'],
            'date': endDate,
            'status': endDate.isBefore(now.subtract(const Duration(days: 2))) ? 'Taken' : 'Missed',
            'medicineId': doc.id,
          });
        }
      }

      // Sort by date
      history.sort((a, b) => b['date'].compareTo(a['date']));

      if (mounted) {
        setState(() {
          _historyData = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMedicineStatus(String medicineId, String status) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .update({
      'lastStatus': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    var filteredData = _historyData.where((item) {
      if (_selectedFilter == 1) return item['status'] == 'Taken';
      if (_selectedFilter == 2) return item['status'] == 'Missed';
      return true;
    }).toList();

    int totalTaken = _historyData.where((m) => m['status'] == 'Taken').length;
    int totalMissed = _historyData.where((m) => m['status'] == 'Missed').length;

    return Scaffold(
      body: Stack(
        children: [
          buildBackground(),
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Medicine History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your medication adherence',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 20),

                      // Stats Cards
                      Row(
                        children: [
                          _buildStatsCard(
                            title: 'Total',
                            value: '${_historyData.length}',
                            color: primaryMagenta,
                          ),
                          const SizedBox(width: 12),
                          _buildStatsCard(
                            title: 'Taken',
                            value: '$totalTaken',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildStatsCard(
                            title: 'Missed',
                            value: '$totalMissed',
                            color: Colors.red,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Filters
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            _buildFilterButton('All', 0),
                            _buildFilterButton('Taken', 1),
                            _buildFilterButton('Missed', 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: filteredData.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No history found',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete medicine courses to see history',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      var item = filteredData[index];
                      Color statusColor = item['status'] == 'Taken' ? Colors.green : Colors.red;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withOpacity(0.2),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [primaryMagenta, primaryPurple],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item['status'] == 'Taken' ? Icons.check_circle : Icons.cancel,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['medicineName'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['dose']} • ${item['time']}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(item['date']),
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['status'],
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), Colors.white.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String title, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _selectedFilter == index ? primaryMagenta : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _selectedFilter == index ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
