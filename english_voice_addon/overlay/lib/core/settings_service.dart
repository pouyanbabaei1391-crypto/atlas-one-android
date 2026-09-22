import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
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

  Future<String> get baseUrl async =>
      (await _storage.read(key: 'base_url')) ?? 'http://192.168.1.10:11434/v1';
  Future<void> setBaseUrl(String value) =>
      _storage.write(key: 'base_url', value: value.trim());

  Future<String> get model async =>
      (await _storage.read(key: 'model')) ?? 'gemma3:4b';
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
}
