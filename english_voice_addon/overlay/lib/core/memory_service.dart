import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';

class MemoryHit {
  final ChatMessage message;
  final double score;
  const MemoryHit(this.message, this.score);
}

class MemoryService {
  static const _secure = FlutterSecureStorage();
  final _cipher = AesGcm.with256bits();
  Database? _db;
  SecretKey? _key;

  Future<void> init() async {
    final root = await getDatabasesPath();
    _db = await openDatabase(
      join(root, 'atlas_memory.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            role TEXT NOT NULL,
            ciphertext TEXT NOT NULL,
            nonce TEXT NOT NULL,
            mac TEXT NOT NULL,
            created_at TEXT NOT NULL,
            embedding TEXT
          )
        ''');
      },
    );
    final existing = await _secure.read(key: 'atlas_memory_key');
    if (existing == null) {
      final k = await _cipher.newSecretKey();
      final bytes = await k.extractBytes();
      await _secure.write(key: 'atlas_memory_key', value: base64Encode(bytes));
      _key = SecretKey(bytes);
    } else {
      _key = SecretKey(base64Decode(existing));
    }
  }

  Future<void> save(ChatMessage message, {List<double>? embedding}) async {
    final key = _key!;
    final nonce = _randomBytes(12);
    final box = await _cipher.encrypt(
      utf8.encode(message.content),
      secretKey: key,
      nonce: nonce,
    );
    await _db!.insert(
      'messages',
      {
        'id': message.id,
        'role': message.role,
        'ciphertext': base64Encode(box.cipherText),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'created_at': message.createdAt.toIso8601String(),
        'embedding': embedding == null ? null : jsonEncode(embedding),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> recent({int limit = 30}) async {
    final rows = await _db!.query('messages', orderBy: 'created_at DESC', limit: limit);
    final out = <ChatMessage>[];
    for (final row in rows.reversed) {
      out.add(await _decode(row));
    }
    return out;
  }

  Future<List<MemoryHit>> semanticSearch(List<double> query, {int limit = 6}) async {
    final rows = await _db!.query('messages', where: 'embedding IS NOT NULL', limit: 500);
    final hits = <MemoryHit>[];
    for (final row in rows) {
      final raw = row['embedding'] as String?;
      if (raw == null) continue;
      final vector = (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
      if (vector.length != query.length) continue;
      final msg = await _decode(row);
      hits.add(MemoryHit(msg, _cosine(query, vector)));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  /// Fast local retrieval for Qwen/local mode. No network and no embedding wait.
  Future<List<MemoryHit>> lexicalSearch(String query, {int limit = 8}) async {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return const [];
    final rows = await _db!.query('messages', orderBy: 'created_at DESC', limit: 1200);
    final hits = <MemoryHit>[];
    final now = DateTime.now();
    for (final row in rows) {
      final msg = await _decode(row);
      final body = _tokens(msg.content);
      if (body.isEmpty) continue;
      var overlap = 0.0;
      for (final token in tokens) {
        if (body.contains(token)) overlap += 1.0;
      }
      if (overlap == 0) continue;
      final ageDays = now.difference(msg.createdAt).inHours / 24.0;
      final recency = 1.0 / (1.0 + ageDays / 180.0);
      final score = (overlap / tokens.length) * 0.88 + recency * 0.12;
      hits.add(MemoryHit(msg, score));
    }
    hits.sort((a,b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  Set<String> _tokens(String text) {
    const stop = {'the','a','an','is','are','was','were','to','of','and','or','in','on','من','تو','را','به','از','که','و','در','این','اون','آن','یک','برای','با','چی','چه'};
    return text.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((e) => e.length > 1 && !stop.contains(e))
      .toSet();
  }

  Future<void> wipe() async {
    await _db?.delete('messages');
  }

  Future<ChatMessage> _decode(Map<String, Object?> row) async {
    final box = SecretBox(
      base64Decode(row['ciphertext'] as String),
      nonce: base64Decode(row['nonce'] as String),
      mac: Mac(base64Decode(row['mac'] as String)),
    );
    final clear = await _cipher.decrypt(box, secretKey: _key!);
    return ChatMessage(
      id: row['id'] as String,
      role: row['role'] as String,
      content: utf8.decode(clear),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  double _cosine(List<double> a, List<double> b) {
    var dot = 0.0, aa = 0.0, bb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      aa += a[i] * a[i];
      bb += b[i] * b[i];
    }
    if (aa == 0 || bb == 0) return 0;
    return dot / (sqrt(aa) * sqrt(bb));
  }
}
