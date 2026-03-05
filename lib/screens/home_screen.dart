import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/settings_provider.dart';
import 'audio_screen.dart';
import 'image_screen.dart';
import 'video_screen.dart';
import 'screen_record_screen.dart';

import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _items = const [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Overview'),
    _NavItem(icon: Icons.graphic_eq_outlined, activeIcon: Icons.graphic_eq, label: 'Audio'),
    _NavItem(icon: Icons.image_outlined, activeIcon: Icons.image, label: 'Image'),
    _NavItem(icon: Icons.videocam_outlined, activeIcon: Icons.videocam, label: 'Video'),
    _NavItem(icon: Icons.radio_button_unchecked, activeIcon: Icons.radio_button_checked, label: 'Screen'),
  ];

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const _OverviewScreen();
      case 1: return const AudioScreen();
      case 2: return const ImageScreen();
      case 3: return const VideoScreen();
      case 4: return const ScreenRecordScreen();
      default: return const _OverviewScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('V', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16,
                )),
              ),
            ),
            const SizedBox(width: 10),
            const Text('VNITx Security'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),

          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildScreen(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          items: _items.map((item) => BottomNavigationBarItem(
            icon: Icon(item.icon),
            activeIcon: Icon(item.activeIcon),
            label: item.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// ──────────────────────────────────────────────────────────────────────────────
// OVERVIEW SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class _OverviewScreen extends StatelessWidget {
  const _OverviewScreen();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withOpacity(0.2),
                AppTheme.accent.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security, color: AppTheme.accent, size: 28),
                  const SizedBox(width: 12),
                  Text('VNITx Multimodal Security',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI-powered detection of deepfakes, voice synthesis, prompt injection, and cross-modal inconsistencies.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text('HackIITK 2026',
                style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('Detection Capabilities', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        ..._capabilities.map((cap) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CapabilityCard(capability: cap),
        )),

        const SizedBox(height: 8),
        Text('Mobile Feature', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        // Screen recording highlight card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.radio_button_checked, color: AppTheme.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Screen Recording Analysis',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record any on-screen call, auto-extract audio & video, and analyse both with the AI APIs.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  static const _capabilities = [
    _Capability(
      icon: Icons.graphic_eq,
      label: 'AI Voice Detection',
      description: 'Detect synthetic / AI-generated speech using hybrid physics + DL ensemble.',
      color: Color(0xFF7C4DFF),
    ),
    _Capability(
      icon: Icons.image_search,
      label: 'Image Prompt Injection',
      description: 'Detect adversarial text hidden in images via OCR + DeBERTa injection model.',
      color: Color(0xFF00BCD4),
    ),
    _Capability(
      icon: Icons.movie_filter,
      label: 'Video Deepfake Detection',
      description: 'Frame-by-frame deepfake analysis, AV-sync checks, and cross-modal scoring.',
      color: Color(0xFFFF4081),
    ),
  ];
}

class _Capability {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  const _Capability({required this.icon, required this.label, required this.description, required this.color});
}

class _CapabilityCard extends StatelessWidget {
  final _Capability capability;
  const _CapabilityCard({required this.capability});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: capability.color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: capability.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(capability.icon, color: capability.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(capability.label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(capability.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}