import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config.dart';

class AuthApi {
  final storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await storage.write(key: "token", value: token);
  }

  Future<String?> getToken() async {
    return await storage.read(key: "token");
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

    final data = jsonDecode(res.body);

    if (res.statusCode != 200) {
      throw Exception(data["message"] ?? "Login failed");
    }

    return data; // { "token": "..."}
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();

    final url = Uri.parse("${AppConfig.baseUrl}/auth/me");
    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Unauthorized");
    }

    return jsonDecode(res.body);
  }

  Future<void> logout() async {
    await storage.delete(key: "token");
  }
}
