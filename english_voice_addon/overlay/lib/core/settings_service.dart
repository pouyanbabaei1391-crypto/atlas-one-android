import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static const groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const groqFastModel = 'llama-3.1-8b-instant';
  static const legacyDefaultBaseUrl = 'http://192.168.1.10:11434/v1';
  Future<bool> get useLocalAi async =>
      Platform.isAndroid && (await _storage.read(key: 'use_local_gemma')) != 'false';
  Future<void> setUseLocalAi(bool value) => _storage.write(key: 'use_local_gemma', value: value.toString());
  Future<bool> get modelTermsAccepted async => (await _storage.read(key: 'gemma_terms')) == 'accepted';
  Future<void> acceptModelTerms() => _storage.write(key: 'gemma_terms', value: 'accepted');
  static const _storage = FlutterSecureStorage();

  Future<String> get userName async =>
      (await _storage.read(key: 'user_name')) ?? 'friend';
  Future<void> setUserName(String value) =>
      _storage.write(key: 'user_name', value: value.trim());

  Future<String> get baseUrl async {
    final value = await _storage.read(key: 'base_url');
    return value == null || value.trim().isEmpty || value == legacyDefaultBaseUrl
        ? groqBaseUrl : value.trim();
  }
  Future<void> setBaseUrl(String value) =>
      _storage.write(key: 'base_url', value: value.trim());

  Future<String> get model async {
    final value = await _storage.read(key: 'model');
    return value == null || value.trim().isEmpty || value == 'gemma3:4b'
        ? groqFastModel : value.trim();
  }
  Future<void> setModel(String value) =>
      _storage.write(key: 'model', value: value.trim());

  Future<String> get embeddingModel async =>
      (await _storage.read(key: 'embedding_model')) ?? 'embeddinggemma';
  Future<void> setEmbeddingModel(String value) =>
      _storage.write(key: 'embedding_model', value: value.trim());

  Future<String> get apiKey async =>
      (await _storage.read(key: 'api_key')) ?? '';
  Future<void> setApiKey(String value) =>
      _storage.write(key: 'api_key', value: value.trim());

  Future<bool> get cloudConfigured async {
    final url = await baseUrl;
    final key = await apiKey;
    // A custom Gateway may safely hold the provider key and require no key in the APK.
    return key.trim().isNotEmpty || url != groqBaseUrl;
  }
}
