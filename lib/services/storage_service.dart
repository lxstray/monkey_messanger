import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../utils/supabase_config.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // Загрузка файла в Supabase Storage
  Future<String> uploadFile(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}${path.extension(file.path)}';
      final filePath = 'chats/$chatId/$fileName';
      
      final response = await _supabase.storage
          .from(SupabaseConfig.chatFilesBucket)
          .upload(filePath, file);
          
      // Получаем публичную ссылку на файл
      final fileUrl = _supabase.storage
          .from(SupabaseConfig.chatFilesBucket)
          .getPublicUrl(filePath);
          
      AppLogger.info('File uploaded successfully: $filePath');
      return fileUrl;
    } catch (e) {
      AppLogger.error('Failed to upload file', e, StackTrace.current);
      throw Exception('Failed to upload file: $e');
    }
  }

  // Загрузка изображения в Supabase Storage
  Future<String> uploadImage(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final filePath = 'chats/$chatId/images/$fileName';
      
      final response = await _supabase.storage
          .from(SupabaseConfig.chatImagesBucket)
          .upload(filePath, file);
          
      // Получаем публичную ссылку на изображение
      final imageUrl = _supabase.storage
          .from(SupabaseConfig.chatImagesBucket)
          .getPublicUrl(filePath);
          
      AppLogger.info('Image uploaded successfully: $filePath');
      return imageUrl;
    } catch (e) {
      AppLogger.error('Failed to upload image', e, StackTrace.current);
      throw Exception('Failed to upload image: $e');
    }
  }

  // Загрузка голосового сообщения в Supabase Storage
  Future<String> uploadVoice(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}.m4a';
      final filePath = 'chats/$chatId/voice/$fileName';
      
      final response = await _supabase.storage
          .from(SupabaseConfig.chatVoiceBucket)
          .upload(filePath, file);
          
      // Получаем публичную ссылку на голосовое сообщение
      final voiceUrl = _supabase.storage
          .from(SupabaseConfig.chatVoiceBucket)
          .getPublicUrl(filePath);
          
      AppLogger.info('Voice message uploaded successfully: $filePath');
      return voiceUrl;
    } catch (e) {
      AppLogger.error('Failed to upload voice message', e, StackTrace.current);
      throw Exception('Failed to upload voice message: $e');
    }
  }
} 