class UserProfile {
  final int? id;
  final String name;
  final String bloodType;
  final String allergies; // เก็บเป็นข้อความยาวๆ เช่น "Penicillin, Aspirin"
  final String medicalConditions; // โรคประจำตัว
  final String emergencyPhone;
  final String? lastCheckIn; // เก็บเวลาเช็คชื่อล่าสุด
  final int checkInInterval;
  final String address;
  final String medicalHistory;
  final String? emergencyEmail;
  final bool isTrackingMode; // สถานะ Tracking Mode
  final bool isEmergencyMode; // สถานะ Medical ID Mode
  final bool isDarkMode; // สถานะ Dark Mode

  UserProfile({
    this.id,
    required this.name,
    required this.bloodType,
    required this.allergies,
    required this.medicalConditions,
    required this.emergencyPhone,
    this.lastCheckIn,
    required this.checkInInterval,
    required this.address,
    required this.medicalHistory,
    this.emergencyEmail,
    this.isTrackingMode = false,
    this.isEmergencyMode = false,
    this.isDarkMode = false,
  });

  // แปลงข้อมูลจาก Database (Map) มาเป็น Object
  factory UserProfile.fromMap(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    name: json['name'],
    bloodType: json['blood_type'],
    allergies: json['allergies'],
    medicalConditions: json['medical_conditions'],
    emergencyPhone: json['emergency_phone'],
    lastCheckIn: json['last_check_in'],
    checkInInterval: json['check_in_interval'] ?? 120,
    address: json['address'] ?? '',
    medicalHistory: json['medical_history'] ?? '',
    emergencyEmail: json['emergency_email'],
    isTrackingMode: json['is_tracking_mode'] == 1,
    isEmergencyMode: json['is_emergency_mode'] == 1,
    isDarkMode: json['is_dark_mode'] == 1,
  );

  // แปลง Object เป็น Map เพื่อบันทึกลง Database
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'blood_type': bloodType,
    'allergies': allergies,
    'medical_conditions': medicalConditions,
    'emergency_phone': emergencyPhone,
    'last_check_in': lastCheckIn,
    'check_in_interval': checkInInterval,
    'address': address,
    'medical_history': medicalHistory,
    'emergency_email': emergencyEmail,
    'is_tracking_mode': isTrackingMode ? 1 : 0,
    'is_emergency_mode': isEmergencyMode ? 1 : 0,
    'is_dark_mode': isDarkMode ? 1 : 0,
  };
}
