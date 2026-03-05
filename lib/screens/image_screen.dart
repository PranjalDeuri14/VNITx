import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/settings_provider.dart';
import '../core/theme.dart';
import '../widgets/analysis_result_card.dart';
import 'audio_screen.dart'
    show SectionHeader, OptionCard, ActionButton, FileBadge, ErrorBox, CurlExample;

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  Uint8List? _imageBytes;
  String? _imageName;
  String _audioTranscript = '';
  bool _runCaption = true;
  bool _deep = true;
  ApiResult? _result;
  bool _loading = false;
  String? _error;
  final _transcriptCtrl = TextEditingController();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        _imageName = result.files.first.name;
        _result = null; _error = null;
      });
    }
  }

  Future<void> _captureCamera() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _result = null; _error = null;
      });
    }
  }

  Future<void> _analyze() async {
    final settings = context.read<SettingsProvider>();
    if (_imageBytes == null) return;
    setState(() { _loading = true; _error = null; _result = null; });
    final res = await ApiService.analyzeImage(
      baseUrl: settings.imageBase,
      imageBytes: _imageBytes!,
      filename: _imageName ?? 'image.jpg',
      audioTranscript: _audioTranscript,
      runCaption: _runCaption,
      deep: _deep,
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
        SectionHeader(icon: Icons.image_search, title: 'Image Prompt Injection', color: const Color(0xFF00BCD4)),
        const SizedBox(height: 16),

        OptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Image Source', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ActionButton(icon: Icons.folder_open, label: 'Choose File', onTap: _pickFile)),
                  const SizedBox(width: 12),
                  Expanded(child: ActionButton(icon: Icons.camera_alt, label: 'Camera', onTap: _captureCamera)),
                ],
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_imageBytes!, height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                FileBadge(name: _imageName!, bytes: _imageBytes!.length),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        OptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Options', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _transcriptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Audio transcript (optional)',
                  hintText: 'Paste transcript text here...',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                maxLines: 3,
                onChanged: (v) => setState(() => _audioTranscript = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Run BLIP caption alignment'),
                value: _runCaption,
                onChanged: (v) => setState(() => _runCaption = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Use DeBERTa deep model'),
                value: _deep,
                onChanged: (v) => setState(() => _deep = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_imageBytes != null)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.analytics),
              label: Text(_loading ? 'Analyzing...' : 'Analyze Image'),
            ),
          ),

        if (_error != null) ...[const SizedBox(height: 14), ErrorBox(message: _error!)],

        if (_result != null && _result!.ok) ...[
          const SizedBox(height: 20),
          Text('Results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_result!.data['ocr'] != null)
            AnalysisResultCard(data: Map<String, dynamic>.from(_result!.data['ocr'] as Map), title: 'OCR Output'),
          const SizedBox(height: 10),
          if (_result!.data['injection'] != null)
            AnalysisResultCard(data: Map<String, dynamic>.from(_result!.data['injection'] as Map), title: 'Prompt Injection'),
          const SizedBox(height: 10),
          if (_result!.data['cross_modal'] != null)
            AnalysisResultCard(data: Map<String, dynamic>.from(_result!.data['cross_modal'] as Map), title: 'Cross-Modal Consistency'),
          const SizedBox(height: 10),
          if (_result!.data['caption_alignment'] != null)
            AnalysisResultCard(data: Map<String, dynamic>.from(_result!.data['caption_alignment'] as Map), title: 'Caption Alignment (BLIP)'),
          const SizedBox(height: 10),
          AnalysisResultCard(data: _result!.data, title: 'Full Response'),
        ],

        const SizedBox(height: 20),
        CurlExample(child: Text(
          'curl -X POST "\$IMAGE_BASE/analyze"\\\n'
          '  -F "image=@sample.jpg"\\\n'
          '  -F "audio_transcript=..."\\\n'
          '  -F "run_caption=true"\\\n'
          '  -F "deep=true"',
          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary),
        )),
        const SizedBox(height: 30),
      ],
    );
  }
}
