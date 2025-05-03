import 'package:flutter_test/flutter_test.dart';
import 'package:monkey_messanger/models/chat_entity.dart';

void main() {
  group('ChatEntity', () {
    final DateTime now = DateTime.now();
    final testChat = ChatEntity(
      id: 'chat-123',
      name: 'Test Chat',
      imageUrl: 'https://example.com/chat.jpg',
      participantIds: ['user-1', 'user-2', 'user-3'],
      lastMessageText: 'Last message',
      lastMessageTime: now,
      lastMessageSenderId: 'user-2',
      isGroup: true,
      unreadMessageCount: {'user-1': 0, 'user-2': 3, 'user-3': 5},
      createdAt: now.subtract(const Duration(days: 7)),
      createdBy: 'user-1',
      typing: {'user-2': true, 'user-3': false},
      adminIds: ['user-1', 'user-3'],
    );

    test('should create ChatEntity instance correctly', () {
      expect(testChat.id, 'chat-123');
      expect(testChat.name, 'Test Chat');
      expect(testChat.imageUrl, 'https://example.com/chat.jpg');
      expect(testChat.participantIds, ['user-1', 'user-2', 'user-3']);
      expect(testChat.lastMessageText, 'Last message');
      expect(testChat.lastMessageTime, now);
      expect(testChat.lastMessageSenderId, 'user-2');
      expect(testChat.isGroup, true);
      expect(testChat.unreadMessageCount, {'user-1': 0, 'user-2': 3, 'user-3': 5});
      expect(testChat.createdAt, now.subtract(const Duration(days: 7)));
      expect(testChat.createdBy, 'user-1');
      expect(testChat.typing, {'user-2': true, 'user-3': false});
      expect(testChat.adminIds, ['user-1', 'user-3']);
    });

    test('copyWith should return a new instance with updated values', () {
      final updatedChat = testChat.copyWith(
        name: 'Updated Chat',
        imageUrl: 'https://example.com/updated.jpg',
        lastMessageText: 'New message',
        unreadMessageCount: {'user-1': 1, 'user-2': 0, 'user-3': 2},
      );

      // Проверяем обновленные поля
      expect(updatedChat.name, 'Updated Chat');
      expect(updatedChat.imageUrl, 'https://example.com/updated.jpg');
      expect(updatedChat.lastMessageText, 'New message');
      expect(updatedChat.unreadMessageCount, {'user-1': 1, 'user-2': 0, 'user-3': 2});

      // Проверяем, что остальные поля не изменились
      expect(updatedChat.id, testChat.id);
      expect(updatedChat.participantIds, testChat.participantIds);
      expect(updatedChat.lastMessageTime, testChat.lastMessageTime);
      expect(updatedChat.lastMessageSenderId, testChat.lastMessageSenderId);
      expect(updatedChat.isGroup, testChat.isGroup);
      expect(updatedChat.createdAt, testChat.createdAt);
      expect(updatedChat.createdBy, testChat.createdBy);
      expect(updatedChat.typing, testChat.typing);
      expect(updatedChat.adminIds, testChat.adminIds);
    });

    test('toMap should convert ChatEntity to Map correctly', () {
      final map = testChat.toMap();

      expect(map['id'], testChat.id);
      expect(map['name'], testChat.name);
      expect(map['imageUrl'], testChat.imageUrl);
      expect(map['participantIds'], testChat.participantIds);
      expect(map['lastMessageText'], testChat.lastMessageText);
      expect(map['lastMessageTime'], testChat.lastMessageTime.millisecondsSinceEpoch);
      expect(map['lastMessageSenderId'], testChat.lastMessageSenderId);
      expect(map['isGroup'], testChat.isGroup);
      expect(map['unreadMessageCount'], testChat.unreadMessageCount);
      expect(map['createdAt'], testChat.createdAt.millisecondsSinceEpoch);
      expect(map['createdBy'], testChat.createdBy);
      expect(map['typing'], testChat.typing);
      expect(map['adminIds'], testChat.adminIds);
    });

    test('fromMap should create ChatEntity from Map correctly', () {
      final map = {
        'id': 'chat-123',
        'name': 'Test Chat',
        'imageUrl': 'https://example.com/chat.jpg',
        'participantIds': ['user-1', 'user-2', 'user-3'],
        'lastMessageText': 'Last message',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': 'user-2',
        'isGroup': true,
        'unreadMessageCount': {'user-1': 0, 'user-2': 3, 'user-3': 5},
        'createdAt': now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        'createdBy': 'user-1',
        'typing': {'user-2': true, 'user-3': false},
        'adminIds': ['user-1', 'user-3'],
      };

      final chatFromMap = ChatEntity.fromMap(map);

      expect(chatFromMap.id, 'chat-123');
      expect(chatFromMap.name, 'Test Chat');
      expect(chatFromMap.imageUrl, 'https://example.com/chat.jpg');
      expect(chatFromMap.participantIds, ['user-1', 'user-2', 'user-3']);
      expect(chatFromMap.lastMessageText, 'Last message');
      expect(chatFromMap.lastMessageTime.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(chatFromMap.lastMessageSenderId, 'user-2');
      expect(chatFromMap.isGroup, true);
      expect(chatFromMap.unreadMessageCount, {'user-1': 0, 'user-2': 3, 'user-3': 5});
      expect(chatFromMap.createdAt.millisecondsSinceEpoch,
          now.subtract(const Duration(days: 7)).millisecondsSinceEpoch);
      expect(chatFromMap.createdBy, 'user-1');
      expect(chatFromMap.typing, {'user-2': true, 'user-3': false});
      expect(chatFromMap.adminIds, ['user-1', 'user-3']);
    });

    test('fromMap with minimal values should set defaults', () {
      final map = {
        'id': 'chat-123',
        'name': 'Test Chat',
        'participantIds': ['user-1', 'user-2'],
        'lastMessageText': '',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'isGroup': false,
        'unreadMessageCount': {},
        'createdAt': now.millisecondsSinceEpoch,
      };

      final chatFromMap = ChatEntity.fromMap(map);

      expect(chatFromMap.id, 'chat-123');
      expect(chatFromMap.name, 'Test Chat');
      expect(chatFromMap.imageUrl, null);
      expect(chatFromMap.participantIds, ['user-1', 'user-2']);
      expect(chatFromMap.lastMessageText, '');
      expect(chatFromMap.lastMessageSenderId, null);
      expect(chatFromMap.isGroup, false);
      expect(chatFromMap.unreadMessageCount, {});
      expect(chatFromMap.createdBy, null);
      expect(chatFromMap.typing, null);
      expect(chatFromMap.adminIds, null);
    });

    test('isAdmin should correctly identify admin users', () {
      expect(testChat.isAdmin('user-1'), true);
      expect(testChat.isAdmin('user-3'), true);
      expect(testChat.isAdmin('user-2'), false);
      expect(testChat.isAdmin('non-existent-user'), false);
    });

    test('getDisplayName should return chat name for group chats', () {
      final userNames = {
        'user-1': 'User One',
        'user-2': 'User Two',
        'user-3': 'User Three',
      };

      // Для групповых чатов просто возвращаем имя чата
      expect(testChat.getDisplayName('user-1', userNames), 'Test Chat');
    });

    test('getDisplayName should return other user name for private chats', () {
      final privateChat = ChatEntity(
        id: 'private-chat',
        name: 'Private Chat',
        participantIds: ['user-1', 'user-2'],
        lastMessageText: 'Hello',
        lastMessageTime: now,
        isGroup: false,
        unreadMessageCount: {},
        createdAt: now,
      );

      final userNames = {
        'user-1': 'User One',
        'user-2': 'User Two',
      };

      // Для приватных чатов возвращаем имя другого пользователя
      expect(privateChat.getDisplayName('user-1', userNames), 'User Two');
      expect(privateChat.getDisplayName('user-2', userNames), 'User One');
    });

    test('getDisplayImage should return chat image for group chats', () {
      final userImages = {
        'user-1': 'https://example.com/user1.jpg',
        'user-2': 'https://example.com/user2.jpg',
        'user-3': 'https://example.com/user3.jpg',
      };

      // Для групповых чатов возвращаем изображение чата
      expect(testChat.getDisplayImage('user-1', userImages), 'https://example.com/chat.jpg');
    });

    test('getDisplayImage should return other user image for private chats', () {
      final privateChat = ChatEntity(
        id: 'private-chat',
        name: 'Private Chat',
        participantIds: ['user-1', 'user-2'],
        lastMessageText: 'Hello',
        lastMessageTime: now,
        isGroup: false,
        unreadMessageCount: {},
        createdAt: now,
      );

      final userImages = {
        'user-1': 'https://example.com/user1.jpg',
        'user-2': 'https://example.com/user2.jpg',
      };

      // Для приватных чатов возвращаем изображение другого пользователя
      expect(privateChat.getDisplayImage('user-1', userImages), 'https://example.com/user2.jpg');
      expect(privateChat.getDisplayImage('user-2', userImages), 'https://example.com/user1.jpg');
    });

    test('hasUnreadMessages should correctly identify unread messages', () {
      expect(testChat.hasUnreadMessages('user-1'), false);
      expect(testChat.hasUnreadMessages('user-2'), true);
      expect(testChat.hasUnreadMessages('user-3'), true);
      expect(testChat.hasUnreadMessages('non-existent-user'), false);
    });

    test('getUnreadCount should return correct unread count', () {
      expect(testChat.getUnreadCount('user-1'), 0);
      expect(testChat.getUnreadCount('user-2'), 3);
      expect(testChat.getUnreadCount('user-3'), 5);
      expect(testChat.getUnreadCount('non-existent-user'), 0);
    });

    test('isSomeoneTyping should return true if at least one user is typing', () {
      expect(testChat.isSomeoneTyping(), true);

      final noOneTypingChat = testChat.copyWith(
        typing: {'user-1': false, 'user-2': false, 'user-3': false},
      );
      expect(noOneTypingChat.isSomeoneTyping(), false);

      final nullTypingChat = testChat.copyWith(typing: null);
      expect(nullTypingChat.isSomeoneTyping(), false);
    });

    test('getTypingUsers should return list of typing users', () {
      expect(testChat.getTypingUsers(), ['user-2']);

      final multipleTypingChat = testChat.copyWith(
        typing: {'user-1': true, 'user-2': true, 'user-3': false},
      );
      expect(multipleTypingChat.getTypingUsers(), ['user-1', 'user-2']);

      final noOneTypingChat = testChat.copyWith(
        typing: {'user-1': false, 'user-2': false, 'user-3': false},
      );
      expect(noOneTypingChat.getTypingUsers(), []);

      final nullTypingChat = testChat.copyWith(typing: null);
      expect(nullTypingChat.getTypingUsers(), []);
    });

    test('identical ChatEntity instances should be equal', () {
      final chat1 = ChatEntity(
        id: 'chat-123',
        name: 'Test Chat',
        imageUrl: 'https://example.com/chat.jpg',
        participantIds: ['user-1', 'user-2', 'user-3'],
        lastMessageText: 'Last message',
        lastMessageTime: now,
        lastMessageSenderId: 'user-2',
        isGroup: true,
        unreadMessageCount: {'user-1': 0, 'user-2': 3, 'user-3': 5},
        createdAt: now.subtract(const Duration(days: 7)),
        createdBy: 'user-1',
        typing: {'user-2': true, 'user-3': false},
        adminIds: ['user-1', 'user-3'],
      );

      final chat2 = ChatEntity(
        id: 'chat-123',
        name: 'Test Chat',
        imageUrl: 'https://example.com/chat.jpg',
        participantIds: ['user-1', 'user-2', 'user-3'],
        lastMessageText: 'Last message',
        lastMessageTime: now,
        lastMessageSenderId: 'user-2',
        isGroup: true,
        unreadMessageCount: {'user-1': 0, 'user-2': 3, 'user-3': 5},
        createdAt: now.subtract(const Duration(days: 7)),
        createdBy: 'user-1',
        typing: {'user-2': true, 'user-3': false},
        adminIds: ['user-1', 'user-3'],
      );

      expect(chat1, equals(chat2));
    });

    test('ChatEntity instances with different properties should not be equal', () {
      final chat1 = testChat;
      final chat2 = testChat.copyWith(
        id: 'chat-456',
        name: 'Different Chat',
        participantIds: ['user-1', 'user-4'],
      );

      expect(chat1, isNot(equals(chat2)));
    });
  });
} 