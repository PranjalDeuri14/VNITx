import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Central API service that wraps all three VNITx backend APIs:
/// - Audio: POST /api/voice-detection (JSON with base64)
/// - Image: POST /analyze (multipart form)
/// - Video: POST /analyze_video (multipart form)
class ApiService {
  // ──────────────────────────────────────────────────────────────
  // AUDIO
  // ──────────────────────────────────────────────────────────────

  /// Analyze audio bytes (must be MP3 for production, or specify format).
  static Future<ApiResult> analyzeAudio({
    required String baseUrl,
    required String apiKey,
    required Uint8List audioBytes,
    required String language,
    String audioFormat = 'mp3',
  }) async {
    final url = Uri.parse('${_base(baseUrl)}/api/voice-detection');
    final audioB64 = base64Encode(audioBytes);
    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
            },
            body: jsonEncode({
              'language': language,
              'audioFormat': audioFormat,
              'audioBase64': audioB64,
            }),
          )
          .timeout(const Duration(seconds: 90));
      return ApiResult.fromResponse(resp);
    } catch (e) {
      return ApiResult.error(e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────
  // IMAGE
  // ──────────────────────────────────────────────────────────────

  /// Analyze an image for prompt injection, cross-modal, deepfake.
  static Future<ApiResult> analyzeImage({
    required String baseUrl,
    required Uint8List imageBytes,
    required String filename,
    String contentType = 'image/jpeg',
    String audioTranscript = '',
    bool runCaption = true,
    bool deep = true,
  }) async {
    final url = Uri.parse('${_base(baseUrl)}/analyze');
    try {
      final req = http.MultipartRequest('POST', url)
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ))
        ..fields['audio_transcript'] = audioTranscript
        ..fields['run_caption'] = runCaption ? 'true' : 'false'
        ..fields['deep'] = deep ? 'true' : 'false';
      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final resp = await http.Response.fromStream(streamed);
      return ApiResult.fromResponse(resp);
    } catch (e) {
      return ApiResult.error(e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────
  // VIDEO
  // ──────────────────────────────────────────────────────────────

  /// Analyze a video for deepfake, prompt injection, AV-sync, etc.
  static Future<ApiResult> analyzeVideo({
    required String baseUrl,
    required Uint8List videoBytes,
    required String filename,
    String contentType = 'video/mp4',
    String audioTranscript = '',
    double targetFps = 5.0,
    int? maxFrames,
    bool runInjection = true,
    bool runCrossModal = true,
    bool runCaption = true,
    bool runVisionDeepfake = true,
    bool runAvsync = true,
    bool logFrames = true,
  }) async {
    final url = Uri.parse('${_base(baseUrl)}/analyze_video');
    try {
      final req = http.MultipartRequest('POST', url)
        ..files.add(http.MultipartFile.fromBytes(
          'video',
          videoBytes,
          filename: filename,
        ))
        ..fields['audio_transcript'] = audioTranscript
        ..fields['target_fps'] = targetFps.toString()
        ..fields['max_frames'] = maxFrames != null ? maxFrames.toString() : ''
        ..fields['run_injection'] = runInjection ? 'true' : 'false'
        ..fields['run_cross_modal'] = runCrossModal ? 'true' : 'false'
        ..fields['run_caption'] = runCaption ? 'true' : 'false'
        ..fields['run_vision_deepfake'] = runVisionDeepfake ? 'true' : 'false'
        ..fields['run_avsync'] = runAvsync ? 'true' : 'false'
        ..fields['log_frames'] = logFrames ? 'true' : 'false';
      final streamed = await req.send().timeout(const Duration(minutes: 10));
      final resp = await http.Response.fromStream(streamed);
      return ApiResult.fromResponse(resp);
    } catch (e) {
      return ApiResult.error(e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────
  // HEALTH CHECK
  // ──────────────────────────────────────────────────────────────

  static Future<HealthResult> healthCheck(String baseUrl, String path) async {
    final url = Uri.parse('${_base(baseUrl)}$path');
    final sw = Stopwatch()..start();
    try {
      final resp = await http
          .get(url)
          .timeout(const Duration(seconds: 15));
      sw.stop();
      return HealthResult(
        ok: resp.statusCode < 400,
        statusCode: resp.statusCode,
        message: resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body,
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return HealthResult(ok: false, statusCode: 0, message: e.toString(), latencyMs: sw.elapsedMilliseconds);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────

  static String _base(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

class ApiResult {
  final bool ok;
  final int statusCode;
  final Map<String, dynamic> data;
  final String? error;

  const ApiResult({
    required this.ok,
    required this.statusCode,
    required this.data,
    this.error,
  });

  factory ApiResult.fromResponse(http.Response resp) {
    final ok = resp.statusCode >= 200 && resp.statusCode < 300;
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else {
        data = {'value': decoded};
      }
    } catch (_) {
      data = {'raw_text': resp.body};
    }
    return ApiResult(
      ok: ok,
      statusCode: resp.statusCode,
      data: data,
      error: ok ? null : 'HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 300))}',
    );
  }

  factory ApiResult.error(String message) => ApiResult(
        ok: false,
        statusCode: 0,
        data: {},
        error: message,
      );
}

class HealthResult {
  final bool ok;
  final int statusCode;
  final String message;
  final int latencyMs;

  const HealthResult({
    required this.ok,
    required this.statusCode,
    required this.message,
    required this.latencyMs,
  });
}
