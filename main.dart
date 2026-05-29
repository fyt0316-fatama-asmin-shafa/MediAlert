import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'medicine_scanner.dart';
import 'auth_wrapper.dart';
import 'loading_screen.dart';
import 'profile_edit_page.dart';
import 'common_widgets.dart';
import 'screens/quick_view.dart';
import 'screens/notification_history.dart';
import 'screens/physical_condition.dart';
import 'screens/history.dart';
import 'alarm_dialog.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
Future<void> initNotifications() async {
  const AndroidInitializationSettings androidInit =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosInit =
  DarwinInitializationSettings();

  const InitializationSettings settings =
  InitializationSettings(android: androidInit, iOS: iosInit);

  await flutterLocalNotificationsPlugin.initialize(settings);
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: " ",
      appId: "1:267657249954:web:01165929839cb83e7e03fb",
      messagingSenderId: "267657249954",
      projectId: "medialert-a04d5",
      authDomain: "medialert-a04d5.firebaseapp.com",
      storageBucket: "medialert-a04d5.appspot.com",
    ),
  );

  if (!kIsWeb) {
    await Permission.notification.request();
    await requestExactAlarmPermission();
    await initializeNotifications();
    await requestExactAlarmPermission();
    await requestIgnoreBatteryOptimizations(); // NEW
    final androidPlugin =
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (await Permission.notification.isDenied ||
        await Permission.notification.isPermanentlyDenied) {
      await Permission.notification.request();
    }

  }

  runApp(const MediAlertApp());
}
Future<void> handleAlarmFire(String payload) async {
  await addNotificationToHistory(payload);
}
// NEW: Ask user to disable battery optimization
Future<void> requestIgnoreBatteryOptimizations() async {
  if (Platform.isAndroid) {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (!result.isGranted) {
        // Show educational dialog
        // We'll show it later in the app to avoid blocking startup
      }
    }
  }
}

