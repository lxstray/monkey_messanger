import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;
  
  String? _lastGeneratedCode;
  
  EmailService({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    required SharedPreferences prefs,
  }) : _firebaseAuth = firebaseAuth,
      _firestore = firestore,
      _prefs = prefs;
      
  String? get lastGeneratedCode => _lastGeneratedCode;
  
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); 
  }
  
  Future<bool> sendVerificationCode(String email) async {
    try {
      final code = _generateVerificationCode();
      _lastGeneratedCode = code; 
      
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));
      
      await _firestore.collection(AppConstants.verificationCodesCollection).doc(email).set({
        'code': code,
        'expiresAt': expiresAt,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      final success = await _sendEmailViaService(email, code);
      
      if (!success) {
        AppLogger.info('Email service failed, verification code for testing: $code');
      }
      
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error sending verification code', e, stackTrace);
      return false;
    }
  }
  
  Future<bool> _sendEmailViaService(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.emailServiceUrl}/api/send-verification-code'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': AppConstants.emailServiceApiKey,
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        AppLogger.error('Email service error: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error calling email service', e, stackTrace);
      return false;
    }
  }
  
  Future<bool> verifyCode(String email, String code) async {
    try {
      final docRef = _firestore.collection(AppConstants.verificationCodesCollection).doc(email);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        return false;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final storedCode = data['code'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      
      if (DateTime.now().isAfter(expiresAt)) {
        await docRef.delete();
        return false;
      }
      
      final isValid = storedCode == code;
      
      if (isValid) {
        await docRef.delete();
      }
      
      return isValid;
    } catch (e, stackTrace) {
      AppLogger.error('Error verifying code', e, stackTrace);
      return false;
    }
  }
  
  void showTestCodeDialog(BuildContext context) {
    if (_lastGeneratedCode != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              'Тестовый код 2FA',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Код для тестирования: $_lastGeneratedCode\n\nВ реальном приложении этот код будет отправлен на указанный email через сервер отправки писем.',
              style: const TextStyle(color: Colors.white),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF4A90E2)),
                ),
              ),
            ],
          );
        },
      );
    }
  }
} 