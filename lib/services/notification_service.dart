import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart'; // สำหรับใช้ Color

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // 🔑 กำหนด ID และชื่อที่นี่ "ที่เดียว" (จะได้แก้ทีเดียวจบ ไม่หลง)
  // เปลี่ยนเป็น v99 เพื่อหนีค่าเก่าที่เครื่องจำไว้แน่นอน
  static const String _emergencyChannelId = 'medical_alert_channel_v99';
  static const String _emergencyChannelName = '🔴 แจ้งเตือนฉุกเฉิน (สำคัญมาก)';
  static const String _emergencyChannelDesc = 'แสดงข้อมูล Medical ID ตลอดเวลาเมื่อเปิดโหมดฉุกเฉิน';

  static Future init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(settings);

    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // 1. ขออนุญาต
    await androidImplementation?.requestNotificationsPermission();

    // 2. ⚡ บังคับสร้าง Channel ทันทีที่เปิดแอป (เพื่อฝังค่า ongoing ลงเครื่อง)
    const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
      _emergencyChannelId, // ใช้ตัวแปร ID
      _emergencyChannelName, // ใช้ตัวแปรชื่อ
      description: _emergencyChannelDesc,
      importance: Importance.max, // ความสำคัญสูงสุด
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // สั่งสร้างลงเครื่องเลย
    await androidImplementation?.createNotificationChannel(emergencyChannel);
  }

  // ฟังก์ชันเปิดโหมดฉุกเฉิน
  static Future showEmergencyNotification({
    required String name,
    required String allergy,
    required String bloodType,
    required String emergencyContact,
  }) async {
    // ตั้งค่ารูปแบบการแจ้งเตือน
    final androidDetails = AndroidNotificationDetails(
      _emergencyChannelId, // ✅ ต้องตรงกับข้างบนเป๊ะๆ (ใช้ตัวแปรเดียวกัน)
      _emergencyChannelName, // ✅ ชื่อต้องตรงกัน
      channelDescription: _emergencyChannelDesc,

      importance: Importance.max,
      priority: Priority.max,

      // 🔥 หัวใจสำคัญของการลบไม่ได้
      ongoing: true, // เป็น process ที่กำลังทำงาน (เหมือนเปิดเพลง)
      autoCancel: false, // กดแล้วไม่หาย
      // การตั้งค่าเสริม
      color: const Color(0xFFFF0000), // สีแดง
      onlyAlertOnce: true,
      showWhen: true,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.call, // ตั้งเป็นหมวด Call หรือ Alarm จะลบยากขึ้น
      // ป้องกันเพิ่มเติมสำหรับ Android รุ่นใหม่
      fullScreenIntent: true,
      actions: [
        // เพิ่มปุ่มหลอกๆ เพื่อให้มันดูสำคัญ (Optional)
        // const AndroidNotificationAction('id_1', 'เปิดแอป', showsUserInterface: true),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      888, // ID ของ Notification
      'SOS: $name (เลือด $bloodType)',
      'แพ้: $allergy | โทร: $emergencyContact',
      details,
    );
  }

  static Future showWarningNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'warning_channel_id_v1', // แยก ID ต่างหาก
      'แจ้งเตือนล่วงหน้า',
      channelDescription: 'เตือนก่อนส่ง SOS',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(777, '⏰ เตือนความจำ', message, details);
  }

  static Future cancelNotification() async {
    await _notifications.cancel(888);
  }
}
