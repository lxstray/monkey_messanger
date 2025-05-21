import 'dart:async';
import 'package:flutter/material.dart';
import 'app_logger.dart';

class ImageHelper {
  static final ImageHelper _instance = ImageHelper._internal();
  factory ImageHelper() => _instance;
  ImageHelper._internal();
  
  final Set<String> _validatedUrls = {};
  
  Future<bool> isImageUrlValid(String url) async {
    if (url.isEmpty) return false;
    
    if (_validatedUrls.contains(url)) return true;
    
    try {
      final provider = NetworkImage(url);
      final completer = Completer<bool>();
      
      final listener = ImageStreamListener(
        (info, syncCall) {
          _validatedUrls.add(url); 
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (exception, stackTrace) {
          AppLogger.error('Image URL validation failed: $url', exception, stackTrace);
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      
      final stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(listener);
      
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
  
  Future<void> preloadImage(String url) async {
    if (url.isEmpty) return;
    
    try {
      final provider = NetworkImage(url);
      final completer = Completer<void>();
      
      final listener = ImageStreamListener(
        (info, syncCall) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (exception, stackTrace) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      
      final stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(listener);
      
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          stream.removeListener(listener);
          completer.complete();
        }
      });
      
      await completer.future;
    } catch (e) {
    }
  }
  
  void clearCache() {
    _validatedUrls.clear();
  }
} 