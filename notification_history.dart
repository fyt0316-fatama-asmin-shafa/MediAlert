import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../common_widgets.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  bool _hasPermissionError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMissedAlarms();
    });
  }

  Future<void> _deleteNotification(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('notificationHistory')
        .doc(docId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Deleted")),
      );
    }
  }

  Future<void> _checkMissedAlarms() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    try {
      final medicinesSnapshot = await FirebaseFirestore.instance
          .collection('medi')
          .doc(user.uid)
          .collection('medicines')
          .where('active', isEqualTo: true)
          .get();

      if (medicinesSnapshot.docs.isEmpty) {
        if (mounted) setState(() => _hasPermissionError = false);
        return;
      }

      for (final medicineDoc in medicinesSnapshot.docs) {
        final medicineId = medicineDoc.id;
        final medData = medicineDoc.data();

        final alarmsSnapshot = await FirebaseFirestore.instance
            .collection('medi')
            .doc(user.uid)
            .collection('medicines')
            .doc(medicineId)
            .collection('alarms')
            .where('notified', isEqualTo: false)
            .where('scheduledTime', isLessThanOrEqualTo: now)
            .get();

        for (final alarmDoc in alarmsSnapshot.docs) {
          final alarmData = alarmDoc.data();
          final alarmTime = (alarmData['scheduledTime'] as Timestamp).toDate();

          final exists = await FirebaseFirestore.instance
              .collection('medi')
              .doc(user.uid)
              .collection('notificationHistory')
              .where('medicineId', isEqualTo: medicineId)
              .limit(1)
              .get();

          if (exists.docs.isEmpty) {
            await FirebaseFirestore.instance
                .collection('medi')
                .doc(user.uid)
                .collection('notificationHistory')
                .add({
              'medicineId': medicineId,
              'medicineName': medData['medicineName'] ?? 'Unknown',
              'dose': medData['dose'] ?? '',
              'timestamp': alarmTime,
              'read': false,
            });
          }

          await alarmDoc.reference.update({'notified': true});
        }
      }

      if (mounted) setState(() => _hasPermissionError = false);
    } catch (e) {
      if (mounted) setState(() => _hasPermissionError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          buildBackground(),
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.notifications, color: primaryMagenta),
                            SizedBox(width: 8),
                            Text("Notifications",
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const Spacer(),

                      /// unread count (same, OK)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('medi')
                            .doc(user?.uid)
                            .collection('notificationHistory')
                            .where('read', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.docs.length ?? 0;
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [primaryMagenta, primaryPurple]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "$count New",
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                if (_hasPermissionError)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "Permission error detected",
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('medi')
                        .doc(user?.uid)
                        .collection('notificationHistory')
                        .where('read', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "No notifications yet",
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final bool isRead = data['read'] ?? false;
                          final Timestamp? timestamp = data['timestamp'];
                          final DateTime dateTime =
                              timestamp?.toDate() ?? DateTime.now();

                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.only(right: 20),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteNotification(doc.id),
                            child: GestureDetector(
                              onTap: () async {
                                await doc.reference.update({'read': true});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      isRead
                                          ? Colors.white.withOpacity(0.08)
                                          : primaryMagenta.withOpacity(0.15),
                                      Colors.white.withOpacity(0.03),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.notifications_active,
                                        color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          const Text("Medicine Reminder",
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          Text(
                                            "Take ${data['medicineName']} ${data['dose']}",
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                          Text(
                                            DateFormat('dd MMM yyyy hh:mm a')
                                                .format(dateTime),
                                            style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
}