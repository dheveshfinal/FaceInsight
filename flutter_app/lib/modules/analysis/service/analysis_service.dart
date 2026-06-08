// ==============================================================
//  FaceInsight – lib/modules/analysis/service/analysis_service.dart
//  Handles image upload (web-compatible), job polling, results
// ==============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_constants.dart';
import '../../../core/providers/auth_store.dart';

class AnalysisService {
  AnalysisService._();
  static final AnalysisService instance = AnalysisService._();

  final _picker = ImagePicker();

  // ── Pick image from camera or gallery ─────────────────────
  /// Returns null if user cancelled.
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    if (kIsWeb || !fromCamera) {
      // Web: always use gallery (opens native browser file picker;
      //      on mobile Chrome the user can still choose camera)
      return _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
    } else {
      return _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
        preferredCameraDevice: CameraDevice.front,
      );
    }
  }

  // ── Upload XFile and create analysis job ──────────────────
  /// Works on Web (uses bytes) and mobile (uses path).
  Future<AnalysisJob> uploadXFile(XFile xfile) async {
    final token = AuthStore.instance.accessToken;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConstants.uploadImageUrl),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Web doesn't support dart:io File — use bytes instead
    final bytes    = await xfile.readAsBytes();
    final filename = xfile.name.isNotEmpty ? xfile.name : 'photo.jpg';
    final mimeType = xfile.mimeType ?? _guessMime(filename);

    request.files.add(http.MultipartFile.fromBytes(
      'file',               // must match FastAPI parameter name
      bytes,
      filename: filename,
      contentType: _parseMediaType(mimeType),
    ));

    final streamed = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timed out'),
    );
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      String detail = 'Upload failed (${streamed.statusCode})';
      try {
        detail = (jsonDecode(body) as Map)['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    return AnalysisJob.fromJson(data);
  }

  // ── Poll job status until completion ──────────────────────
  Future<AnalysisJobStatus> pollJobStatus({
    required String jobId,
    required void Function(double progress, String stage)? onProgress,
  }) async {
    int attempts = 0;
    const maxAttempts = AppConstants.maxPollingAttempts;

    while (attempts < maxAttempts) {
      final status = await getJobStatus(jobId: jobId);

      if (onProgress != null && status.progress != null) {
        onProgress(status.progress!, status.stage ?? 'Processing…');
      }

      if (status.isComplete) return status;

      await Future.delayed(AppConstants.pollingInterval);
      attempts++;
    }
    throw Exception('Analysis timed out');
  }

  // ── Get current job status ─────────────────────────────────
  Future<AnalysisJobStatus> getJobStatus({required String jobId}) async {
    final token = AuthStore.instance.accessToken;
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final res = await http.get(
      Uri.parse('${AppConstants.jobStatusUrl}/$jobId'),
      headers: headers,
    ).timeout(AppConstants.httpTimeout);

    if (res.statusCode == 404) throw Exception('Job not found: $jobId');
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['detail'] ?? 'Failed to fetch job status');
    }

    return AnalysisJobStatus.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Get analysis results ───────────────────────────────────
  Future<Map<String, dynamic>> getResults({required String jobId}) async {
    final token = AuthStore.instance.accessToken;
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final res = await http.get(
      Uri.parse('${AppConstants.analysisResultUrl}/$jobId'),
      headers: headers,
    ).timeout(AppConstants.httpTimeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch results: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Get analysis history ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getHistory() async {
    final token = AuthStore.instance.accessToken;
    if (token == null || token.isEmpty) {
      return [];
    }
    final res = await http.get(
      Uri.parse(AppConstants.analysisHistoryUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(AppConstants.httpTimeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch history: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['history'] as List<dynamic>? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }


  // ── Helpers ───────────────────────────────────────────────
  String _guessMime(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      default:     return 'image/jpeg';
    }
  }

  http.MediaType _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    return http.MediaType(
      parts.first,
      parts.length > 1 ? parts[1] : 'jpeg',
    );
  }
}

// ── DTO: Upload response ───────────────────────────────────────

class AnalysisJob {
  final String jobId;
  final String status;
  final String createdAt;

  AnalysisJob({
    required this.jobId,
    required this.status,
    required this.createdAt,
  });

  factory AnalysisJob.fromJson(Map<String, dynamic> json) => AnalysisJob(
        jobId:     json['job_id']     as String,
        status:    json['status']     as String? ?? 'pending',
        createdAt: json['created_at'] as String? ?? '',
      );
}

// ── DTO: Job status response ───────────────────────────────────

class AnalysisJobStatus {
  final String  jobId;
  final String  status;
  final double? progress;
  final String? stage;
  final String? errorMessage;

  AnalysisJobStatus({
    required this.jobId,
    required this.status,
    this.progress,
    this.stage,
    this.errorMessage,
  });

  bool get isComplete => status == 'completed' || status == 'failed';
  bool get isSuccess  => status == 'completed';

  factory AnalysisJobStatus.fromJson(Map<String, dynamic> json) =>
      AnalysisJobStatus(
        jobId:        json['job_id'] as String,
        status:       json['status'] as String? ?? 'pending',
        progress:     _toDouble(json['progress']),
        stage:        json['stage']         as String?,
        errorMessage: json['error_message'] as String?,
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
