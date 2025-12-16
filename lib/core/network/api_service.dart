import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../../config.dart';

/// Generic API service for authenticated HTTP requests
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Get the stored auth token
  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Generic GET request
  Future<ApiResponse> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
      );
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      debugPrint('[ApiService] GET $endpoint error: $e');
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Generic POST request
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
      print('[ApiService] POST $url');
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      
      print('[ApiService] POST response status: ${response.statusCode}');
      print('[ApiService] POST response body: ${response.body}');
      
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      print('[ApiService] POST $endpoint error: $e');
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Generic PUT request
  Future<ApiResponse> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      debugPrint('[ApiService] PUT $endpoint error: $e');
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Generic DELETE request
  Future<ApiResponse> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
      );
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      debugPrint('[ApiService] DELETE $endpoint error: $e');
      return ApiResponse(success: false, error: e.toString());
    }
  }
}

/// Wrapper for API responses
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode = 0,
  });

  factory ApiResponse.fromHttpResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = response.body;
    }

    return ApiResponse(
      success: isSuccess,
      data: isSuccess ? body : null,
      error: isSuccess ? null : (body is Map ? body['message'] : response.body),
      statusCode: response.statusCode,
    );
  }
}
