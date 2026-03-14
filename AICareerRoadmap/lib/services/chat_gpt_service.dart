import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatGPTService {
  static const String _apiKey = 'YOUR_OPENAI_API_KEY';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {
              "role": "system",
              "content": "You are a helpful career advisor that provides job suggestions, resume tips, and course advice for students."
            },
            {
              "role": "user",
              "content": message
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String reply = data['choices'][0]['message']['content'];
        return reply.trim();
      } else if (response.statusCode == 401) {
        return '❌ Unauthorized: Check your API key.';
      } else if (response.statusCode == 429) {
        return '🚫 Rate limit exceeded. Please wait and try again.';
      } else {
        return '⚠️ Error: ${response.statusCode} - ${response.reasonPhrase}';
      }
    } catch (e) {
      return '❌ Exception: ${e.toString()}';
    }
  }
}
