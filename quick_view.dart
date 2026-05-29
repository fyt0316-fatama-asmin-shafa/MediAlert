import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../common_widgets.dart';
import '../profile_edit_page.dart';
import '../main.dart'; // for flutterLocalNotificationsPlugin

class QuickViewScreen extends StatefulWidget {
  const QuickViewScreen({super.key});

  @override
  State<QuickViewScreen> createState() => _QuickViewScreenState();
}

class _QuickViewScreenState extends State<QuickViewScreen> {
  final List<String> frequencyOptions = ['1 time a day', '2 times a day', '3 times a day', '4 times a day'];
  final List<String> intakeOptions = ['Before Meal', 'After Meal', 'With Meal'];

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatAlarmTime(String timeStr) {
    try {
      final format = DateFormat('HH:mm');
      final DateTime dateTime = format.parse(timeStr);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return timeStr;
    }
  }

  List<String> _parseMultipleTimes(String alarmTimeStr) {
    if (alarmTimeStr.isEmpty) return [];
    List<String> times = [];
    try {
      List<String> parts = alarmTimeStr.split(',');
      for (String part in parts) {
        if (part.trim().isNotEmpty) {
          times.add(_formatAlarmTime(part.trim()));
        }
      }
    } catch (e) {
      times.add(_formatAlarmTime(alarmTimeStr));
    }
    return times;
  }

  String _getCurrentFormattedDate() {
    return DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
  }

  String _getCurrentFormattedTime() {
    return DateFormat('h:mm a').format(DateTime.now());
  }

  Widget _buildUserProfile() {
    User? user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('medi').doc(user?.uid).get(),
      builder: (context, snapshot) {
        String userName = 'User';
        String? profileImageBase64;
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          userName = data['name'] ?? 'User';
          profileImageBase64 = data['profileImage'];
        }
        return GestureDetector(
          onTap: () async {
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileEditPage(userData: data)),
              );
              if (result == true) setState(() {});
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [primaryMagenta, primaryPurple]),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: profileImageBase64 != null && profileImageBase64.isNotEmpty
                        ? MemoryImage(base64Decode(profileImageBase64))
                        : null,
                    child: (profileImageBase64 != null && profileImageBase64.isNotEmpty)
                        ? null
                        : const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Delete Medicine ----------
  Future<void> _deleteMedicine(BuildContext context, String medicineId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: darkBgEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Medicine', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this medicine?\nAll reminders will be removed.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (!kIsWeb) {
      await _cancelAllNotificationsForMedicine(medicineId);
    }