Future<void> requestExactAlarmPermission() async {
  if (Platform.isAndroid) {
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }
}
Future<void> initializeNotifications() async {
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

  const AndroidNotificationChannel channel =
  AndroidNotificationChannel(
    'medicine_channel',
    'Medicine Reminders',
    description: 'Medicine alarm notifications',
    importance: Importance.max,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.requestNotificationsPermission();

  await androidPlugin?.createNotificationChannel(channel);

  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
  DarwinInitializationSettings();

  const InitializationSettings settings =
  InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (response) async {
      if (response.actionId == 'STOP_ACTION') {
        final int? id = response.id;

        if (id != null) {
          await flutterLocalNotificationsPlugin.cancel(id);
        }

        FlutterRingtonePlayer().stop();
        return;
      }

      final payload = response.payload;
      if (payload != null) {
        // your existing dialog logic...
      }
    },

    onDidReceiveBackgroundNotificationResponse:
    notificationTapBackground,
  );
}
// Test notification (use default sound)
Future<void> scheduleTestNotification() async {
  final testTime = DateTime.now().add(const Duration(seconds: 10));
  await flutterLocalNotificationsPlugin.zonedSchedule(
    999999,
    "Test Alarm",
    "If you see this, notifications work!",
    tz.TZDateTime.from(testTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_channel',
        'Medicine Reminders',

        channelDescription: 'Medicine alarm notifications',

        importance: Importance.max,
        priority: Priority.max,

        playSound: true,

        sound: RawResourceAndroidNotificationSound('alarm'),

        audioAttributesUsage: AudioAttributesUsage.alarm,

        enableVibration: true,

        fullScreenIntent: true,

        category: AndroidNotificationCategory.alarm,

        visibility: NotificationVisibility.public,

        ongoing: true,

        autoCancel: false,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    payload: "test|123",
  );
  print("Test notification scheduled for ${testTime.toLocal()}");
}

// Updated history function with duplicate prevention and alarm marking
Future<void> addNotificationToHistory(String payload) async {
  try {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final parts = payload.split('|');

    if (parts.length != 2) return;

    final medicineId = parts[0];
    final alarmMillis = int.parse(parts[1]);

    final alarmDateTime =
    DateTime.fromMillisecondsSinceEpoch(alarmMillis);

    // 🔍 Duplicate check
    final duplicateCheck = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('notificationHistory')
        .where('medicineId', isEqualTo: medicineId)
        .where('timestamp', isEqualTo: alarmDateTime)
        .limit(1)
        .get();

    // ❌ Already exists
    if (duplicateCheck.docs.isNotEmpty) {
      return;
    }

    // 🔍 Get medicine data
    final medicineDoc = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .get();

    if (!medicineDoc.exists) return;

    final medData = medicineDoc.data() as Map<String, dynamic>;

    // ✅ Add to notification history
    await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('notificationHistory')
        .add({
      'medicineId': medicineId,
      'medicineName': medData['medicineName'] ?? 'Unknown',
      'dose': medData['dose'] ?? '',
      'timestamp': alarmDateTime,
      'read': false,
    });

    // ✅ Mark alarm as notified
    final alarmDocs = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .collection('alarms')
        .where('scheduledTime', isEqualTo: alarmDateTime)
        .limit(1)
        .get();

    if (alarmDocs.docs.isNotEmpty) {
      await alarmDocs.docs.first.reference.update({
        'notified': true,
      });
    }

    debugPrint("✅ Notification added to history");

  } catch (e) {
    debugPrint("❌ History Error: $e");
  }
}

Future<void> sendSmsToUser(String payload) async {
  try {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .get();
    final phoneNumber = userDoc.data()?['phone'] ?? '';
    if (phoneNumber.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length != 2) return;
    final medicineId = parts[0];
    final medicineDoc = await FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .doc(medicineId)
        .get();
    final medicineName = medicineDoc.data()?['medicineName'] ?? 'your medicine';
    final message = 'MediAlert Reminder: Time to take $medicineName.';
    final smsUri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  } catch (e) {
    debugPrint('SMS error: $e');
  }
}

// ===================== 6‑MONTH PERSISTENT LOGIN =====================
Future<bool> isLoginExpired() async {
  final prefs = await SharedPreferences.getInstance();
  final lastLoginMillis = prefs.getInt('last_login_timestamp');
  if (lastLoginMillis == null) return true;
  final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMillis);
  final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
  return lastLogin.isBefore(sixMonthsAgo);
}

Future<void> clearLoginTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('last_login_timestamp');
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAndHandleExpiration();
  }

  Future<void> _checkAndHandleExpiration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final expired = await isLoginExpired();
      if (expired) {
        await FirebaseAuth.instance.signOut();
        await clearLoginTimestamp();
      }
    }
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) return const LoadingScreen();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        User? user = snapshot.data;
        if (user == null) return const AuthWrapper();
        return const MainPage();
      },
    );
  }
}

class MediAlertApp extends StatelessWidget {
  const MediAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MediAlert',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const AuthGate(),
    );
  }
}

