import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/settings_provider.dart';
import '../core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _audioCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _videoCtrl;
  late TextEditingController _keyCtrl;
  bool _obscureKey = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _audioCtrl = TextEditingController(text: s.audioBase);
    _imageCtrl = TextEditingController(text: s.imageBase);
    _videoCtrl = TextEditingController(text: s.videoBase);
    _keyCtrl = TextEditingController(text: s.apiKey);
  }

  @override
  void dispose() {
    _audioCtrl.dispose();
    _imageCtrl.dispose();
    _videoCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<SettingsProvider>().save(
      audioBase: _audioCtrl.text,
      imageBase: _imageCtrl.text,
      videoBase: _videoCtrl.text,
      apiKey: _keyCtrl.text,
    );
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _reset() async {
    await context.read<SettingsProvider>().reset();
    final s = context.read<SettingsProvider>();
    _audioCtrl.text = s.audioBase;
    _imageCtrl.text = s.imageBase;
    _videoCtrl.text = s.videoBase;
    _keyCtrl.text = s.apiKey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset to defaults',
            onPressed: _reset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel('API Endpoints'),
          const SizedBox(height: 12),
          _UrlField(controller: _audioCtrl, label: 'Audio Base URL', icon: Icons.graphic_eq),
          const SizedBox(height: 12),
          _UrlField(controller: _imageCtrl, label: 'Image Base URL', icon: Icons.image_search),
          const SizedBox(height: 12),
          _UrlField(controller: _videoCtrl, label: 'Video Base URL', icon: Icons.movie_filter),
          const SizedBox(height: 24),
          _SectionLabel('Authentication'),
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'Audio API Key  (x-api-key)',
              prefixIcon: const Icon(Icons.vpn_key),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Required for the Audio Voice Detection API. Enter "sk_test_123456789" for testing.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(_saved ? Icons.check : Icons.save),
              label: Text(_saved ? 'Saved!' : 'Save Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved ? AppTheme.success : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppTheme.primary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _UrlField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _UrlField({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        hintText: 'https://',
      ),
    );
  }
}
