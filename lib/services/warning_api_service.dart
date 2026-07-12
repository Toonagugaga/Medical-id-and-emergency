import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class WarningApiService {
  // URL ของ API (ใช้ตัวนี้ได้เลย หรือเปลี่ยนเป็น Gist ของคุณ)
  static const String _apiUrl =
      'https://gist.githubusercontent.com/Toonagugaga/ff4d0455a3e3396d20540c906f20fe95/raw/b2162f4be47646f5513243f06e58165b93166fbf/warning_messages.json';

  // ฟังก์ชันดึงและสุ่มข้อความ
  static Future<String> getRandomWarningMessage(int minutesLeft) async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> messages = data['messages'];

        // สุ่มมา 1 ข้อความ
        String randomMsg = messages[Random().nextInt(messages.length)];

        // แทนที่คำว่า {min} ด้วยตัวเลขจริง
        return randomMsg.replaceAll('{min}', minutesLeft.toString());
      }
    } catch (e) {
      print("Error fetching warning: $e");
    }

    // ข้อความกันเหนียว (Default)
    return "แจ้งเตือน: กรุณากดเช็คชื่อภายใน $minutesLeft นาที";
  }
}
