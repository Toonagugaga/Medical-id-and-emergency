import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/foreground_medical_service.dart';
import '../services/emergency_manager.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import 'edit_profile_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isEmergencyMode = false;
  bool isTrackingMode = false;
  bool isDarkMode = false;
  int _currentInterval = 120;
  String _userName = "ผู้ใช้";
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Countdown Timer variables
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isCountdownActive = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _requestAllPermissions();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playWaterSound() async {
    await _audioPlayer.play(AssetSource('sounds/water.mp3'));
  }

  Future<void> _playOpenSound() async {
    await _audioPlayer.play(AssetSource('sounds/open.mp3'));
  }

  Future<void> _playCheckSound() async {
    await _audioPlayer.play(AssetSource('sounds/check.mp3'));
  }

  Future<void> _requestAllPermissions() async {
    await [Permission.notification, Permission.location, Permission.phone, Permission.sms, Permission.ignoreBatteryOptimizations].request();

    if (await Permission.scheduleExactAlarm.isDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("กรุณาเปิดสิทธิ์ 'Alarms & reminders' เพื่อให้แอปทำงานได้"), duration: Duration(seconds: 5)));
      await Permission.scheduleExactAlarm.request();
    }

    if (await Permission.location.isGranted) {
      if (await Permission.locationAlways.isDenied) {
        await Permission.locationAlways.request();
      }
    }
  }

  Future<void> _loadCurrentSettings() async {
    final db = DatabaseHelper();
    final user = await db.getUser();
    if (user != null) {
      setState(() {
        _currentInterval = user.checkInInterval;
        _userName = user.name.isNotEmpty ? user.name : "ผู้ใช้";
        isTrackingMode = user.isTrackingMode;
        isEmergencyMode = user.isEmergencyMode;
        isDarkMode = user.isDarkMode;
      });

      // ถ้าโหมดเปิดอยู่ ให้เริ่ม service ใหม่
      if (user.isEmergencyMode) {
        await ForegroundMedicalService.startService(
          name: user.name.isNotEmpty ? user.name : "ไม่ระบุชื่อ",
          bloodType: user.bloodType.isNotEmpty ? user.bloodType : "-",
          allergy: user.allergies.isNotEmpty ? user.allergies : "-",
          emergencyContact: user.emergencyPhone.isNotEmpty ? user.emergencyPhone : "-",
        );
      }

      // ถ้า Tracking Mode เปิดอยู่ และมี lastCheckIn ให้คำนวณเวลาที่เหลือและเริ่ม countdown ต่อ
      if (user.isTrackingMode && user.lastCheckIn != null) {
        try {
          final lastCheckInTime = DateTime.parse(user.lastCheckIn!);
          final intervalSeconds = user.checkInInterval * 60;
          final elapsedSeconds = DateTime.now().difference(lastCheckInTime).inSeconds;
          final remaining = intervalSeconds - elapsedSeconds;

          if (remaining > 0) {
            // ยังมีเวลาเหลือ เริ่ม countdown ต่อ
            _resumeCountdown(remaining);
          }
        } catch (e) {
          // ถ้า parse ไม่ได้ ไม่ต้องทำอะไร
        }
      }
    }
  }

  Future<void> _updateInterval(int minutes) async {
    final db = DatabaseHelper();
    UserProfile? user = await db.getUser();

    if (user != null) {
      UserProfile updatedUser = UserProfile(
        id: user.id,
        name: user.name,
        bloodType: user.bloodType,
        allergies: user.allergies,
        medicalConditions: user.medicalConditions,
        emergencyPhone: user.emergencyPhone,
        emergencyEmail: user.emergencyEmail,
        lastCheckIn: user.lastCheckIn,
        address: user.address,
        medicalHistory: user.medicalHistory,
        checkInInterval: minutes,
        isTrackingMode: user.isTrackingMode,
        isEmergencyMode: user.isEmergencyMode,
        isDarkMode: user.isDarkMode,
      );

      await db.saveUser(updatedUser);

      if (!mounted) return;

      setState(() {
        _currentInterval = minutes;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ตั้งเวลา Check-in เป็น ${_formatTime(minutes)} เรียบร้อย")));
    }
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return "$minutes นาที";
    if (minutes == 60) return "1 ชม.";
    if (minutes < 1440) return "${minutes ~/ 60} ชม.";
    return "${minutes ~/ 1440} วัน";
  }

  // Start countdown timer
  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = _currentInterval * 60; // Convert minutes to seconds
      _isCountdownActive = true;
    });

    // บันทึกเวลา Check-In ลงฐานข้อมูล
    DatabaseHelper().updateLastCheckIn(DateTime.now());

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isCountdownActive = false;
        });
      }
    });
  }

  // Resume countdown with remaining seconds
  void _resumeCountdown(int remainingSeconds) {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = remainingSeconds;
      _isCountdownActive = true;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isCountdownActive = false;
        });
      }
    });
  }

  // Stop countdown timer
  void _stopCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _isCountdownActive = false;
    });
  }

  // Format countdown time for display (MM:SS or HH:MM:SS)
  String _formatCountdown(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showIntervalPicker() {
    _playWaterSound();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("ตั้งเวลาแจ้งเตือน", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildIntervalOption(2, "2 นาที (ทดสอบ)"),
              _buildIntervalOption(360, "6 ชั่วโมง"),
              _buildIntervalOption(720, "12 ชั่วโมง"),
              _buildIntervalOption(1440, "1 วัน"),
              _buildIntervalOption(4320, "3 วัน"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntervalOption(int minutes, String label) {
    return ListTile(
      leading: Icon(Icons.timer, color: _currentInterval == minutes ? Colors.blue : Colors.grey),
      title: Text(label),
      trailing: _currentInterval == minutes ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        _playWaterSound();
        _updateInterval(minutes);
        Navigator.pop(context);
      },
    );
  }

  void _showHelpDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              _playWaterSound();
              Navigator.pop(context);
            },
            child: const Text("เข้าใจแล้ว"),
          ),
        ],
      ),
    );
  }

  void toggleEmergencyMode(bool value) async {
    _playOpenSound();
    setState(() {
      isEmergencyMode = value;
    });

    // บันทึกสถานะลงฐานข้อมูล
    final db = DatabaseHelper();
    await db.updateModeStates(isEmergencyMode: value);

    if (value) {
      final user = await db.getUser();

      // ใช้ Foreground Service แทน (ลบไม่ได้!)
      await ForegroundMedicalService.startService(
        name: user?.name ?? "ไม่ระบุชื่อ",
        bloodType: user?.bloodType ?? "-",
        allergy: user?.allergies ?? "-",
        emergencyContact: user?.emergencyPhone ?? "-",
      );
    } else {
      // หยุด Foreground Service
      await ForegroundMedicalService.stopService();
    }
  }

  void toggleTrackingMode(bool value) async {
    _playOpenSound();
    setState(() {
      isTrackingMode = value;
    });

    // บันทึกสถานะลงฐานข้อมูล
    final db = DatabaseHelper();
    await db.updateModeStates(isTrackingMode: value);

    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เปิด Tracking Mode แล้ว: กดปุ่ม Check-in เพื่อเริ่มระบบ")));
    } else {
      _stopCountdown(); // Stop countdown when tracking mode is off
      await db.clearLastCheckIn(); // เคลียร์ lastCheckIn เพื่อไม่ให้ countdown เริ่มเองเมื่อเปิดใหม่
      EmergencyManager.stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ปิด Tracking Mode: หยุดระบบติดตามแล้ว")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // === Header ===
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Medical ID",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : const Color(0xFF2196F3)),
                  ),
                  GestureDetector(
                    onTap: () {
                      _playWaterSound();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileScreen(isFirstRun: false)),
                      ).then((_) => _loadCurrentSettings());
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: isDarkMode ? Colors.grey.shade800 : const Color(0xFFE3F2FD),
                      child: Icon(Icons.person, color: isDarkMode ? Colors.white : const Color(0xFF2196F3)),
                    ),
                  ),
                ],
              ),
            ),

            // === Greeting + Dark Mode Toggle ===
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "สวัสดีคุณ $_userName",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white70 : Colors.black87),
                  ),
                  // Dark/Light Mode Toggle
                  Container(
                    width: 50,
                    height: 90,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _playWaterSound();
                            setState(() => isDarkMode = false);
                            DatabaseHelper().updateModeStates(isDarkMode: false);
                          },
                          child: Icon(Icons.wb_sunny, color: !isDarkMode ? Colors.orange : Colors.grey, size: 22),
                        ),
                        GestureDetector(
                          onTap: () {
                            _playWaterSound();
                            setState(() => isDarkMode = true);
                            DatabaseHelper().updateModeStates(isDarkMode: true);
                          },
                          child: Icon(Icons.nightlight_round, color: isDarkMode ? Colors.blue.shade200 : Colors.grey, size: 22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // === Main Content ===
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // === Tracking Mode Card ===
                    _buildTrackingModeCard(),

                    const SizedBox(height: 20),

                    // === Medical ID Mode Card ===
                    _buildMedicalIdModeCard(),
                  ],
                ),
              ),
            ),

            // === Bottom Navigation ===
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.home, "Home", true),
                  _buildNavItem(
                    Icons.person_outline,
                    "Profile",
                    false,
                    onTap: () {
                      _playWaterSound();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileScreen(isFirstRun: false)),
                      ).then((_) => _loadCurrentSettings());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === Tracking Mode Card ===
  Widget _buildTrackingModeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isTrackingMode ? const Color(0xFF2196F3) : Colors.grey.shade300, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Top Row: Toggle + Help
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ON/OFF Toggle
              GestureDetector(
                onTap: () => toggleTrackingMode(!isTrackingMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTrackingMode ? const Color(0xFF2196F3) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isTrackingMode ? "ON" : "OFF",
                        style: TextStyle(color: isTrackingMode ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Help Button
              GestureDetector(
                onTap: () {
                  _playWaterSound();
                  _showHelpDialog(
                    "Tracking Mode คืออะไร?",
                    "ระบบจะติดตามคุณตามเวลาที่ตั้งไว้\n\n"
                        "• หากคุณไม่กด Check-in ภายในเวลาที่กำหนด\n"
                        "• ระบบจะส่ง SMS พร้อมพิกัด GPS ไปยังเบอร์ฉุกเฉิน\n"
                        "• และโทรแจ้งเตือนอัตโนมัติ\n\n"
                        "เหมาะสำหรับผู้สูงอายุ หรือผู้ที่อยู่คนเดียว",
                  );
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Icon(Icons.question_mark, size: 16, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Countdown Timer Display (in the circled area)
          if (_isCountdownActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: const Color(0xFF2196F3), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatCountdown(_remainingSeconds),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF2196F3),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(25)),
              child: Text("กด Check-In เพื่อเริ่ม", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ),

          const SizedBox(height: 16),

          // Title
          Text(
            "Tracking Mode",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
          ),

          const SizedBox(height: 24),

          // Check-In Button with Lottie Background
          GestureDetector(
            onTap: isTrackingMode
                ? () {
                    _playCheckSound();
                    _startCountdown(); // Start countdown timer
                    EmergencyManager.userCheckIn();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ เช็คชื่อแล้ว! เริ่มนับถอยหลังใหม่")));
                  }
                : null,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTrackingMode ? const Color(0xFF2196F3) : Colors.grey.shade200,
                boxShadow: isTrackingMode ? [BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.3), blurRadius: 25, spreadRadius: 5)] : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Lottie Background Animation
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: ClipOval(
                      child: OverflowBox(
                        maxWidth: 180,
                        maxHeight: 180,
                        child: Transform.translate(
                          offset: isTrackingMode ? const Offset(0, 0) : Offset.zero,
                          child: Lottie.asset(
                            isTrackingMode ? 'assets/animations/after-check.json' : 'assets/animations/before-check.json',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Check-In Text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "Check-In",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Timer Display (below Check-In)
          GestureDetector(
            onTap: _showIntervalPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 18, color: isTrackingMode ? const Color(0xFF2196F3) : Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_currentInterval),
                    style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // === Medical ID Mode Card ===
  Widget _buildMedicalIdModeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isEmergencyMode ? const Color(0xFF2196F3) : Colors.grey.shade300, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Top Row: Toggle + Help
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ON/OFF Toggle
              GestureDetector(
                onTap: () => toggleEmergencyMode(!isEmergencyMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEmergencyMode ? const Color(0xFF2196F3) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEmergencyMode ? "ON" : "OFF",
                        style: TextStyle(color: isEmergencyMode ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Help Button
              GestureDetector(
                onTap: () {
                  _playWaterSound();
                  _showHelpDialog(
                    "Medical ID Mode คืออะไร?",
                    "แสดงข้อมูลทางการแพทย์บน Lock Screen\n\n"
                        "• ชื่อ, กรุ๊ปเลือด, ยาที่แพ้\n"
                        "• เบอร์โทรฉุกเฉิน\n\n"
                        "เหมาะสำหรับกรณีฉุกเฉิน แพทย์หรือผู้ช่วยเหลือสามารถเห็นข้อมูลสำคัญได้ทันที",
                  );
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Icon(Icons.question_mark, size: 16, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Lottie Animation (centered)
          Lottie.asset(
            isEmergencyMode ? 'assets/animations/heart-mode.json' : 'assets/animations/tracking-icon.json',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            "Medical ID Mode",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF2196F3) : Colors.grey, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
