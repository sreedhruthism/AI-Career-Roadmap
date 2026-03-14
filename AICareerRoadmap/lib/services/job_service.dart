import 'dart:convert';
import 'package:http/http.dart' as http;

class JobService {
  static const String _apiUrl = 'https://indeed-scraper-api.p.rapidapi.com/api/job';
  static const String _apiKey = 'eefc362678mshfb0c1a419ddededp1ec85ajsn1b567e11428c'; // Replace with your real key
  static const String _host = 'indeed-scraper-api.p.rapidapi.com';

  static Future<List<Map<String, dynamic>>> fetchJobs(String query, String location) async {
    final Map<String, dynamic> payload = {
      "scraper": {
        "maxRows": 15,
        "query": query,
        "location": location,
        "jobType": "fulltime",
        "radius": "50",
        "sort": "relevance",
        "fromDays": "7",
        "country": "us"
      }
    };

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'x-rapidapi-key': _apiKey,
        'x-rapidapi-host': _host,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['jobs'] ?? []);
    } else {
      throw Exception('Failed to fetch jobs: ${response.body}');
    }
  }
}
