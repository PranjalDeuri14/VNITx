import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/settings_provider.dart';
import '../core/theme.dart';
import '../widgets/analysis_result_card.dart';
import '../widgets/risk_timeline.dart';
import 'audio_screen.dart'
    show SectionHeader, OptionCard, ActionButton, FileBadge, ErrorBox, CurlExample;

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  Uint8List? _videoBytes;
  String? _videoName;
  String _videoTranscript = '';
  double _targetFps = 5.0;
  int? _maxFrames;
  bool _runInjection = true;
  bool _runCrossModal = true;
  bool _runCaption = true;
  bool _runVisionDeepfake = true;
  bool _runAvsync = true;
  bool _logFrames = true;
  ApiResult? _result;
  bool _loading = false;
  String? _error;
  final _transcriptCtrl = TextEditingController();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _videoBytes = result.files.first.bytes;
        _videoName = result.files.first.name;
        _result = null; _error = null;
      });
    }
  }

  Future<void> _analyze() async {
    final settings = context.read<SettingsProvider>();
    if (_videoBytes == null) return;
    setState(() { _loading = true; _error = null; _result = null; });
    final res = await ApiService.analyzeVideo(
      baseUrl: settings.videoBase,
      videoBytes: _videoBytes!,
      filename: _videoName ?? 'video.mp4',
      audioTranscript: _videoTranscript,
      targetFps: _targetFps,
      maxFrames: _maxFrames,
      runInjection: _runInjection,
      runCrossModal: _runCrossModal,
      runCaption: _runCaption,
      runVisionDeepfake: _runVisionDeepfake,
      runAvsync: _runAvsync,
      logFrames: _logFrames,
    );
    setState(() { _loading = false; _result = res; if (!res.ok) _error = res.error; });
  }

  @override
  void dispose() {
    _transcriptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionHeader(icon: Icons.movie_filter, title: 'Video Deepfake Detection', color: const Color(0xFFFF4081)),
        const SizedBox(height: 16),

        // File picker
        OptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Video File', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ActionButton(icon: Icons.video_file, label: 'Choose Video (mp4 / mov / avi / mkv)', onTap: _pickFile),
              ),
              if (_videoName != null) ...[
                const SizedBox(height: 10),
                FileBadge(name: _videoName!, bytes: _videoBytes?.length ?? 0),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Options
        OptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Analysis Options', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _transcriptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Audio transcript (optional)',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                maxLines: 2,
                onChanged: (v) => setState(() => _videoTranscript = v),
              ),
              const SizedBox(height: 14),
              // FPS slider
              Row(
                children: [
                  Text('Target FPS: ${_targetFps.toStringAsFixed(1)}',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      min: 1, max: 15, divisions: 14,
                      value: _targetFps,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _targetFps = v),
                    ),
                  ),
                ],
              ),
              // Max frames
              Row(
                children: [
                  Text('Max Frames: ', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  Switch(
                    value: _maxFrames != null,
                    onChanged: (v) => setState(() => _maxFrames = v ? 100 : null),
                  ),
                  if (_maxFrames != null) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: _maxFrames.toString(),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.all(8)),
                        onChanged: (v) => setState(() => _maxFrames = int.tryParse(v)),
                      ),
                    ),
                  ] else
                    Text('No limit', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
              const Divider(height: 20),
              Text('Detectors', style: Theme.of(context).textTheme.bodyMedium),
              _DetectorToggle(label: 'Prompt Injection', value: _runInjection, onChanged: (v) => setState(() => _runInjection = v)),
              _DetectorToggle(label: 'Cross-Modal Check', value: _runCrossModal, onChanged: (v) => setState(() => _runCrossModal = v)),
              _DetectorToggle(label: 'Caption Alignment', value: _runCaption, onChanged: (v) => setState(() => _runCaption = v)),
              _DetectorToggle(label: 'Vision Deepfake', value: _runVisionDeepfake, onChanged: (v) => setState(() => _runVisionDeepfake = v)),
              _DetectorToggle(label: 'AV Sync Check', value: _runAvsync, onChanged: (v) => setState(() => _runAvsync = v)),
              _DetectorToggle(label: 'Log per-frame JSONL', value: _logFrames, onChanged: (v) => setState(() => _logFrames = v)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_videoBytes != null)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.analytics),
              label: Text(_loading ? 'Analyzing...' : 'Analyze Video'),
            ),
          ),

        if (_error != null) ...[const SizedBox(height: 14), ErrorBox(message: _error!)],

        if (_result != null && _result!.ok) ..._buildResults(context),

        const SizedBox(height: 20),
        CurlExample(child: Text(
          'curl -X POST "\$VIDEO_BASE/analyze_video"\\\n'
          '  -F "video=@sample.mp4"\\\n'
          '  -F "target_fps=5"\\\n'
          '  -F "run_vision_deepfake=true"',
          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary),
        )),
        const SizedBox(height: 30),
      ],
    );
  }

  List<Widget> _buildResults(BuildContext context) {
    final data = _result!.data;
    return [
      const SizedBox(height: 20),
      Text('Results', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      if (data['summary'] is Map)
        AnalysisResultCard(
          data: Map<String, dynamic>.from(data['summary'] as Map),
          title: 'Summary',
        ),
      const SizedBox(height: 10),
      // Timeline chart
      if (data['timeline_flat'] is List && (data['timeline_flat'] as List).isNotEmpty) ...[
        Text('Risk Timeline', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: RiskTimeline(timelineFlat: data['timeline_flat'] as List),
        ),
        const SizedBox(height: 10),
      ],
      // Top risky frames table
      if (data['top_risky_frames_flat'] is List && (data['top_risky_frames_flat'] as List).isNotEmpty) ...[
        Text('Top Risky Frames', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...(data['top_risky_frames_flat'] as List).take(5).map((f) {
          final frame = f as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnalysisResultCard(data: frame, title: 'Frame ${frame['frame_index'] ?? '?'}'),
          );
        }),
      ],
    ];
  }
}

class _DetectorToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DetectorToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