// ===================== MAIN PAGE =====================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _hasMedicines = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserMedicinesStatus();
  }

  Future<void> _checkUserMedicinesStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _hasMedicines = false;
        _isLoading = false;
        _currentIndex = 1;
      });
      return;
    }
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('medi')
          .doc(user.uid)
          .collection('medicines')
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      final hasMedicines = snapshot.docs.isNotEmpty;
      setState(() {
        _hasMedicines = hasMedicines;
        _isLoading = false;
        _currentIndex = hasMedicines ? 0 : 1;
      });
    } catch (e) {
      setState(() {
        _hasMedicines = false;
        _isLoading = false;
        _currentIndex = 1;
      });
    }
  }

  Stream<bool> _listenToMedicineChanges() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return FirebaseFirestore.instance
        .collection('medi')
        .doc(user.uid)
        .collection('medicines')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final hasMedicines = snapshot.docs.isNotEmpty;
      // Only update if changed
      if (_hasMedicines != hasMedicines) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasMedicines = hasMedicines;
              _currentIndex = hasMedicines ? 0 : 1;
            });
          }
        });
      }
      return hasMedicines;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            buildBackground(),
            Container(color: Colors.black.withOpacity(0.5)),
            const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryMagenta))),
          ],
        ),
      );
    }
    return StreamBuilder<bool>(
      stream: _listenToMedicineChanges(),
      initialData: _hasMedicines,
      builder: (context, snapshot) {
        final List<Widget> _screens = [
          const QuickViewScreen(),
          const MedicineEntryScreen(),
          const NotificationHistoryScreen(),
          const PhysicalConditionScreen(),
          const HistoryScreen(),
        ];
        return Scaffold(
          body: _screens[_currentIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [darkBgStart.withOpacity(0.95), darkBgEnd.withOpacity(0.95)],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: primaryMagenta,
              unselectedItemColor: Colors.white54,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.visibility), label: 'Quick View'),
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '🔔'),
                BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Health'),
                BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===================== MEDICINE ENTRY SCREEN =====================
class MedicineEntryScreen extends StatefulWidget {
  const MedicineEntryScreen({super.key});

  @override
  State<MedicineEntryScreen> createState() => _MedicineEntryScreenState();
}

class _MedicineEntryScreenState extends State<MedicineEntryScreen> {
  List<Map<String, dynamic>> medicines = [];
  final uuid = const Uuid();
  bool isLoading = false;
  bool isScanning = false;
  int? editingMedicineIndex;

  final List<String> frequencyOptions = ['1 time a day', '2 times a day', '3 times a day', '4 times a day'];
  final List<String> intakeOptions = ['Before Meal', 'After Meal', 'With Meal'];

  int _getTimesPerDay(String freq) {
    switch (freq) {
      case '1 time a day': return 1;
      case '2 times a day': return 2;
      case '3 times a day': return 3;
      case '4 times a day': return 4;
      default: return 3;
    }
  }

  void _updateTimesForMedicine(Map<String, dynamic> medicine, String newFrequency) {
    int timesPerDay = _getTimesPerDay(newFrequency);
    List<TimeOfDay> currentTimes = List.from(medicine['selectedTimes'] ?? []);
    List<TimeOfDay> newTimes = [];
    for (int i = 0; i < timesPerDay; i++) {
      if (i < currentTimes.length) {
        newTimes.add(currentTimes[i]);
      } else {
        switch (i) {
          case 0: newTimes.add(const TimeOfDay(hour: 8, minute: 0)); break;
          case 1: newTimes.add(const TimeOfDay(hour: 14, minute: 0)); break;
          case 2: newTimes.add(const TimeOfDay(hour: 20, minute: 0)); break;
          case 3: newTimes.add(const TimeOfDay(hour: 2, minute: 0)); break;
          default: newTimes.add(const TimeOfDay(hour: 12, minute: 0));
        }
      }
    }
    medicine['selectedTimes'] = newTimes;
  }

  void _addNewMedicine() {
    setState(() {
      medicines.add({
        'id': uuid.v4(),
        'name': '',
        'dose': '',
        'quantity': '',
        'intakeType': 'After Meal',
        'frequency': '3 times a day',
        'selectedTimes': <TimeOfDay>[],
        'dateRange': null,
        'nameController': TextEditingController(),
        'doseController': TextEditingController(),
        'qtyController': TextEditingController(),
      });
      _updateTimesForMedicine(medicines.last, medicines.last['frequency']);
    });
  }

  void _removeMedicine(int index) {
    setState(() => medicines.removeAt(index));
  }

  void _updateMedicineField(int index, String field, dynamic value) {
    setState(() => medicines[index][field] = value);
  }

  Future<void> _showImagePickerOptions(int index) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 200,
        decoration: BoxDecoration(
            color: darkBgEnd,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Select Image Source',
                style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(icon: Icons.camera_alt, label: 'Camera', onTap: () async { Navigator.pop(context); await _captureMedicineImage(index); }),
                _buildImagePickerOption(icon: Icons.photo_library, label: 'Gallery', onTap: () async { Navigator.pop(context); await _pickImageFromGallery(index); }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [primaryMagenta, primaryPurple]), borderRadius: BorderRadius.circular(20)),
        child: Column(
            children: [
              Icon(icon, color: Colors.black, size: 40),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.black))]),
      ),
    );
  }

  Future<void> _captureMedicineImage(int index) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (image != null) {
        setState(() { isScanning = true; editingMedicineIndex = index; });
        await _processMedicineImage(image, index);
      }
    } catch (e) {
      setState(() { isScanning = false; editingMedicineIndex = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickImageFromGallery(int index) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (image != null) {
        setState(() { isScanning = true; editingMedicineIndex = index; });
        await _processMedicineImage(image, index);
      }
    } catch (e) {
      setState(() { isScanning = false; editingMedicineIndex = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _processMedicineImage(XFile image, int index) async {
    try {
      final scanner = MedicineScanner();
      final result = await scanner.extractMedicineInfo(File(image.path));
      setState(() {
        final name = result['medicineName'] ?? '';
        final dose = result['dose'] ?? '';
        medicines[index]['nameController'].text = name;
        medicines[index]['doseController'].text = dose;
        medicines[index]['name'] = name;
        medicines[index]['dose'] = dose;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine detected from image!'), backgroundColor: primaryMagenta));
    } catch (e) { print('Error processing image: $e'); } finally { setState(() { isScanning = false; editingMedicineIndex = null; }); }
  }

  List<DateTime> _calculateAlarmTimesForMedicine(Map<String, dynamic> medicine) {
    List<DateTime> alarmList = [];
    DateTimeRange? range = medicine['dateRange'];
    List<TimeOfDay> selectedTimes = medicine['selectedTimes'] ?? [];
    if (range == null || selectedTimes.isEmpty) return alarmList;
    DateTime currentDate = range.start;
    while (!currentDate.isAfter(range.end)) {
      for (TimeOfDay tod in selectedTimes) {
        final dt = DateTime(currentDate.year, currentDate.month, currentDate.day, tod.hour, tod.minute);
        // Only include future alarms
        if (dt.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
          alarmList.add(dt);
        }
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    // Limit to 2000 alarms to avoid overload
    if (alarmList.length > 2000) {
      print('Too many alarms, limiting to 2000.');
      return alarmList.sublist(0, 2000);
    }
    return alarmList;
  }

  Future<void> _scheduleNotificationsForMedicine(
      String medicineId,
      List<DateTime> alarmTimes,
      ) async {
    print("🔥 TOTAL ALARMS: ${alarmTimes.length}");
    if (kIsWeb) return;

    for (DateTime alarmTime in alarmTimes) {
      print("➡️ Scheduling: $alarmTime");
      final now = tz.TZDateTime.now(tz.local);

      final scheduled = tz.TZDateTime.from(alarmTime, tz.local);

      if (scheduled.isBefore(now)) continue;
        int notificationId =
            (medicineId.hashCode.abs() +
                alarmTime.millisecondsSinceEpoch) %
                2147483647;

        String payload =
            '$medicineId|${alarmTime.millisecondsSinceEpoch}';

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Medicine Reminder',
        'Time to take your medicine',

        tz.TZDateTime.from(alarmTime, tz.local),

        NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_channel',
            'Medicine Reminders',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,

            playSound: true,
            enableVibration: true,

            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'STOP_ACTION',
                'STOP',
                cancelNotification: true,
              ),
            ],
          ),
        ),

        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
          payload: jsonEncode({
            'medicineId': medicineId,
            'time': alarmTime.millisecondsSinceEpoch,
          }),
      );
      await FirebaseFirestore.instance
          .collection('medi')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('notificationHistory')
          .add({
        'medicineId': medicineId,
        'medicineName': 'Medicine',
        'dose': '',
        'timestamp': alarmTime,
        'read': false,
      });
        await flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          'Medicine Reminder',
          'Time to take your medicine',
          tz.TZDateTime.from(alarmTime, tz.local),

          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medicine_channel',
              'Medicine Reminders',

              importance: Importance.max,
              priority: Priority.high,

              playSound: true,
              sound: RawResourceAndroidNotificationSound('alarm'),
              audioAttributesUsage: AudioAttributesUsage.alarm,

              enableVibration: true,

              fullScreenIntent: true,

              category: AndroidNotificationCategory.alarm,

              visibility: NotificationVisibility.public,

              ongoing: true,
              autoCancel: false,

              ticker: 'Medicine Alarm',
            ),

            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),

          androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,

          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,

          payload: payload,
        );

        print("✅ Scheduled: $alarmTime");
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
          final docRef = FirebaseFirestore.instance.collection('medi').doc(userId).collection('medicines').doc(medicineId).collection('alarms').doc();
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

  Future<void> _saveMedicines() async {
    if (medicines.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one medicine'))); return; }
    for (var med in medicines) {
      if (med['name'].toString().trim().isEmpty || med['dose'].toString().trim().isEmpty || med['quantity'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields (name, dose, quantity) for all medicines'))); return;
      }
      if (med['dateRange'] == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set course duration for each medicine'))); return; }
      List<TimeOfDay> times = med['selectedTimes'];
      if (times.isEmpty || times.any((t) => t == null)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set all alarm times for each medicine'))); return; }
    }
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      String batchId = const Uuid().v4();
      for (var med in medicines) {
        String medicineId = med['id'];
        DateTimeRange originalRange = med['dateRange'];
        DateTime limitedEnd = originalRange.end.isAfter(DateTime.now().add(const Duration(days: 365))) ? DateTime.now().add(const Duration(days: 365)) : originalRange.end;
        if (limitedEnd != originalRange.end) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course duration limited to 1 year for performance.'))); med['dateRange'] = DateTimeRange(start: originalRange.start, end: limitedEnd); }
        List<DateTime> alarmTimes = _calculateAlarmTimesForMedicine(med);
        if (alarmTimes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No future alarms for ${med['name']}.'))); continue; }
        await FirebaseFirestore.instance.collection('medi').doc(user.uid).collection('medicines').doc(medicineId).set({
          'medicineName': med['name'], 'dose': med['dose'], 'quantity': med['quantity'],
          'intakeType': med['intakeType'], 'frequency': med['frequency'], 'startDate': med['dateRange'].start,
          'endDate': med['dateRange'].end, 'alarmTime': '${med['selectedTimes'].first.hour}:${med['selectedTimes'].first.minute}',
          'active': true, 'createdAt': FieldValue.serverTimestamp(), 'batchId': batchId,
        });
        await _saveAlarmsInBatches(user.uid, medicineId, alarmTimes);
        await _scheduleNotificationsForMedicine(medicineId, alarmTimes);
      }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${medicines.length} medicine(s) activated successfully!'), backgroundColor: Colors.green)); setState(() => medicines.clear()); _showSuccessDialog(); }
    } catch (e) { print('Save error: $e'); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); } finally { setState(() => isLoading = false); }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: darkBgEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 32), SizedBox(width: 10), Text('Success!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
        content: const Text('All medicines have been added successfully!\n\nYou can now see them in Quick View.', style: TextStyle(color: Colors.white70)),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: primaryMagenta, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('OK', style: TextStyle(color: Colors.white)))],
      ),
    );
  }

  Future<void> _selectDateRangeForMedicine(int index) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primaryMagenta, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black)), child: child!),
    );
    if (picked != null) _updateMedicineField(index, 'dateRange', picked);
  }

  Future<void> _selectTimeForDose(int medIndex, int doseIndex) async {
    TimeOfDay current = medicines[medIndex]['selectedTimes'][doseIndex];
    final time = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primaryMagenta, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black)), child: child!),
    );
    if (time != null) setState(() => medicines[medIndex]['selectedTimes'][doseIndex] = time);
  }

  Widget _buildMedicineCard(int index) {
    var med = medicines[index];
    List<TimeOfDay> times = med['selectedTimes'] ?? [];
    DateTimeRange? dateRange = med['dateRange'];
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('Medicine ${index + 1}', style: const TextStyle(color: primaryMagenta, fontWeight: FontWeight.bold, fontSize: 14))), if (medicines.length > 1) IconButton(onPressed: () => _removeMedicine(index), icon: const Icon(Icons.close, color: Colors.red, size: 20))]),
        const SizedBox(height: 16),
        Row(children: [Expanded(flex: 2, child: _buildMedicineInputField(hint: 'Medicine name', icon: Icons.medication, controller: med['nameController'], onChanged: (v) => _updateMedicineField(index, 'name', v))), const SizedBox(width: 8), GestureDetector(
          onTap: (isScanning && editingMedicineIndex == index) ? null : () => _showImagePickerOptions(index),
          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [primaryMagenta, primaryPurple]), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.25))),
              child: (isScanning && editingMedicineIndex == index) ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt, color: Colors.black, size: 24)),
        )]),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _buildMedicineInputField(hint: 'Dose (e.g., 500 mg)', icon: Icons.monitor_weight, controller: med['doseController'], onChanged: (v) => _updateMedicineField(index, 'dose', v))), const SizedBox(width: 12), Expanded(child: _buildMedicineInputField(hint: 'Quantity (e.g., 10)', icon: Icons.inventory_2_outlined, controller: med['qtyController'], onChanged: (v) => _updateMedicineField(index, 'quantity', v)))]),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black.withOpacity(0.3), border: Border.all(color: Colors.white.withOpacity(0.1))), child: Column(children: [
          const Text('SCHEDULE SETTINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 1)), const SizedBox(height: 12),
          _buildGlassBox(onTap: () => _selectDateRangeForMedicine(index), icon: Icons.calendar_month_rounded, title: 'Course Duration', value: dateRange == null ? 'Select Duration' : '${DateFormat('dd/MM').format(dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}'),
          const SizedBox(height: 12),
          _buildDropdownField(label: 'Frequency', value: med['frequency'], items: frequencyOptions, onChanged: (val) { if (val != null) { _updateMedicineField(index, 'frequency', val); _updateTimesForMedicine(medicines[index], val); } }, icon: Icons.loop_rounded),
          const SizedBox(height: 12),
          ...List.generate(times.length, (doseIdx) {
            String doseLabel = doseIdx == 0 ? '1st Dose' : doseIdx == 1 ? '2nd Dose' : doseIdx == 2 ? '3rd Dose' : '${doseIdx + 1}th Dose';
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildGlassBox(onTap: () => _selectTimeForDose(index, doseIdx), icon: Icons.access_time_filled_rounded, title: doseLabel, value: times[doseIdx].format(context)));
          }),
          const SizedBox(height: 8),
          _buildDropdownField(label: 'Intake', value: med['intakeType'], items: intakeOptions, onChanged: (val) => _updateMedicineField(index, 'intakeType', val!), icon: Icons.restaurant_rounded),
        ])),
      ]),
    );
  }

  Widget _buildMedicineInputField({required String hint, required IconData icon, required TextEditingController controller, required Function(String) onChanged}) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.black.withOpacity(0.3)), child: Row(children: [Icon(icon, color: Colors.pink), const SizedBox(width: 10), Expanded(child: TextFormField(controller: controller, onChanged: onChanged, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: hint, border: InputBorder.none)))]));
  }

  Widget _buildGlassBox({required IconData icon, required String title, String? value, VoidCallback? onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [darkBgStart.withOpacity(0.8), darkBgEnd.withOpacity(0.9)]), border: Border.all(color: Colors.white.withOpacity(0.15))), child: Row(children: [Icon(icon, color: primaryMagenta, size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFFFBFBFB), fontSize: 10, fontWeight: FontWeight.w500)), Text(value ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))]))]))));
  }

  Widget _buildDropdownField({required String label, required String value, required List<String> items, required Function(String?) onChanged, required IconData icon}) {
    return Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [darkBgStart.withOpacity(0.8), darkBgEnd.withOpacity(0.9)]), border: Border.all(color: Colors.white.withOpacity(0.15))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: darkBgEnd, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), icon: Icon(Icons.arrow_drop_down, color: primaryMagenta), items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Row(children: [Icon(icon, color: primaryMagenta, size: 16), const SizedBox(width: 8), Text(value, style: const TextStyle(color: Colors.white))]))).toList(), onChanged: onChanged))));
  }

  Widget _buildHeader() => Row(children: [buildGlowingLogoSmall(), const Spacer(), _buildUserProfile()]);

  Widget _buildUserProfile() {
    User? user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('medi').doc(user?.uid).get(), builder: (context, snapshot) {
      String userName = 'User';
      if (snapshot.hasData && snapshot.data!.exists) userName = (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? 'User';
      return GestureDetector(onTap: () async { if (snapshot.hasData && snapshot.data!.exists) { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileEditPage(userData: snapshot.data!.data() as Map<String, dynamic>))); if (result == true) setState(() {}); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)]), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.3))), child: Row(children: [Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [primaryMagenta, primaryPurple])), child: CircleAvatar(radius: 18, backgroundImage: (snapshot.hasData && snapshot.data!.exists && (snapshot.data!.data() as Map<String, dynamic>)['profileImage'] != null && (snapshot.data!.data() as Map<String, dynamic>)['profileImage'].toString().isNotEmpty) ? MemoryImage(base64Decode((snapshot.data!.data() as Map<String, dynamic>)['profileImage'])) : null, child: ((snapshot.hasData && snapshot.data!.exists && (snapshot.data!.data() as Map<String, dynamic>)['profileImage'] != null && (snapshot.data!.data() as Map<String, dynamic>)['profileImage'].toString().isNotEmpty) ? null : const Icon(Icons.person, color: Colors.white, size: 20)))), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(userName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))]), const SizedBox(width: 6), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.edit, color: Colors.white, size: 14))])));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackground(),
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  ...List.generate(medicines.length, (index) => _buildMedicineCard(index)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _addNewMedicine,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          primaryMagenta.withOpacity(0.2),
                          primaryPurple.withOpacity(0.2),
                        ]),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: primaryMagenta.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline, color: primaryMagenta, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            medicines.isEmpty ? 'Add Medicine' : 'Add Another Medicine',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: isLoading ? null : _saveMedicines,
                    child: buildPrimaryButton(
                      text: isLoading ? 'ACTIVATING...' : 'ACTIVATE ALL MEDICINES',
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildActiveMedicinesList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMedicinesList() {
    User? user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('medi').doc(user?.uid).collection('medicines').where('active', isEqualTo: true).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(
              child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Text('ACTIVE MEDICINES',
                  style: TextStyle(fontSize: 12,
                      letterSpacing: 1.2,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...snapshot.data!.docs.map((doc){
                  var data = doc.data() as Map<String,
                      dynamic>;
                  return
                    Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.05)]),
                            border: Border.all(color: Colors.white.withOpacity(0.2))),
                        child: Row(children: [Container(padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [primaryMagenta, primaryPurple]),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(
                                Icons.medication,
                                color: Colors.white,
                                size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [Text(data['medicineName'] ?? 'Unknown',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                    Text('${data['dose']} • ${data['frequency']} • ${data['intakeType']}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                    Text('Until ${DateFormat('dd/MM/yyyy').format((data['endDate'] as Timestamp).toDate())}',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10))])),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.withOpacity(0.5))),
                              child: const Text('Active',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)))]) );}).toList()]);
        });
  }
}
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAkUHxzVA6SxcTeheoytoWUAiuTKADWBQw",
      appId: "1:267657249954:web:01165929839cb83e7e03fb",
      messagingSenderId: "267657249954",
      projectId: "medialert-a04d5",
      storageBucket: "medialert-a04d5.appspot.com",
    ),
  );

  if (response.payload != null) {
    final data = jsonDecode(response.payload!);

    final medicineId = data['medicineId'];
    final time = data['time'];

    await addNotificationToHistory('$medicineId|$time');
  }
}