    final alarmsSnapshot = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .collection('alarms')
        .get();
    for (var doc in alarmsSnapshot.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine deleted successfully'), backgroundColor: Colors.green),
      );
    }
  }

  // ---------- Edit Medicine (with fixed duration and dark theme) ----------
  Future<void> _editMedicine(BuildContext context, String medicineId, Map<String, dynamic> currentData) async {
    TextEditingController nameController = TextEditingController(text: currentData['medicineName'] ?? '');
    TextEditingController doseController = TextEditingController(text: currentData['dose'] ?? '');
    TextEditingController quantityController = TextEditingController(text: currentData['quantity'] ?? '');

    String frequency = currentData['frequency'] ?? '3 times a day';
    String intakeType = currentData['intakeType'] ?? 'After Meal';
    DateTimeRange dateRange = DateTimeRange(
      start: (currentData['startDate'] as Timestamp).toDate(),
      end: (currentData['endDate'] as Timestamp).toDate(),
    );

    List<TimeOfDay> selectedTimes = [];
    String alarmTimeStr = currentData['alarmTime'] ?? '';
    if (alarmTimeStr.isNotEmpty) {
      try {
        List<String> parts = alarmTimeStr.split(',');
        for (String part in parts) {
          List<String> hm = part.split(':');
          if (hm.length == 2) {
            selectedTimes.add(TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1])));
          }
        }
      } catch (e) {
        List<String> hm = alarmTimeStr.split(':');
        if (hm.length == 2) {
          selectedTimes.add(TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1])));
        }
      }
    }
    int targetCount = _getTimesPerDay(frequency);
    while (selectedTimes.length < targetCount) {
      selectedTimes.add(const TimeOfDay(hour: 12, minute: 0));
    }
    if (selectedTimes.length > targetCount) {
      selectedTimes = selectedTimes.sublist(0, targetCount);
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: darkBgEnd,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Medicine', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEditField(nameController, 'Medicine Name', Icons.medication),
                  const SizedBox(height: 12),
                  _buildEditField(doseController, 'Dose (e.g., 500mg)', Icons.monitor_weight),
                  const SizedBox(height: 12),
                  _buildEditField(quantityController, 'Quantity', Icons.inventory_2_outlined),
                  const SizedBox(height: 12),

                  // Intake dropdown (dark theme)
                  _buildDarkDropdown(
                    label: 'Intake',
                    value: intakeType,
                    items: intakeOptions,
                    icon: Icons.restaurant_rounded,
                    onChanged: (val) => setDialogState(() => intakeType = val!),
                  ),
                  const SizedBox(height: 12),

                  // Frequency dropdown (dark theme)
                  _buildDarkDropdown(
                    label: 'Frequency',
                    value: frequency,
                    items: frequencyOptions,
                    icon: Icons.loop_rounded,
                    onChanged: (val) {
                      setDialogState(() {
                        frequency = val!;
                        int newCount = _getTimesPerDay(frequency);
                        while (selectedTimes.length < newCount) {
                          selectedTimes.add(const TimeOfDay(hour: 12, minute: 0));
                        }
                        if (selectedTimes.length > newCount) {
                          selectedTimes = selectedTimes.sublist(0, newCount);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // ----- DURATION (fixed: now updates correctly) -----
                  _buildDarkGlassBox(
                    icon: Icons.calendar_month_rounded,
                    title: 'Course Duration',
                    value: '${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}',
                    onTap: () async {
                      DateTimeRange? newRange = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: dateRange,
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.black,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black,
                            ),
                            dialogTheme: const DialogThemeData(
                              backgroundColor: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (newRange != null) {
                        setDialogState(() {
                          dateRange = newRange;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Dose Times', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),

                  ...List.generate(selectedTimes.length, (idx) {
                    String doseLabel = idx == 0 ? '1st Dose' : idx == 1 ? '2nd Dose' : idx == 2 ? '3rd Dose' : '${idx + 1}th Dose';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildDarkGlassBox(
                        icon: Icons.access_time_filled_rounded,
                        title: doseLabel,
                        value: selectedTimes[idx].format(context),
                        onTap: () async {
                          TimeOfDay? newTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTimes[idx],
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.grey,
                                  onPrimary: Colors.white,
                                  surface: Colors.black,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (newTime != null) {
                            setDialogState(() => selectedTimes[idx] = newTime);
                          }
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, {
                    'name': nameController.text.trim(),
                    'dose': doseController.text.trim(),
                    'quantity': quantityController.text.trim(),
                    'intakeType': intakeType,
                    'frequency': frequency,
                    'dateRange': dateRange,
                    'selectedTimes': selectedTimes,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await _saveEditedMedicine(medicineId, result);
    }
  }

  // ----- Dark glass box (no pink, all dark/white) -----
  Widget _buildDarkGlassBox({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.8)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                    Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Dark dropdown -----
  Widget _buildDarkDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.8)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: darkBgEnd,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            icon: Icon(Icons.arrow_drop_down, color: Colors.white70),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(item, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.8),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white54),
          icon: Icon(icon, color: Colors.white70),
          border: InputBorder.none,
        ),
      ),
    );
  }

  int _getTimesPerDay(String freq) {
    switch (freq) {
      case '1 time a day': return 1;
      case '2 times a day': return 2;
      case '3 times a day': return 3;
      case '4 times a day': return 4;
      default: return 3;
    }
  }

  // ---------- Save edited medicine ----------
  Future<void> _saveEditedMedicine(String medicineId, Map<String, dynamic> newData) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!kIsWeb) {
      await _cancelAllNotificationsForMedicine(medicineId);
    }

    final alarmsSnapshot = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .collection('alarms')
        .get();
    for (var doc in alarmsSnapshot.docs) {
      await doc.reference.delete();
    }

    DateTimeRange range = newData['dateRange'];
    List<TimeOfDay> selectedTimes = newData['selectedTimes'];
    String alarmTimeStr = selectedTimes.map((tod) => '${tod.hour}:${tod.minute}').join(',');

    List<DateTime> alarmTimes = [];
    DateTime current = range.start;
    while (!current.isAfter(range.end)) {
      for (TimeOfDay tod in selectedTimes) {
        DateTime dt = DateTime(current.year, current.month, current.day, tod.hour, tod.minute);
        if (dt.isAfter(DateTime.now())) {
          alarmTimes.add(dt);
        }
      }
      current = current.add(const Duration(days: 1));
    }
    if (alarmTimes.length > 2000) alarmTimes = alarmTimes.sublist(0, 2000);

    await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .update({
      'medicineName': newData['name'],
      'dose': newData['dose'],
      'quantity': newData['quantity'],
      'intakeType': newData['intakeType'],
      'frequency': newData['frequency'],
      'startDate': range.start,
      'endDate': range.end,
      'alarmTime': alarmTimeStr,
    });

    if (!kIsWeb) {
      await _saveAlarmsInBatches(user.uid, medicineId, alarmTimes);
      await _scheduleNotificationsForMedicine(medicineId, alarmTimes);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicine updated successfully'), backgroundColor: Colors.green),
    );
  }

  Future<void> _cancelAllNotificationsForMedicine(String medicineId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || kIsWeb) return;
    final alarms = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .collection('alarms')
        .get();
    for (var doc in alarms.docs) {
      int? nid = doc['notificationId'] as int?;
      if (nid != null) {
        await flutterLocalNotificationsPlugin.cancel(nid);
      }
    }
  }

  Future<void> _saveAlarmsInBatches(String userId, String medicineId, List<DateTime> alarmTimes) async {
    const int batchSize = 400;
    for (int i = 0; i < alarmTimes.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      int end = (i + batchSize < alarmTimes.length) ? i + batchSize : alarmTimes.length;
      for (int j = i; j < end; j++) {
        final alarmTime = alarmTimes[j];
        if (alarmTime.isAfter(DateTime.now())) {
          final docRef = FirebaseFirestore.instance
              .collection('medi')
              .doc(userId)
              .collection('medicines')
              .doc(medicineId)
              .collection('alarms')
              .doc();
          batch.set(docRef, {
            'scheduledTime': alarmTime,
            'notified': false,
            'notificationId': (medicineId.hashCode.abs() + alarmTime.millisecondsSinceEpoch) % 2147483647
          });
        }
      }
      await batch.commit();
      if (i + batchSize < alarmTimes.length) await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  Future<void> _scheduleNotificationsForMedicine(String medicineId, List<DateTime> alarmTimes) async {
    if (kIsWeb) return;
    for (DateTime alarmTime in alarmTimes) {
      int notificationId = (medicineId.hashCode.abs() + alarmTime.millisecondsSinceEpoch) % 2147483647;
      String payload = '$medicineId|${alarmTime.millisecondsSinceEpoch}';
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'MediAlert Reminder',
        'Time to take your medicine',
        tz.TZDateTime.from(alarmTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_channel',
            'Medicine Reminders',
            importance: Importance.max,
            priority: Priority.high,
            sound: null,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      buildGlowingLogoSmall(),
                      const Spacer(),
                      _buildUserProfile(),
                    ],
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility, color: primaryMagenta, size: 20),
                              SizedBox(width: 8),
                              Text('Quick View', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            Text(
                              _getCurrentFormattedDate(),
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getCurrentFormattedTime(),
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('medi')
                        .doc(user?.uid)
                        .collection('medicines')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No medicines added", style: TextStyle(color: Colors.white54)));
                      }

                      final docs = snapshot.data!.docs;
                      final now = DateTime.now();
                      List<QueryDocumentSnapshot> sortedDocs = List.from(docs);
                      sortedDocs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final startA = (dataA['startDate'] as Timestamp).toDate();
                        final endA = (dataA['endDate'] as Timestamp).toDate();
                        final startB = (dataB['startDate'] as Timestamp).toDate();
                        final endB = (dataB['endDate'] as Timestamp).toDate();

                        final bool activeA = now.isAfter(startA) && now.isBefore(endA);
                        final bool activeB = now.isAfter(startB) && now.isBefore(endB);

                        if (activeA == activeB) return 0;
                        return activeA ? -1 : 1;
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: sortedDocs.length,
                        itemBuilder: (context, index) {
                          final doc = sortedDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final medicineId = doc.id;
                          final start = (data['startDate'] as Timestamp).toDate();
                          final end = (data['endDate'] as Timestamp).toDate();
                          final bool active = now.isBefore(
                            end.add(const Duration(days: 1)),
                          );
                          final List<String> doseTimes = _parseMultipleTimes(data['alarmTime'] ?? '');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 15, offset: const Offset(0, 8))],
                              border: Border.all(color: active ? Colors.green.withOpacity(0.4) : Colors.orange.withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [primaryMagenta, primaryPurple]),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.medication, color: Colors.black),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(data['medicineName'] ?? '',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text('${data['frequency']} • ${data['intakeType']}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                          onPressed: () => _editMedicine(context, medicineId, data),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () => _deleteMedicine(context, medicineId),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: active ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(active ? "Active" : "Expired",
                                              style: TextStyle(color: active ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.medication, size: 16, color: primaryMagenta),
                                          const SizedBox(width: 8),
                                          Text("Dose: ${data['dose']} • Qty: ${data['quantity']}",
                                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (doseTimes.isNotEmpty) ...[
                                        const Divider(color: Colors.white24),
                                        const Text("Reminder Times:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: doseTimes.map((time) => Chip(
                                            label: Text(time, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                            backgroundColor: primaryMagenta.withOpacity(0.3),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          )).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range, size: 16, color: Colors.white54),
                                      const SizedBox(width: 8),
                                      Text("Duration: ${DateFormat('dd MMM yyyy').format(start)} → ${DateFormat('dd MMM yyyy').format(end)}",
                                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
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