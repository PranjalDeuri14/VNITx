import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class SettingsProvider extends ChangeNotifier {
  String _audioBase = AppConstants.defaultAudioBase;
  String _imageBase = AppConstants.defaultImageBase;
  String _videoBase = AppConstants.defaultVideoBase;
  String _apiKey = AppConstants.defaultAudioApiKey;

  String get audioBase => _audioBase;
  String get imageBase => _imageBase;
  String get videoBase => _videoBase;
  String get apiKey => _apiKey;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _audioBase = prefs.getString(AppConstants.prefAudioBase) ?? AppConstants.defaultAudioBase;
    _imageBase = prefs.getString(AppConstants.prefImageBase) ?? AppConstants.defaultImageBase;
    _videoBase = prefs.getString(AppConstants.prefVideoBase) ?? AppConstants.defaultVideoBase;
    _apiKey = prefs.getString(AppConstants.prefApiKey) ?? AppConstants.defaultAudioApiKey;
    notifyListeners();
  }

  Future<void> save({
    required String audioBase,
    required String imageBase,
    required String videoBase,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _audioBase = audioBase.trim().isNotEmpty ? audioBase.trim() : AppConstants.defaultAudioBase;
    _imageBase = imageBase.trim().isNotEmpty ? imageBase.trim() : AppConstants.defaultImageBase;
    _videoBase = videoBase.trim().isNotEmpty ? videoBase.trim() : AppConstants.defaultVideoBase;
    _apiKey = apiKey.trim();
    await prefs.setString(AppConstants.prefAudioBase, _audioBase);
    await prefs.setString(AppConstants.prefImageBase, _imageBase);
    await prefs.setString(AppConstants.prefVideoBase, _videoBase);
    await prefs.setString(AppConstants.prefApiKey, _apiKey);
    notifyListeners();
  }

  Future<void> reset() async {
    await save(
      audioBase: AppConstants.defaultAudioBase,
      imageBase: AppConstants.defaultImageBase,
      videoBase: AppConstants.defaultVideoBase,
      apiKey: AppConstants.defaultAudioApiKey,
    );
  }
}

// Helper to encode bytes as base64
String bytesToBase64(Uint8List bytes) => base64Encode(bytes);
