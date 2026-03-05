// Core constants for the VNITx app
class AppConstants {
  // Default API Base URLs
  static const String defaultAudioBase =
      'https://arshan123-voice-detection-api.hf.space';
  static const String defaultImageBase =
      'https://arshan123-vnitx-image.hf.space';
  static const String defaultVideoBase =
      'https://arshan123-vnitx-video.hf.space';

  // Default API Key
  static const String defaultAudioApiKey = 'sk_test_123456789';

  // Languages supported by Audio API
  static const List<String> languages = [
    'English',
    'Tamil',
    'Hindi',
    'Malayalam',
    'Telugu',
  ];

  // SharedPreferences keys
  static const String prefAudioBase = 'audio_base';
  static const String prefImageBase = 'image_base';
  static const String prefVideoBase = 'video_base';
  static const String prefApiKey = 'audio_api_key';

  // Android platform channel
  static const String screenRecordChannel = 'vnit_x/screen_record';
}
