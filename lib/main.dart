import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/settings_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  await settings.load();
  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: const VNITxApp(),
    ),
  );
}

class VNITxApp extends StatelessWidget {
  const VNITxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VNITx Security',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
