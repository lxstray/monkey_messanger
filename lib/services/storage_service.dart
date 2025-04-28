import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../utils/supabase_config.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../utils/image_helper.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();
  final _imageHelper = ImageHelper();

  // Загрузка изображения в Supabase Storage с оптимизацией
  Future<String> uploadImage(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final filePath = 'chats/$chatId/images/$fileName';
      
      // Компрессия изображения перед загрузкой
      final compressedFile = await _compressImage(file);
      if (compressedFile == null) {
        AppLogger.error('Failed to compress image', null, StackTrace.current);
        return '';
      }
      
      // Убеждаемся, что файл существует и не превышает ограничение размера
      final fileSize = await compressedFile.length();
      if (fileSize > 5 * 1024 * 1024) { // 5 MB
        AppLogger.error('File size too large: $fileSize bytes', null, StackTrace.current);
        return '';
      }
      
      // Загружаем файл
      await _supabase.storage
          .from(SupabaseConfig.chatImagesBucket)
          .upload(filePath, compressedFile);
          
      // Получаем публичную ссылку на изображение
      final imageUrl = _supabase.storage
          .from(SupabaseConfig.chatImagesBucket)
          .getPublicUrl(filePath);
          
      // Проверяем, что URL действительно валидный
      if (imageUrl.isEmpty) {
        throw Exception('Получен пустой URL после загрузки изображения');
      }
      
      // Проверяем доступность изображения
      final isValid = await _imageHelper.isImageUrlValid(imageUrl);
      if (!isValid) {
        AppLogger.error('Image URL is not valid after upload: $imageUrl', null, StackTrace.current);
        return '';
      }
      
      // Предзагружаем изображение в кэш
      await _imageHelper.preloadImage(imageUrl);
      
      AppLogger.info('Image uploaded and validated successfully: $filePath, URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      AppLogger.error('Failed to upload image', e, StackTrace.current);
      // Возвращаем пустую строку вместо исключения, чтобы избежать краша
      return '';
    }
  }
  
  // Метод для компрессии изображения
  Future<File?> _compressImage(File file) async {
    try {
      // Определяем путь для сжатого файла
      final dir = path.dirname(file.path);
      final ext = path.extension(file.path).toLowerCase();
      final outPath = path.join(dir, '${path.basenameWithoutExtension(file.path)}_compressed$ext');
      
      // Сжимаем изображение
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
      // В случае ошибки при сжатии, возвращаем исходный файл
      return file;
    }
  }

  // Загрузка файла в Supabase Storage
  Future<String> uploadFile(File file, String chatId) async {
    try {
      final fileName = '${_uuid.v4()}${path.extension(file.path)}';
      final filePath = 'chats/$chatId/$fileName';
      
      // Загружаем файл
      await _supabase.storage
          .from(SupabaseConfig.chatFilesBucket)
          .upload(filePath, file);
          
      // Получаем публичную ссылку на файл
      final fileUrl = _supabase.storage
          .from(SupabaseConfig.chatFilesBucket)
          .getPublicUrl(filePath);
          
      // Проверяем, что URL действительно валидный
      if (fileUrl.isEmpty) {
        throw Exception('Получен пустой URL после загрузки файла');
      }
      
      AppLogger.info('File uploaded successfully: $filePath, URL: $fileUrl');
      return fileUrl;
    } catch (e) {
      AppLogger.error('Failed to upload file', e, StackTrace.current);
      // Возвращаем пустую строку вместо исключения, чтобы избежать краша
      return '';
    }
  }

  // Загрузка голосового сообщения
  Future<String> uploadVoiceMessage(File file, String chatId) async {
    try {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = 'chats/$chatId/voice/$fileName';
      
      // Загружаем файл
      await _supabase.storage
          .from(SupabaseConfig.chatVoiceBucket)
          .upload(filePath, file);
          
      // Получаем публичную ссылку на голосовое сообщение
      final voiceUrl = _supabase.storage
          .from(SupabaseConfig.chatVoiceBucket)
          .getPublicUrl(filePath);
          
      // Проверяем, что URL действительно валидный
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