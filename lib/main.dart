import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'services/notification_service.dart';
import 'services/foreground_medical_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  // 1. ต้องมีบรรทัดนี้เสมอ
  WidgetsFlutterBinding.ensureInitialized();

  // 2. เริ่มต้นระบบแจ้งเตือน
  await NotificationService.init();

  // 3. เริ่มต้น Foreground Service สำหรับ Medical ID
  ForegroundMedicalService.init();

  // 4. เริ่มต้นระบบ Alarm Manager (เรียกครั้งเดียวพอครับ)
  try {
    await AndroidAlarmManager.initialize();
    print("✅ Alarm Manager Initialized");
  } catch (e) {
    print("❌ Alarm Manager Init Error: $e");
  }

  // 5. เช็คสถานะการเข้าใช้งานครั้งแรก
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(MyApp(onboardingComplete: onboardingComplete));
}

class MyApp extends StatelessWidget {
  final bool onboardingComplete;

  const MyApp({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medical ID',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: onboardingComplete ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
