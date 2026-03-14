import 'dart:convert';
import 'package:http/http.dart' as http;

class AIResumeService {
  static const String apiUrl = "https://indeed-scraper-api.p.rapidapi.com/api/job"; // 🔗 Replace this

  static Future<String?> generateSummary({
    required String name,
    required String designation,
    required List<String> experiences,
    required List<String> skills,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'designation': designation,
          'experience': experiences,
          'skills': skills,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['summary'];
      } else {
        print('API Error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling AI service: $e');
      return null;
    }
  }
}
