import 'dart:convert';
import 'package:http/http.dart' as http;

class DrugApiService {
  static Future<List<String>> searchDrugs(String query) async {
    if (query.length < 3) return [];

    try {
      // ใช้สูตรค้นหาแบบ "OR" (หรือ) คือหาทั้ง Brand Name หรือ Generic Name
      // รูปแบบ Query: (openfda.brand_name:"query*" OR openfda.generic_name:"query*")

      final encodedQuery = Uri.encodeComponent('openfda.brand_name:"$query*" OR openfda.generic_name:"$query*"');
      final url = Uri.parse('https://api.fda.gov/drug/label.json?search=$encodedQuery&limit=10');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null) {
          final results = data['results'] as List;

          // ใช้ Set เพื่อป้องกันชื่อซ้ำ
          Set<String> drugSet = {};

          for (var item in results) {
            if (item['openfda'] != null) {
              // 1. เก็บชื่อสามัญ (Generic Name) - เช่น Carbamazepine
              if (item['openfda']['generic_name'] != null) {
                String generic = item['openfda']['generic_name'][0].toString();
                // แปลงให้เป็นตัวพิมพ์ใหญ่แค่ตัวแรก (Title Case) เพื่อความสวยงาม
                drugSet.add(_capitalize(generic));
              }

              // 2. เก็บชื่อยี่ห้อ (Brand Name) - เช่น Tegretol
              if (item['openfda']['brand_name'] != null) {
                String brand = item['openfda']['brand_name'][0].toString();
                drugSet.add(_capitalize(brand));
              }
            }
          }

          // กรองเอาเฉพาะคำที่มีส่วนคล้ายกับที่ User พิมพ์จริงๆ
          // (เพราะ API อาจส่งผลลัพธ์ที่เกี่ยวข้องกันมาแต่ชื่อไม่เหมือน)
          final filteredList = drugSet.where((name) {
            return name.toLowerCase().contains(query.toLowerCase());
          }).toList();

          // ถ้ากรองแล้วไม่เหลืออะไรเลย ให้ส่งกลับทั้งหมดที่หาเจอแทน (กันเหนียว)
          return filteredList.isNotEmpty ? filteredList : drugSet.toList();
        }
      }
      return [];
    } catch (e) {
      print("Error fetching drugs: $e");
      return [];
    }
  }

  // ฟังก์ชันช่วยทำตัวอักษรตัวแรกให้เป็นตัวใหญ่ (สวยงาม)
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
