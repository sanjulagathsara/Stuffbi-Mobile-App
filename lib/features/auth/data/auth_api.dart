import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config.dart';

class AuthApi {
  final storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await storage.write(key: "token", value: token);
  }

  Future<void> saveUserData(Map<String, dynamic> user) async {
    await storage.write(key: "user_data", value: jsonEncode(user));
  }

  Future<String?> getToken() async {
    return await storage.read(key: "token");
  }

  Future<Map<String, dynamic>?> getSavedUserData() async {
    final userData = await storage.read(key: "user_data");
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> req) async {
    final url = Uri.parse("${AppConfig.baseUrl}/auth/register");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(req),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode != 200) {
      throw Exception(data["message"] ?? "Registration failed");
    }

    return data; // { "token": "..."}
  }

  Future<Map<String, dynamic>> login(Map<String, dynamic> req) async {
    final url = Uri.parse("${AppConfig.baseUrl}/auth/login");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(req),
    );

    print('[AuthApi] Login response status: ${res.statusCode}');
    print('[AuthApi] Login response body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception("Login failed");
    } else {
      final data = jsonDecode(res.body);
      return data; // { "accessToken": "...", "user": {...} }
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    // First try to get saved user data (from login response)
    final savedUser = await getSavedUserData();
    if (savedUser != null) {
      print('[AuthApi] getMe - returning saved user data');
      return savedUser;
    }

    // Fallback to API call if /auth/me exists
    final token = await getToken();
    print('[AuthApi] getMe - token: ${token != null ? "exists" : "null"}');

    final url = Uri.parse("${AppConfig.baseUrl}/auth/me");
    print('[AuthApi] getMe - URL: $url');
    
    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    print('[AuthApi] getMe - status: ${res.statusCode}');
    print('[AuthApi] getMe - body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception("Unauthorized");
    }

    return jsonDecode(res.body);
  }

  Future<void> logout() async {
    await storage.delete(key: "token");
    await storage.delete(key: "user_data");
  }

  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: "token");
    return token != null;
  }
}

