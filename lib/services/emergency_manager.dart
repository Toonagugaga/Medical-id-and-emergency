// ไฟล์: lib/services/emergency_manager.dart

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
// ignore: unused_import
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart'; // ตัวใหม่สำหรับโทร
import 'package:android_intent_plus/flag.dart'; // สำหรับ Flag
import 'package:flutter/foundation.dart'; // สำหรับเช็ค Platform
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/warning_api_service.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/material.dart'; // จำเป็นสำหรับ WidgetsFlutterBinding

class EmergencyManager {
  static const int alarmId = 999;
  static const int warningAlarmId = 990;

  // 1. เริ่มระบบติดตาม (User กด Check-in)
  static Future<void> userCheckIn() async {
    // บันทึกเวลาล่าสุด
    await DatabaseHelper().updateLastCheckIn(DateTime.now());

    // รีเซ็ต Alarm เก่าทั้งหมด
    await stopTracking();

    print("⏳ กำลังพยายามตั้งเวลา...");

    // ดึงเวลาที่ User ตั้งไว้
    final db = DatabaseHelper();
    UserProfile? user = await db.getUser();
    int intervalMinutes = user?.checkInInterval ?? 120;

    print("✅ Check-in แล้ว! เริ่มนับถอยหลัง $intervalMinutes นาที");

    // --- 1.1 ตั้งเวลา SOS จริง ---
    await AndroidAlarmManager.oneShot(
      Duration(minutes: intervalMinutes),
      alarmId,
      fireEmergencyProtocol, // เรียกฟังก์ชัน Top-level ด้านล่าง
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot: true,
    );

    print("🎉 ตั้งเวลาสำเร็จจริงๆ! (Alarm Scheduled)");

    // --- 1.2 ตั้งเวลาแจ้งเตือนล่วงหน้า (25% ของเวลาทั้งหมด) ---
    int warningBuffer = (intervalMinutes * 25 ~/ 100).clamp(1, intervalMinutes - 1);
    if (intervalMinutes > warningBuffer) {
      await AndroidAlarmManager.oneShot(
        Duration(minutes: intervalMinutes - warningBuffer),
        warningAlarmId,
        fireWarningProtocol, // เรียกฟังก์ชัน Top-level ด้านล่าง
        exact: true,
        wakeup: true,
        alarmClock: true,
      );
    }
  }

  // ฟังก์ชันหยุดระบบติดตาม
  static Future<void> stopTracking() async {
    await AndroidAlarmManager.cancel(alarmId);
    await AndroidAlarmManager.cancel(warningAlarmId);
    await NotificationService.cancelNotification();
    print("🛑 หยุดระบบ Tracking แล้ว");
  }
}

// ==================================================================
// 👇 พื้นที่ Top-Level Function (อยู่นอก Class)
// สำคัญมาก! ต้องเอาไว้ตรงนี้ ระบบ Android ถึงจะเรียกใช้ตอนจอดับได้
// ==================================================================

// ฟังก์ชันดึง GPS (แยกออกมาเพื่อให้โค้ดสะอาด)
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
  );
}

@pragma('vm:entry-point')
void fireWarningProtocol() async {
  // ต้อง Init Binding ใหม่สำหรับ Isolate นี้
  WidgetsFlutterBinding.ensureInitialized();

  print("⚠️ WARNING ALARM FIRED!");
  HapticFeedback.heavyImpact();

  String msg = await WarningApiService.getRandomWarningMessage(15);
  await NotificationService.showWarningNotification(msg);
}

@pragma('vm:entry-point')
void fireEmergencyProtocol() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🚨 ALARM FIRED! เริ่มกระบวนการฉุกเฉิน");

  final db = DatabaseHelper();
  UserProfile? user = await db.getUser();

  // เช็คแค่ว่ามี User ไหม (ถ้าไม่มี User เลยค่อยหยุด)
  if (user == null) {
    print("❌ ไม่พบข้อมูลผู้ใช้งานในระบบ");
    return;
  }

  // --- ส่วนที่ 1: เตรียมข้อมูล GPS ---
  String mapLink = "No GPS";
  try {
    Position position = await _determinePosition();
    mapLink = "http://googleusercontent.com/maps.google.com/maps?q=${position.latitude},${position.longitude}";
  } catch (e) {
    print("GPS Error: $e");
  }

  // --- ส่วนที่ 2: ส่งอีเมล (ถ้ามีอีเมล) ---
  if (user.emergencyEmail != null && user.emergencyEmail!.isNotEmpty) {
    print("กำลังส่งอีเมลไปที่: ${user.emergencyEmail}");

    // ตั้งค่า Gmail ผู้ส่ง (Sender)
    String senderEmail = 'emergency.by.me@gmail.com'; // 🔴 แก้: อีเมลระบบ
    String senderPassword = 'xxx'; // 🔴 แก้: รหัส App Password

    final smtpServer = gmail(senderEmail, senderPassword);

    final message = Message()
      ..from = Address(senderEmail, 'Medical ID Alert')
      ..recipients.add(user.emergencyEmail)
      ..subject = 'SOS! แจ้งเตือนฉุกเฉิน: ${user.name}'
      ..text =
          'แจ้งเตือนฉุกเฉิน!\n\n'
          'ผู้ใช้งาน ${user.name} ขาดการติดต่อเกินกำหนด\n'
          'พิกัดล่าสุด:\n$mapLink\n\n'
          'กรุณาตรวจสอบด่วน!';

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ ส่งอีเมลสำเร็จ: ${sendReport.toString()}');
    } catch (e) {
      print('❌ ส่งอีเมลไม่ผ่าน: $e');
    }
  } else {
    // ถ้าไม่มีอีเมล ให้แจ้งเตือนเฉยๆ แล้วไปทำต่อ (ไม่ return)
    print("⚠️ ไม่พบอีเมลฉุกเฉิน (ข้ามขั้นตอนส่งเมล)");
  }

  // --- ส่วนที่ 3: โทรออก (ทำเสมอ ถ้ามีเบอร์) ---
  if (user.emergencyPhone.isNotEmpty) {
    print("กำลังโทรออกไปที่: ${user.emergencyPhone} ...");
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final intent = AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:${user.emergencyPhone}',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        print("✅ สั่งโทรออกสำเร็จ");
      }
    } catch (e) {
      print("Call Error: $e");
    }
  } else {
    print("❌ ไม่พบเบอร์โทรฉุกเฉิน");
  }
}
