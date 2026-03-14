import 'package:http/http.dart' as http;
import 'dart:convert';

class PerplexityService {
  final String apiUrl = 'https://api.perplexity.ai/chat/completions';
  final String apiKey = 'YOUR_API_KEY_HERE'; // Store securely!

  Future<dynamic> sendPrompt(String prompt) async {
    final body = jsonEncode({
      "model": "sonar-medium-online",
      "messages": [
        {"role": "system", "content": "Be precise and concise."},
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 500,
      "temperature": 0.7
    });

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to call Perplexity API: ${response.statusCode}');
    }
  }
}
