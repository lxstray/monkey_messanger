import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_logger.dart';

class ImageHelper {
  // Singleton pattern
  static final ImageHelper _instance = ImageHelper._internal();
  factory ImageHelper() => _instance;
  ImageHelper._internal();
  
  // Кэш проверенных URL
  final Set<String> _validatedUrls = {};
  
  // Проверяет, можно ли загрузить изображение по указанному URL
  Future<bool> isImageUrlValid(String url) async {
    if (url.isEmpty) return false;
    
    // Если URL уже был проверен ранее, просто возвращаем результат
    if (_validatedUrls.contains(url)) return true;
    
    try {
      // Пытаемся создать ImageProvider и загрузить изображение
      final provider = NetworkImage(url);
      final completer = Completer<bool>();
      
      // Настраиваем ImageStreamListener с обработкой ошибок
      final listener = ImageStreamListener(
        (info, syncCall) {
          _validatedUrls.add(url); // Добавляем URL в список проверенных
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (exception, stackTrace) {
          AppLogger.error('Image URL validation failed: $url', exception, stackTrace);
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      
      // Запускаем загрузку изображения
      final stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(listener);
      
      // Устанавливаем таймаут на загрузку
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          stream.removeListener(listener);
          completer.complete(false);
        }
      });
      
      return await completer.future;
    } catch (e, stackTrace) {
      AppLogger.error('Image URL validation error: $url', e, stackTrace);
      return false;
    }
  }
  
  // Предварительно загружает изображение, чтобы оно было в кэше
  Future<void> preloadImage(String url) async {
    if (url.isEmpty) return;
    
    try {
      final provider = NetworkImage(url);
      final completer = Completer<void>();
      
      // Настраиваем ImageStreamListener
      final listener = ImageStreamListener(
        (info, syncCall) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (exception, stackTrace) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      
      // Запускаем загрузку изображения
      final stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(listener);
      
      // Устанавливаем таймаут
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          stream.removeListener(listener);
          completer.complete();
        }
      });
      
      await completer.future;
    } catch (e) {
      // Игнорируем ошибки при предзагрузке
    }
  }
  
  // Очищает кэш проверенных URL
  void clearCache() {
    _validatedUrls.clear();
  }
} 