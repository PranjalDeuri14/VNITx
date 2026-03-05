import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/settings_provider.dart';
import '../core/theme.dart';
import '../widgets/analysis_result_card.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  String _language = 'English';
  bool _compress = true;
  Uint8List? _audioBytes;
  String? _audioFileName;
  ApiResult? _result;
  bool _loading = false;
  bool _recording = false;
  String? _error;

  final AudioRecorder _recorder = AudioRecorder();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _audioBytes = result.files.first.bytes;
        _audioFileName = result.files.first.name;
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          setState(() {
            _audioBytes = file.readAsBytesSync();
            _audioFileName = 'recording.mp3';
            _result = null;
            _error = null;
          });
        }
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() => _error = 'Microphone permission denied.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _recording = true);
    }
  }

  Future<void> _analyze() async {
    final settings = context.read<SettingsProvider>();
    if (_audioBytes == null) return;
    setState(() { _loading = true; _error = null; _result = null; });
    final res = await ApiService.analyzeAudio(
      baseUrl: settings.audioBase,
      apiKey: settings.apiKey,
      audioBytes: _audioBytes!,
      language: _language,
      audioFormat: (_audioFileName ?? '').endsWith('.mp3') ? 'mp3' : 'wav',
    );
    setState(() { _loading = false; _result = res; if (!res.ok) _error = res.error; });
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionHeader(icon: Icons.graphic_eq, title: 'AI Voice Detection', color: AppTheme.primary),
        const SizedBox(height: 16),
        // Language selector
        OptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Language', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.language)),
                dropdownColor: AppTheme.cardBackgroundLight,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                items: AppConstants.languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _language = v!),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Compress Audio'),
                subtitle: const Text('Lower bitrate for stability'),
                value: _compress,
                onChanged: (v) => setState(() => _compress = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Source selection
        OptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audio Source', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      icon: Icons.folder_open,
                      label: 'Import File',
                      onTap: _pickFile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      icon: _recording ? Icons.stop_circle : Icons.mic,
                      label: _recording ? 'Stop Rec' : 'Record Mic',
                      color: _recording ? AppTheme.error : null,
                      onTap: _toggleRecording,
                    ),
                  ),
                ],
              ),
              if (_audioFileName != null) ...[
                const SizedBox(height: 12),
                FileBadge(name: _audioFileName!, bytes: _audioBytes?.length ?? 0),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_audioBytes != null)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.analytics),
              label: Text(_loading ? 'Analyzing...' : 'Analyze Audio'),
            ),
          ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          ErrorBox(message: _error!),
        ],

        if (_result != null && _result!.ok) ...[
          const SizedBox(height: 20),
          Text('Results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          AnalysisResultCard(data: _result!.data, title: 'Audio Detection'),
        ],

        const SizedBox(height: 20),
        // cURL example
        CurlExample(child: Text(
          'curl -X POST "\\\$AUDIO_BASE/api/voice-detection"\\\n'
              '  -H "Content-Type: application/json"\\\n'
              '  -H "x-api-key: <YOUR_KEY>"\\\n'
              '  -d \'{"language":"English","audioFormat":"mp3","audioBase64":"<BASE64>"}\'',
          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary),
        )),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared small widgets used by multiple screens
// ──────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class OptionCard extends StatelessWidget {
  final Widget child;
  const OptionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: child,
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const ActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: c),
      label: Text(label, style: TextStyle(color: c, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class FileBadge extends StatelessWidget {
  final String name;
  final int bytes;
  const FileBadge({required this.name, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, color: AppTheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          Text('${(bytes / 1024).toStringAsFixed(1)} KB', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: AppTheme.error, fontSize: 13))),
        ],
      ),
    );
  }
}

class CurlExample extends StatelessWidget {
  final Widget child;
  const CurlExample({required this.child});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('cURL Example', style: TextStyle(fontSize: 13)),
      collapsedIconColor: AppTheme.textSecondary,
      iconColor: AppTheme.accent,
      tilePadding: EdgeInsets.zero,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBackgroundLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ],
    );
  }
}