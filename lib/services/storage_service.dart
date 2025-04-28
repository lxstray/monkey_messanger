import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> uploadFile(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}${path.extension(file.path)}';
      final ref = _storage.ref().child('chats/$chatId/$fileName');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<String> uploadImage(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref().child('chats/$chatId/images/$fileName');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<String> uploadVoice(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}.m4a';
      final ref = _storage.ref().child('chats/$chatId/voice/$fileName');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload voice message: $e');
    }
  }
} 