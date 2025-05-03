import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_entity.dart';
import '../models/chat_entity.dart';
import '../utils/app_logger.dart';

// Events
abstract class ChatEvent {}

class LoadMessagesEvent extends ChatEvent {
  final String chatId;
  LoadMessagesEvent(this.chatId);
}

class SendMessageEvent extends ChatEvent {
  final String chatId;
  final String content;
  final MessageType type;
  final String senderId;
  final int? voiceDurationSeconds;
  SendMessageEvent({
    required this.chatId,
    required this.content,
    required this.type,
    required this.senderId,
    this.voiceDurationSeconds,
  });
}

class ResetChatEvent extends ChatEvent {
  ResetChatEvent();
}

// States
abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<MessageEntity> messages;
  final ChatEntity? chat;
  
  ChatLoaded(this.messages, {this.chat});
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  
  // Ключи шифрования
  late encrypt.Key _encryptionKey;
  late encrypt.IV _iv;
  bool _isEncryptionReady = false;

  // Фиксированные значения ключей
  static const String _fixedKeyString = 'MonkeyMessengerFixedEncryptionKey123';
  static const String _fixedIvString = 'MonkeyMsgFixedIV';

  ChatBloc() : super(ChatInitial()) {
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<ResetChatEvent>(_onResetChat);
    _initEncryption();
  }

  // Инициализация ключей шифрования
  Future<void> _initEncryption() async {
    try {
      // Используем фиксированные ключи вместо случайной генерации
      _encryptionKey = encrypt.Key(utf8.encode(_fixedKeyString).sublist(0, 32));
      _iv = encrypt.IV(utf8.encode(_fixedIvString).sublist(0, 16));
      
      // Сохраняем ключи в SharedPreferences для совместимости с существующим кодом
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('encryption_key', base64Encode(_encryptionKey.bytes));
      await prefs.setString('encryption_iv', base64Encode(_iv.bytes));
      
      _isEncryptionReady = true;
      AppLogger.info('Encryption initialized successfully with fixed keys');
    } catch (e) {
      AppLogger.error('Failed to initialize encryption', e, StackTrace.current);
      _isEncryptionReady = false;
      // Создаем ключи из фиксированных строк в случае ошибки
      _encryptionKey = encrypt.Key(utf8.encode(_fixedKeyString).sublist(0, 32));
      _iv = encrypt.IV(utf8.encode(_fixedIvString).sublist(0, 16));
    }
  }

  void _onLoadMessages(LoadMessagesEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      // Отменяем предыдущую подписку, если она есть
      await _messagesSubscription?.cancel();
      
      // Проверяем готовность шифрования
      if (!_isEncryptionReady) {
        await _initEncryption();
      }
      
      // Сначала загружаем информацию о чате
      final chatDoc = await _firestore.collection('chats').doc(event.chatId).get();
      ChatEntity? chat;
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        chat = ChatEntity.fromMap({...chatData, 'id': chatDoc.id});
      }
      
      // Используем StreamController для преобразования потока Firestore в поток, 
      // с которым можно безопасно работать в BLoC
      final controller = StreamController<List<MessageEntity>>();
      
      _messagesSubscription = _firestore
          .collection('chats')
          .doc(event.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50) // Ограничиваем количество сообщений для предотвращения перегрузки
          .snapshots()
          .listen(
        (snapshot) {
          try {
            final messages = snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                final messageType = MessageType.values[data['type'] ?? 0];

                // Только для текстовых сообщений выполняем дешифрование
                if (messageType == MessageType.text && data['text'] != null) {
                  try {
                    data['text'] = _decryptMessage(data['text']);
                  } catch (e) {
                    AppLogger.error('Failed to decrypt message', e, StackTrace.current);
                    // Если не удалось расшифровать, используем текст с пометкой
                    data['text'] = '[Encrypted message]';
                  }
                }

                return MessageEntity.fromMap({
                  ...data,
                  'id': doc.id,
                  'chatId': event.chatId,
                  'timestamp': data['timestamp'] ?? Timestamp.now(),
                });
              } catch (e) {
                AppLogger.error('Error parsing message', e, StackTrace.current);
                // Возвращаем пустое сообщение для предотвращения краша
                return MessageEntity.system(
                  id: doc.id,
                  chatId: event.chatId,
                  text: 'Error loading message',
                  timestamp: DateTime.now(),
                );
              }
            }).toList();
            
            controller.add(messages);
          } catch (e) {
            AppLogger.error('Error processing messages', e, StackTrace.current);
            controller.addError(e);
          }
        },
        onError: (error) {
          AppLogger.error('Error in messages stream', error, StackTrace.current);
          controller.addError(error);
        },
      );
      
      // Подписываемся на поток из StreamController
      await emit.forEach<List<MessageEntity>>(
        controller.stream,
        onData: (messages) => ChatLoaded(messages, chat: chat),
        onError: (error, _) => ChatError('Error loading messages: ${error.toString().split('\n').first}'),
      );
      
      // Закрываем контроллер при отмене подписки
      await controller.close();
    } catch (e) {
      AppLogger.error('Failed to load messages', e, StackTrace.current);
      emit(ChatError('Failed to load messages. Please try again.'));
    }
  }

  void _onSendMessage(SendMessageEvent event, Emitter<ChatState> emit) async {
    try {
      // Проверяем готовность шифрования
      if (!_isEncryptionReady) {
        await _initEncryption();
      }

      final messageData = {
        'type': event.type.index,
        'senderId': event.senderId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Добавляем специфичные для типа сообщения поля
      switch (event.type) {
        case MessageType.text:
          messageData['text'] = _encryptMessage(event.content);
          break;
        case MessageType.image:
          messageData['mediaUrl'] = event.content;
          break;
        case MessageType.file:
          messageData['mediaUrl'] = event.content;
          messageData['mediaName'] = event.content.split('/').last;
          break;
        case MessageType.voice:
          messageData['mediaUrl'] = event.content;
          if (event.voiceDurationSeconds != null) {
            messageData['voiceDurationSeconds'] = event.voiceDurationSeconds as int;
          }
          break;
        case MessageType.system:
          messageData['text'] = event.content;
          break;
      }

      // Добавляем сообщение в чат
      await _firestore
          .collection('chats')
          .doc(event.chatId)
          .collection('messages')
          .add(messageData);

      // Обновляем последнее сообщение в чате
      String lastMessage = '';
      
      switch (event.type) {
        case MessageType.text:
          lastMessage = _encryptMessage(event.content); // Шифруем текст для хранения
          break;
        case MessageType.image:
          lastMessage = '📷 Изображение';
          break;
        case MessageType.file:
          lastMessage = '📎 Файл: ${event.content.split('/').last}';
          break;
        case MessageType.voice:
          String duration = '';
          if (event.voiceDurationSeconds != null) {
            final minutes = event.voiceDurationSeconds! ~/ 60;
            final seconds = event.voiceDurationSeconds! % 60;
            duration = ' (${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')})';
          }
          lastMessage = '🎤 Голосовое сообщение$duration';
          break;
        case MessageType.system:
          lastMessage = event.content;
          break;
      }

      // Базовое обновление для всех типов сообщений
      final updateData = {
        'lastMessageText': lastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': event.senderId,
        'lastMessageType': event.type.index,
      };

      await _firestore.collection('chats').doc(event.chatId).update(updateData);
    } catch (e) {
      AppLogger.error('Failed to send message', e, StackTrace.current);
      emit(ChatError('Failed to send message. Please try again.'));
    }
  }

  void _onResetChat(ResetChatEvent event, Emitter<ChatState> emit) async {
    // Отменяем текущую подписку на сообщения
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    
    // Сбрасываем состояние в начальное
    emit(ChatInitial());
    AppLogger.info('Chat state reset');
  }

  String _encryptMessage(String message) {
    if (!_isEncryptionReady) {
      return message; // Если шифрование не готово, возвращаем как есть
    }
    
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      return encrypter.encrypt(message, iv: _iv).base64;
    } catch (e) {
      AppLogger.error('Failed to encrypt message', e, StackTrace.current);
      return message;
    }
  }

  String _decryptMessage(String encryptedMessage) {
    if (!_isEncryptionReady) {
      return encryptedMessage; // Если шифрование не готово, возвращаем как есть
    }
    
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      return encrypter.decrypt64(encryptedMessage, iv: _iv);
    } catch (e) {
      AppLogger.error('Failed to decrypt message', e, StackTrace.current);
      throw e; // Пробрасываем ошибку для обработки выше
    }
  }

  // Публичный метод для расшифрования сообщений
  String decryptMessageSafe(String encryptedMessage) {
    try {
      return _decryptMessage(encryptedMessage);
    } catch (e) {
      AppLogger.error('Failed to decrypt message safely', e, StackTrace.current);
      return '[Зашифрованное сообщение]';
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
} 