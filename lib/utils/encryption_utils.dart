import 'package:encrypt/encrypt.dart';
import 'package:monkey_messanger/utils/app_logger.dart';

class EncryptionUtils {
  static const String _fixedKeyString = 'MonkeyMessengerFixedEncryptionKey123'; 
  static const String _fixedIvString = 'MonkeyMsgFixedIV'; 

  static final _key = Key.fromUtf8(_fixedKeyString);
  static final _iv = IV.fromUtf8(_fixedIvString);
  static final _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  static String encryptText(String plainText) {
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e, stackTrace) {
      AppLogger.error('Encryption failed', e, stackTrace);
      return plainText; 
    }
  }

  static String decryptText(String encryptedTextBase64) {
    if (encryptedTextBase64.isEmpty) {
      return '';
    }
    try {
      final encrypted = Encrypted.fromBase64(encryptedTextBase64);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      return decrypted;
    } catch (e, stackTrace) {
      AppLogger.warning(
          'Decryption failed for text (returning placeholder). Input: [$encryptedTextBase64]',
          e, 
          stackTrace
      );
      return '[Не удалось расшифровать]'; 
    }
  }
  
  static String decryptMessageSafe(String? encryptedText) {
    if (encryptedText == null || encryptedText.isEmpty) {
      return '';
    }
    return decryptText(encryptedText);
  }
} 