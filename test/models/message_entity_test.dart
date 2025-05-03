import 'package:flutter_test/flutter_test.dart';
import 'package:monkey_messanger/models/message_entity.dart';

void main() {
  group('MessageEntity', () {
    final DateTime now = DateTime.now();
    
    test('should create a basic MessageEntity instance correctly', () {
      final message = MessageEntity(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        text: 'Hello, world!',
        type: MessageType.text,
        timestamp: now,
        isEdited: false,
        readStatus: {'user-123': true, 'user-456': false},
      );

      expect(message.id, 'msg-123');
      expect(message.chatId, 'chat-456');
      expect(message.senderId, 'user-789');
      expect(message.text, 'Hello, world!');
      expect(message.type, MessageType.text);
      expect(message.timestamp, now);
      expect(message.isEdited, false);
      expect(message.readStatus, {'user-123': true, 'user-456': false});
      expect(message.mediaUrl, null);
      expect(message.mediaName, null);
      expect(message.mediaSizeBytes, null);
      expect(message.voiceDurationSeconds, null);
      expect(message.metadata, null);
    });

    test('should create a text message correctly using the factory constructor', () {
      final message = MessageEntity.text(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        text: 'Hello, world!',
        timestamp: now,
        readStatus: {'user-123': true},
      );

      expect(message.id, 'msg-123');
      expect(message.chatId, 'chat-456');
      expect(message.senderId, 'user-789');
      expect(message.text, 'Hello, world!');
      expect(message.type, MessageType.text);
      expect(message.timestamp, now);
      expect(message.readStatus, {'user-123': true});
    });

    test('should create an image message correctly using the factory constructor', () {
      final message = MessageEntity.image(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        caption: 'Check this out!',
        mediaUrl: 'https://example.com/image.jpg',
        timestamp: now,
        mediaSizeBytes: 1024,
      );

      expect(message.id, 'msg-123');
      expect(message.chatId, 'chat-456');
      expect(message.senderId, 'user-789');
      expect(message.text, 'Check this out!');
      expect(message.type, MessageType.image);
      expect(message.timestamp, now);
      expect(message.mediaUrl, 'https://example.com/image.jpg');
      expect(message.mediaSizeBytes, 1024);
    });

    test('should create a file message correctly using the factory constructor', () {
      final message = MessageEntity.file(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        caption: 'Important document',
        mediaUrl: 'https://example.com/doc.pdf',
        mediaName: 'document.pdf',
        mediaSizeBytes: 2048,
        timestamp: now,
      );

      expect(message.id, 'msg-123');
      expect(message.chatId, 'chat-456');
      expect(message.senderId, 'user-789');
      expect(message.text, 'Important document');
      expect(message.type, MessageType.file);
      expect(message.timestamp, now);
      expect(message.mediaUrl, 'https://example.com/doc.pdf');
      expect(message.mediaName, 'document.pdf');
      expect(message.mediaSizeBytes, 2048);
    });

    test('copyWith should return a new instance with updated values', () {
      final original = MessageEntity(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        text: 'Original text',
        type: MessageType.text,
        timestamp: now,
        isEdited: false,
        readStatus: {'user-123': false},
      );

      final updated = original.copyWith(
        text: 'Updated text',
        isEdited: true,
        readStatus: {'user-123': true, 'user-456': false},
      );

      // Проверяем обновленные поля
      expect(updated.text, 'Updated text');
      expect(updated.isEdited, true);
      expect(updated.readStatus, {'user-123': true, 'user-456': false});

      // Проверяем, что остальные поля не изменились
      expect(updated.id, original.id);
      expect(updated.chatId, original.chatId);
      expect(updated.senderId, original.senderId);
      expect(updated.type, original.type);
      expect(updated.timestamp, original.timestamp);
    });

    test('toMap should convert MessageEntity to Map correctly', () {
      final message = MessageEntity(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        text: 'Hello, world!',
        type: MessageType.text,
        timestamp: now,
        isEdited: true,
        readStatus: {'user-123': true, 'user-456': false},
        mediaUrl: 'https://example.com/media',
        mediaName: 'file.txt',
        mediaSizeBytes: 1024,
        voiceDurationSeconds: 30,
        metadata: {'key': 'value'},
      );

      final map = message.toMap();

      expect(map['id'], 'msg-123');
      expect(map['chatId'], 'chat-456');
      expect(map['senderId'], 'user-789');
      expect(map['text'], 'Hello, world!');
      expect(map['type'], MessageType.text.index);
      expect(map['timestamp'], now.millisecondsSinceEpoch);
      expect(map['isEdited'], true);
      expect(map['readStatus'], {'user-123': true, 'user-456': false});
      expect(map['mediaUrl'], 'https://example.com/media');
      expect(map['mediaName'], 'file.txt');
      expect(map['mediaSizeBytes'], 1024);
      expect(map['voiceDurationSeconds'], 30);
      expect(map['metadata'], {'key': 'value'});
    });

    test('fromMap should create MessageEntity from Map correctly', () {
      final map = {
        'id': 'msg-123',
        'chatId': 'chat-456',
        'senderId': 'user-789',
        'text': 'Hello, world!',
        'type': MessageType.text.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': true,
        'readStatus': {'user-123': true, 'user-456': false},
        'mediaUrl': 'https://example.com/media',
        'mediaName': 'file.txt',
        'mediaSizeBytes': 1024,
        'voiceDurationSeconds': 30,
        'metadata': {'key': 'value'},
      };

      final messageFromMap = MessageEntity.fromMap(map);

      expect(messageFromMap.id, 'msg-123');
      expect(messageFromMap.chatId, 'chat-456');
      expect(messageFromMap.senderId, 'user-789');
      expect(messageFromMap.text, 'Hello, world!');
      expect(messageFromMap.type, MessageType.text);
      expect(messageFromMap.timestamp.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(messageFromMap.isEdited, true);
      expect(messageFromMap.readStatus, {'user-123': true, 'user-456': false});
      expect(messageFromMap.mediaUrl, 'https://example.com/media');
      expect(messageFromMap.mediaName, 'file.txt');
      expect(messageFromMap.mediaSizeBytes, 1024);
      expect(messageFromMap.voiceDurationSeconds, 30);
      expect(messageFromMap.metadata, {'key': 'value'});
    });

    test('fromMap with null or missing values should set defaults', () {
      final map = <String, dynamic>{};
      final messageFromMap = MessageEntity.fromMap(map);

      expect(messageFromMap.id, '');
      expect(messageFromMap.chatId, '');
      expect(messageFromMap.senderId, '');
      expect(messageFromMap.text, null);
      expect(messageFromMap.type, MessageType.text);
      expect(messageFromMap.isEdited, false);
      expect(messageFromMap.readStatus, null);
      expect(messageFromMap.mediaUrl, null);
      expect(messageFromMap.mediaName, null);
      expect(messageFromMap.mediaSizeBytes, null);
      expect(messageFromMap.voiceDurationSeconds, null);
      expect(messageFromMap.metadata, null);
    });

    test('identical MessageEntity instances should be equal', () {
      final message1 = MessageEntity(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        text: 'Hello, world!',
        type: MessageType.text,
        timestamp: now,
        isEdited: false,
      );

      final message2 = MessageEntity(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        text: 'Hello, world!',
        type: MessageType.text,
        timestamp: now,
        isEdited: false,
      );

      expect(message1, equals(message2));
    });

    test('MessageEntity instances with different properties should not be equal', () {
      final message1 = MessageEntity(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        text: 'Hello, world!',
        type: MessageType.text,
        timestamp: now,
        isEdited: false,
      );

      final message2 = MessageEntity(
        id: 'msg-456',
        chatId: 'chat-789',
        senderId: 'user-123',
        text: 'Different text',
        type: MessageType.image,
        timestamp: now.add(const Duration(days: 1)),
        isEdited: true,
      );

      expect(message1, isNot(equals(message2)));
    });
  });
} 