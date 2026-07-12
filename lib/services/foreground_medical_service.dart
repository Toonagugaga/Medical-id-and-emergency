import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground Service สำหรับแสดง Medical ID Notification ที่ลบไม่ได้
class ForegroundMedicalService {
  // เก็บข้อมูลล่าสุดไว้ใน SharedPreferences เพื่อแสดงใหม่เมื่อถูกลบ
  static const String _prefKeyName = 'medical_id_name';
  static const String _prefKeyBloodType = 'medical_id_blood_type';
  static const String _prefKeyAllergy = 'medical_id_allergy';
  static const String _prefKeyContact = 'medical_id_contact';
  static const String _prefKeyIsActive = 'medical_id_active';

  /// Initialize Foreground Task (เรียกครั้งเดียวตอนเริ่มแอป)
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'medical_id_foreground_channel',
        channelName: '🔴 Medical ID (ลบไม่ได้)',
        channelDescription: 'แสดงข้อมูลฉุกเฉินตลอดเวลา',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: true, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        // ใช้ repeat event สำหรับแสดง notification ใหม่เมื่อถูกลบ
        eventAction: ForegroundTaskEventAction.repeat(5000), // ทุก 5 วินาที
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// บันทึกข้อมูล Medical ID ลง SharedPreferences
  static Future<void> _saveMedicalData({
    required String name,
    required String bloodType,
    required String allergy,
    required String emergencyContact,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyName, name);
    await prefs.setString(_prefKeyBloodType, bloodType);
    await prefs.setString(_prefKeyAllergy, allergy);
    await prefs.setString(_prefKeyContact, emergencyContact);
    await prefs.setBool(_prefKeyIsActive, true);
    await prefs.setBool('notification_dismissed', false); // Reset flag
  }

  /// ล้างข้อมูล Medical ID จาก SharedPreferences
  static Future<void> _clearMedicalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyIsActive, false);
  }

  /// เริ่ม Foreground Service พร้อมแสดง Medical ID
  static Future<void> startService({
    required String name,
    required String bloodType,
    required String allergy,
    required String emergencyContact,
  }) async {
    // บันทึกข้อมูลเพื่อใช้แสดงใหม่เมื่อ notification ถูกลบ
    await _saveMedicalData(name: name, bloodType: bloodType, allergy: allergy, emergencyContact: emergencyContact);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: '🆘 SOS: $name (เลือด $bloodType)',
        notificationText: '💊 แพ้: $allergy | 📞 โทร: $emergencyContact',
      );
      return;
    }

    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await FlutterForegroundTask.startService(
      notificationTitle: '🆘 SOS: $name (เลือด $bloodType)',
      notificationText: '💊 แพ้: $allergy | 📞 โทร: $emergencyContact',
      callback: _startCallback,
    );
    debugPrint('✅ Medical ID Foreground Service Started');
  }

  /// หยุด Foreground Service
  static Future<void> stopService() async {
    await _clearMedicalData();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      debugPrint('🛑 Medical ID Foreground Service Stopped');
    }
  }
}

// ===============================================================
// 👇 ส่วน TaskHandler - แสดง notification ใหม่เมื่อถูกลบ (เท่านั้น!)
// ===============================================================

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_MedicalIdTaskHandler());
}

class _MedicalIdTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('📱 Medical ID Task Handler Started');
  }

  // ทุกๆ 5 วินาที เช็คว่า notification ถูกลบหรือยัง
  @override
  void onRepeatEvent(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool('medical_id_active') ?? false;
    final wasDismissed = prefs.getBool('notification_dismissed') ?? false;

    // 🔑 แสดงใหม่เฉพาะเมื่อถูก dismiss เท่านั้น!
    if (isActive && wasDismissed) {
      final name = prefs.getString('medical_id_name') ?? '-';
      final bloodType = prefs.getString('medical_id_blood_type') ?? '-';
      final allergy = prefs.getString('medical_id_allergy') ?? '-';
      final contact = prefs.getString('medical_id_contact') ?? '-';

      // แสดง notification ใหม่
      await FlutterForegroundTask.updateService(
        notificationTitle: '🆘 SOS: $name (เลือด $bloodType)',
        notificationText: '💊 แพ้: $allergy | 📞 โทร: $contact',
      );

      // Reset flag หลังแสดงใหม่แล้ว
      await prefs.setBool('notification_dismissed', false);
      debugPrint('🔄 Notification re-shown after dismiss');
    }
  }

  // Callback เมื่อ notification ถูก dismiss (Android 13+)
  @override
  void onNotificationDismissed() async {
    debugPrint('⚠️ Notification was dismissed!');
    // ตั้ง flag ให้ onRepeatEvent รู้ว่าต้องแสดงใหม่
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_dismissed', true);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isSystemTermination) async {
    debugPrint('📱 Medical ID Task Handler Destroyed');
  }
}
