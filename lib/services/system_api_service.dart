import 'dart:convert';
import 'package:http/http.dart' as http;

class SystemApiService {
  // ใส่ URL ที่คุณได้จาก GitHub Gist (กดปุ่ม Raw) ตรงนี้
  // อันนี้เป็น URL ตัวอย่างที่ผมเตรียมไว้ให้ (ใช้ได้จริง)
  static const String _apiUrl =
      'https://gist.githubusercontent.com/Toonagugaga/b994e8da18b2427441f74e39d6c79485/raw/63953c08454b8610247e2148a1ba570f9a4445e3/blood_data.json';

  static Future<Map<String, List<String>>> fetchBloodData() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // แปลงข้อมูลให้อยู่ในรูปแบบ List<String>
        List<String> groups = List<String>.from(data['blood_groups']);
        List<String> rhFactors = List<String>.from(data['rh_factors']);

        return {"groups": groups, "rh": rhFactors};
      }
    } catch (e) {
      print("Error fetching blood data: $e");
    }

    // ถ้า Error หรือไม่มีเน็ต ให้ใช้ค่า Default นี้แทน (กันแอปพัง)
    return {
      "groups": ["A", "B", "AB", "O", "-"],
      "rh": ["+", "-", "Unknown"],
    };
  }
}
