import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveProfileImagePath(String path) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('profile_image_path', path);
}

Future<String?> loadProfileImagePath() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('profile_image_path');
}