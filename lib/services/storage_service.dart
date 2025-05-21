import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../utils/supabase_config.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../utils/image_helper.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();
  final _imageHelper = ImageHelper();

  Future<String> uploadImage(File file, String contextId, {String? specificPath}) async {
    try {
      final fileName = '${_uuid.v4()}${path.extension(file.path)}';
      final filePath = specificPath ?? 'chats/$contextId/images/$fileName';
      
      final compressedFile = await _compressImage(file);
      if (compressedFile == null) {
        AppLogger.error('Failed to compress image', null, StackTrace.current);
        return '';
      }
      
      final fileSize = await compressedFile.length();
      if (fileSize > 5 * 1024 * 1024) { // 5 MB
        AppLogger.error('File size too large: $fileSize bytes', null, StackTrace.current);
        return '';
      }
      
      await _supabase.storage
          .from(SupabaseConfig.chatImagesBucket)
          .upload(filePath, compressedFile);
          
      final imageUrl = _supabase.storage
          .from(SupabaseConfig.chatImagesBucket)
          .getPublicUrl(filePath);
          
      if (imageUrl.isEmpty) {
        throw Exception('Получен пустой URL после загрузки изображения');
      }
 
      await _imageHelper.preloadImage(imageUrl);
      
      AppLogger.info('Image uploaded successfully: $filePath, URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      AppLogger.error('Failed to upload image', e, StackTrace.current);
      return '';
    }
  }
  
  Future<File?> _compressImage(File file) async {
    try {
      final dir = path.dirname(file.path);
      final ext = path.extension(file.path).toLowerCase();
      final outPath = path.join(dir, '${path.basenameWithoutExtension(file.path)}_compressed$ext');
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path, 
        outPath,
        quality: 80,
        minWidth: 1000,
        minHeight: 1000,
      );
      
      return result != null ? File(result.path) : file;
    } catch (e) {
      AppLogger.error('Error compressing image', e, StackTrace.current);
      return file;
    }
  }

  Future<String> uploadFile(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}${path.extension(file.path)}';
      final filePath = 'chats/$chatId/$fileName';
      
      await _supabase.storage
          .from(SupabaseConfig.chatFilesBucket)
          .upload(filePath, file);
          
      final fileUrl = _supabase.storage
          .from(SupabaseConfig.chatFilesBucket)
          .getPublicUrl(filePath);
          
      if (fileUrl.isEmpty) {
        throw Exception('Получен пустой URL после загрузки файла');
      }
      
      AppLogger.info('File uploaded successfully: $filePath, URL: $fileUrl');
      return fileUrl;
    } catch (e) {
      AppLogger.error('Failed to upload file', e, StackTrace.current);
      return '';
    }
  }

  Future<String> uploadVoiceMessage(File file, String chatId) async {
    try {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = 'chats/$chatId/voice/$fileName';
      
      await _supabase.storage
          .from(SupabaseConfig.chatVoiceBucket)
          .upload(filePath, file);
          
      final voiceUrl = _supabase.storage
          .from(SupabaseConfig.chatVoiceBucket)
          .getPublicUrl(filePath);
          
      if (voiceUrl.isEmpty) {
        throw Exception('Получен пустой URL после загрузки голосового сообщения');
      }
      
      AppLogger.info('Voice message uploaded successfully: $filePath');
      return voiceUrl;
    } catch (e) {
      AppLogger.error('Failed to upload voice message', e, StackTrace.current);
      return '';
    }
  }
} 