import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/settings_provider.dart';
import '../core/theme.dart';
import '../widgets/analysis_result_card.dart';
import '../widgets/risk_timeline.dart';
import 'audio_screen.dart'
    show SectionHeader, OptionCard, ActionButton, ErrorBox;

class ScreenRecordScreen extends StatefulWidget {
  const ScreenRecordScreen({super.key});

  @override
  State<ScreenRecordScreen> createState() => _ScreenRecordScreenState();
}

class _ScreenRecordScreenState extends State<ScreenRecordScreen> with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel(AppConstants.screenRecordChannel);

  bool _recording = false;
  String? _recordedFilePath;
  Duration _elapsed = Duration.zero;
  DateTime? _startTime;
  ApiResult? _videoResult;
  ApiResult? _audioResult;
  bool _loadingVideo = false;
  bool _loadingAudio = false;
  String? _error;

  // Animation for the recording indicator
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() { _error = null; _recordedFilePath = null; _videoResult = null; _audioResult = null; });
    try {
      final result = await _channel.invokeMethod<String>('startRecording');
      setState(() {
        _recording = true;
        _startTime = DateTime.now();
        _elapsed = Duration.zero;
      });
      _pollElapsed();
    } on PlatformException catch (e) {
      setState(() => _error = 'Failed to start recording: ${e.message}');
    }
  }

  void _pollElapsed() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_recording || !mounted) return false;
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
      return true;
    });
  }

  Future<void> _stopAndAnalyze() async {
    try {
      final path = await _channel.invokeMethod<String>('stopRecording');
      setState(() { _recording = false; _recordedFilePath = path; });
      if (path != null) {
        await _analyzeRecording(path);
      }
    } on PlatformException catch (e) {
      setState(() { _recording = false; _error = 'Failed to stop recording: ${e.message}'; });
    }
  }

  Future<void> _analyzeRecording(String path) async {
    final settings = context.read<SettingsProvider>();
    final file = File(path);
    if (!await file.exists()) {
      setState(() => _error = 'Recording file not found: $path');
      return;
    }
    final videoBytes = await file.readAsBytes();
    final filename = path.split('/').last;

    // Send video to Video API
    setState(() => _loadingVideo = true);
    final videoResult = await ApiService.analyzeVideo(
      baseUrl: settings.videoBase,
      videoBytes: videoBytes,
      filename: filename,
      audioTranscript: '',
      targetFps: 5.0,
      runInjection: true,
      runCrossModal: true,
      runCaption: true,
      runVisionDeepfake: true,
      runAvsync: true,
    );
    setState(() { _loadingVideo = false; _videoResult = videoResult; });

    // Send to Audio API too
    setState(() => _loadingAudio = true);
    final audioResult = await ApiService.analyzeAudio(
      baseUrl: settings.audioBase,
      apiKey: settings.apiKey,
      audioBytes: videoBytes, // server can handle video container for audio
      language: 'English',
      audioFormat: 'mp3',
    );
    setState(() { _loadingAudio = false; _audioResult = audioResult; });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionHeader(icon: Icons.radio_button_checked, title: 'Screen Recording Analysis', color: AppTheme.accent),
        const SizedBox(height: 8),
        Text(
          'Record your screen during any call, then auto-submit video & audio to the AI detection APIs.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),

        // Recording card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _recording ? AppTheme.error.withOpacity(0.6) : AppTheme.divider,
              width: _recording ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Timer display
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => Opacity(
                  opacity: _recording ? _pulseAnim.value : 1.0,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_recording ? AppTheme.error : AppTheme.accent).withOpacity(0.12),
                      border: Border.all(
                        color: _recording ? AppTheme.error : AppTheme.accent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _recording ? Icons.stop_circle : Icons.fiber_manual_record,
                          color: _recording ? AppTheme.error : AppTheme.accent,
                          size: 32,
                        ),
                        if (_recording) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatDuration(_elapsed),
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (!_recording)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Start Screen Recording'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _stopAndAnalyze,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop & Analyze'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                  ),
                ),

              const SizedBox(height: 12),
              Text(
                _recording
                    ? '🔴 Recording screen... Open any call app now.'
                    : '📱 Tap to start capturing your screen',
                style: TextStyle(
                  color: _recording ? AppTheme.error : AppTheme.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        if (_recordedFilePath != null) ...[
          const SizedBox(height: 16),
          OptionCard(
            child: Row(
              children: [
                Icon(Icons.video_file, color: AppTheme.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _recordedFilePath!.split('/').last,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_error != null) ...[const SizedBox(height: 14), ErrorBox(message: _error!)],

        // Video result
        if (_loadingVideo) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Center(child: Text('Analyzing video...', style: TextStyle(color: AppTheme.textSecondary))),
        ],

        if (_videoResult != null) ...[
          const SizedBox(height: 20),
          Text('Video Analysis Results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_videoResult!.ok && _videoResult!.data['summary'] is Map)
            AnalysisResultCard(
              data: Map<String, dynamic>.from(_videoResult!.data['summary'] as Map),
              title: 'Video Summary',
            ),
          if (_videoResult!.ok && _videoResult!.data['timeline_flat'] is List &&
              (_videoResult!.data['timeline_flat'] as List).isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: RiskTimeline(timelineFlat: _videoResult!.data['timeline_flat'] as List),
            ),
          ],
          if (!_videoResult!.ok) ErrorBox(message: _videoResult!.error ?? 'Video API error'),
        ],

        // Audio result
        if (_loadingAudio) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          Center(child: Text('Analyzing audio...', style: TextStyle(color: AppTheme.textSecondary))),
        ],

        if (_audioResult != null) ...[
          const SizedBox(height: 20),
          Text('Audio Analysis Results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_audioResult!.ok)
            AnalysisResultCard(data: _audioResult!.data, title: 'Voice Detection')
          else
            ErrorBox(message: _audioResult!.error ?? 'Audio API error'),
        ],

        const SizedBox(height: 30),

        // Info box about Android permission
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Screen recording uses Android MediaProjection. '
                  'You will see a system permission dialog when you start recording. '
                  'The recording captures both screen video and microphone audio.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
