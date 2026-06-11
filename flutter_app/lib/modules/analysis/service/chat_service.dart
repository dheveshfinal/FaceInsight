import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../../shared/services/api_client.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class ChatService {
  final ApiClient _apiClient;
  String? _sessionId;

  ChatService({ApiClient? apiClient}) 
    : _apiClient = apiClient ?? ApiClient();

  String get sessionId => _sessionId ?? '';

  void setSessionId(String id) {
    _sessionId = id;
    debugPrint('📱 Chat session set: $id');
  }

  Future<String> askQuestion(String question) async {
    try {
      if (_sessionId == null || _sessionId!.isEmpty) {
        throw Exception('Session ID not initialized');
      }

      final response = await _apiClient.post(
        '/chat/ask',
        data: {'question': question},
        headers: {
          'X-Session-ID': _sessionId!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final answer = data['answer'] as String;
        debugPrint('✅ AI Response: $answer');
        return answer;
      } else {
        throw Exception('Failed to get response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error asking question: $e');
      rethrow;
    }
  }

  Future<void> cleanupSession() async {
    try {
      if (_sessionId == null || _sessionId!.isEmpty) return;

      await _apiClient.delete(
        '/chat/session',
        headers: {
          'X-Session-ID': _sessionId!,
        },
      );

      debugPrint('🧹 Session cleaned up: $_sessionId');
      _sessionId = null;
    } catch (e) {
      debugPrint('⚠️ Error cleaning up session: $e');
      // Don't rethrow - cleanup failure shouldn't crash the app
    }
  }

  Future<List<ChatMessage>> getChatHistory() async {
    try {
      final response = await _apiClient.get(
        '/chat/history',
        headers: {
          'X-Session-ID': _sessionId!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final history = (data['history'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
        return history;
      } else {
        throw Exception('Failed to load chat history');
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      return [];
    }
  }
}
