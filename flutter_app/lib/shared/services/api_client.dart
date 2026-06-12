import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

class ApiClient {
  /// API base URL from environment (dart-define) or fallback to localhost
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  
  final http.Client _client;
  
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _buildHeaders(headers),
      );
      debugPrint('[API GET] $endpoint - ${response.statusCode}');
      return response;
    } catch (e) {
      debugPrint('[API ERROR GET] $endpoint - $e');
      rethrow;
    }
  }

  Future<http.Response> post(
    String endpoint, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      final body = data is String ? data : json.encode(data);
      final response = await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _buildHeaders(headers),
        body: body,
      );
      debugPrint('[API POST] $endpoint - ${response.statusCode}');
      return response;
    } catch (e) {
      debugPrint('[API ERROR POST] $endpoint - $e');
      rethrow;
    }
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _buildHeaders(headers),
      );
      debugPrint('[API DELETE] $endpoint - ${response.statusCode}');
      return response;
    } catch (e) {
      debugPrint('[API ERROR DELETE] $endpoint - $e');
      rethrow;
    }
  }

  Map<String, String> _buildHeaders(Map<String, String>? extra) {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }
}
