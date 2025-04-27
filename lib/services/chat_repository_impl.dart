import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/models/message_entity.dart';
import 'package:monkey_messanger/services/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Uuid _uuid = const Uuid();

  ChatRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

  // Получение коллекций
  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection(AppConstants.chatsCollection);

  CollectionReference<Map<String, dynamic>> _messagesCollection(String chatId) =>
      _chatsCollection.doc(chatId).collection(AppConstants.messagesCollection);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

  // Получение документов
  DocumentReference<Map<String, dynamic>> _chatDoc(String chatId) =>
      _chatsCollection.doc(chatId);

  DocumentReference<Map<String, dynamic>> _messageDoc(String chatId, String messageId) =>
      _messagesCollection(chatId).doc(messageId);

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _usersCollection.doc(userId);

  @override
  Stream<List<ChatEntity>> getUserChats(String userId) {
    return _chatsCollection
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatEntity.fromMap({...doc.data(), 'id': doc.id}))
              .toList();
        });
  }

  @override
  Stream<List<MessageEntity>> getChatMessages(String chatId, {int limit = 50}) {
    return _messagesCollection(chatId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageEntity.fromMap({...doc.data(), 'id': doc.id}))
              .toList();
        });
  }

  @override
  Stream<ChatEntity?> getChatById(String chatId) {
    return _chatDoc(chatId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return ChatEntity.fromMap({...snapshot.data()!, 'id': snapshot.id});
      }
      return null;
    });
  }

  @override
  Future<ChatEntity> createPrivateChat(String currentUserId, String otherUserId) async {
    try {
      // Проверяем, существует ли уже чат между этими пользователями
      final existingChatId = await getExistingChatId(currentUserId, otherUserId);
      if (existingChatId != null) {
        final chatSnapshot = await _chatDoc(existingChatId).get();
        return ChatEntity.fromMap({...chatSnapshot.data()!, 'id': chatSnapshot.id});
      }
      
      // Получаем информацию о пользователях
      final currentUserSnapshot = await _userDoc(currentUserId).get();
      final otherUserSnapshot = await _userDoc(otherUserId).get();
      
      final currentUserData = currentUserSnapshot.data() ?? {};
      final otherUserData = otherUserSnapshot.data() ?? {};
      
      final currentUserName = currentUserData['name'] ?? 'User';
      final otherUserName = otherUserData['name'] ?? 'User';
      
      // Создаем новый чат
      final chatId = _uuid.v4();
      final now = DateTime.now();
      
      final chatData = {
        'name': '$currentUserName, $otherUserName',
        'imageUrl': null,
        'participantIds': [currentUserId, otherUserId],
        'lastMessageText': 'Начало беседы',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
        'isGroup': false,
        'unreadMessageCount': {
          currentUserId: 0,
          otherUserId: 0,
        },
        'createdAt': now.millisecondsSinceEpoch,
        'createdBy': currentUserId,
        'typing': {
          currentUserId: false,
          otherUserId: false,
        },
      };
      
      await _chatDoc(chatId).set(chatData);
      
      // Создаем системное сообщение о создании чата
      final messageId = _uuid.v4();
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': 'Начало беседы',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': {
          currentUserId: true,
          otherUserId: false,
        },
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      return ChatEntity.fromMap({...chatData, 'id': chatId});
    } catch (e, stackTrace) {
      AppLogger.error('Error creating private chat', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<ChatEntity> createGroupChat(String creatorId, String name, List<String> participantIds, {String? imageUrl}) async {
    try {
      // Убеждаемся, что создатель входит в список участников
      if (!participantIds.contains(creatorId)) {
        participantIds.add(creatorId);
      }
      
      // Создаем новый чат
      final chatId = _uuid.v4();
      final now = DateTime.now();
      
      // Инициализируем карту для непрочитанных сообщений и статусов печати
      final Map<String, int> unreadMessageCount = {};
      final Map<String, bool> typing = {};
      
      for (final userId in participantIds) {
        unreadMessageCount[userId] = 0;
        typing[userId] = false;
      }
      
      final chatData = {
        'name': name,
        'imageUrl': imageUrl,
        'participantIds': participantIds,
        'lastMessageText': 'Группа создана',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
        'isGroup': true,
        'unreadMessageCount': unreadMessageCount,
        'createdAt': now.millisecondsSinceEpoch,
        'createdBy': creatorId,
        'typing': typing,
      };
      
      await _chatDoc(chatId).set(chatData);
      
      // Создаем системное сообщение о создании группы
      final messageId = _uuid.v4();
      
      // Инициализируем статус прочтения
      final Map<String, bool> readStatus = {};
      for (final userId in participantIds) {
        readStatus[userId] = userId == creatorId;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': 'Группа создана',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      return ChatEntity.fromMap({...chatData, 'id': chatId});
    } catch (e, stackTrace) {
      AppLogger.error('Error creating group chat', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteChat(String chatId) async {
    try {
      // Получаем все сообщения чата
      final messagesSnapshot = await _messagesCollection(chatId).get();
      
      // Проверяем, есть ли медиа-файлы, которые нужно удалить из хранилища
      final messagesToDeleteFromStorage = messagesSnapshot.docs
          .map((doc) => MessageEntity.fromMap({...doc.data(), 'id': doc.id}))
          .where((message) => 
              message.type == MessageType.image || 
              message.type == MessageType.file || 
              message.type == MessageType.voice)
          .toList();
      
      // Удаляем файлы из хранилища
      for (final message in messagesToDeleteFromStorage) {
        if (message.mediaUrl != null) {
          try {
            final ref = _storage.refFromURL(message.mediaUrl!);
            await ref.delete();
          } catch (e) {
            AppLogger.warning('Could not delete file from storage: ${message.mediaUrl}', e);
            // Продолжаем, даже если не удалось удалить файл
          }
        }
      }
      
      // Удаляем все сообщения из коллекции
      final batch = _firestore.batch();
      
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Удаляем сам чат
      batch.delete(_chatDoc(chatId));
      
      // Выполняем все операции
      await batch.commit();
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting chat', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> leaveGroupChat(String chatId, String userId) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      // Проверяем, является ли чат групповым
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot leave a non-group chat');
      }
      
      // Получаем текущих участников
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      if (!participantIds.contains(userId)) {
        throw Exception('User is not a member of this chat');
      }
      
      // Удаляем пользователя из списка участников
      participantIds.remove(userId);
      
      // Если в группе не остается участников, удаляем ее
      if (participantIds.isEmpty) {
        await deleteChat(chatId);
        return;
      }
      
      // Обновляем карты для непрочитанных сообщений и статусов печати
      final Map<String, int> unreadMessageCount = Map<String, int>.from(chatData['unreadMessageCount'] ?? {});
      final Map<String, bool> typing = Map<String, bool>.from(chatData['typing'] ?? {});
      
      unreadMessageCount.remove(userId);
      typing.remove(userId);
      
      // Обновляем документ чата
      await _chatDoc(chatId).update({
        'participantIds': participantIds,
        'unreadMessageCount': unreadMessageCount,
        'typing': typing,
      });
      
      // Добавляем системное сообщение об уходе из группы
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Получаем имя пользователя
      final userSnapshot = await _userDoc(userId).get();
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      
      // Инициализируем статус прочтения для оставшихся участников
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = false;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': '$userName покинул(а) группу',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о последнем сообщении
      await _chatDoc(chatId).update({
        'lastMessageText': '$userName покинул(а) группу',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error leaving group chat', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> addUserToGroupChat(String chatId, String userId) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      // Проверяем, является ли чат групповым
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot add user to a non-group chat');
      }
      
      // Получаем текущих участников
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      if (participantIds.contains(userId)) {
        throw Exception('User is already a member of this chat');
      }
      
      // Добавляем пользователя в список участников
      participantIds.add(userId);
      
      // Обновляем карты для непрочитанных сообщений и статусов печати
      final Map<String, int> unreadMessageCount = Map<String, int>.from(chatData['unreadMessageCount'] ?? {});
      final Map<String, bool> typing = Map<String, bool>.from(chatData['typing'] ?? {});
      
      unreadMessageCount[userId] = 0;
      typing[userId] = false;
      
      // Обновляем документ чата
      await _chatDoc(chatId).update({
        'participantIds': participantIds,
        'unreadMessageCount': unreadMessageCount,
        'typing': typing,
      });
      
      // Добавляем системное сообщение о присоединении к группе
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Получаем имя пользователя
      final userSnapshot = await _userDoc(userId).get();
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      
      // Инициализируем статус прочтения
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = participantId == userId;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': '$userName присоединился(ась) к группе',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о последнем сообщении
      await _chatDoc(chatId).update({
        'lastMessageText': '$userName присоединился(ась) к группе',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error adding user to group chat', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeUserFromGroupChat(String chatId, String userId) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      // Проверяем, является ли чат групповым
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot remove user from a non-group chat');
      }
      
      // Получаем текущих участников
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      if (!participantIds.contains(userId)) {
        throw Exception('User is not a member of this chat');
      }
      
      // Проверяем, является ли пользователь создателем (админом) чата
      final String creatorId = chatData['createdBy'] ?? '';
      if (userId == creatorId) {
        throw Exception('Cannot remove the creator of the chat');
      }
      
      // Удаляем пользователя из списка участников
      participantIds.remove(userId);
      
      // Обновляем карты для непрочитанных сообщений и статусов печати
      final Map<String, int> unreadMessageCount = Map<String, int>.from(chatData['unreadMessageCount'] ?? {});
      final Map<String, bool> typing = Map<String, bool>.from(chatData['typing'] ?? {});
      
      unreadMessageCount.remove(userId);
      typing.remove(userId);
      
      // Обновляем документ чата
      await _chatDoc(chatId).update({
        'participantIds': participantIds,
        'unreadMessageCount': unreadMessageCount,
        'typing': typing,
      });
      
      // Добавляем системное сообщение об удалении из группы
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Получаем имена пользователей
      final userSnapshot = await _userDoc(userId).get();
      final adminSnapshot = await _userDoc(creatorId).get();
      
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      final adminName = adminSnapshot.data()?['name'] ?? 'Администратор';
      
      // Инициализируем статус прочтения для оставшихся участников
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = false;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': '$adminName удалил(а) $userName из группы',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о последнем сообщении
      await _chatDoc(chatId).update({
        'lastMessageText': '$adminName удалил(а) $userName из группы',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error removing user from group chat', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateGroupChatName(String chatId, String newName) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      // Проверяем, является ли чат групповым
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot update name of a non-group chat');
      }
      
      // Обновляем имя группы
      await _chatDoc(chatId).update({
        'name': newName,
      });
      
      // Добавляем системное сообщение об изменении имени группы
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Получаем список участников
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      // Инициализируем статус прочтения
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = false;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': 'Название группы изменено на "$newName"',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о последнем сообщении
      await _chatDoc(chatId).update({
        'lastMessageText': 'Название группы изменено на "$newName"',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error updating group chat name', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateGroupChatImage(String chatId, String imageUrl) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      // Проверяем, является ли чат групповым
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot update image of a non-group chat');
      }
      
      // Проверяем, нужно ли удалить предыдущее изображение
      final String? oldImageUrl = chatData['imageUrl'];
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(oldImageUrl);
          await ref.delete();
        } catch (e) {
          AppLogger.warning('Could not delete old image from storage: $oldImageUrl', e);
          // Продолжаем, даже если не удалось удалить файл
        }
      }
      
      // Обновляем изображение группы
      await _chatDoc(chatId).update({
        'imageUrl': imageUrl,
      });
      
      // Добавляем системное сообщение об изменении изображения группы
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Получаем список участников
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      // Инициализируем статус прочтения
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = false;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': 'Изображение группы обновлено',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о последнем сообщении
      await _chatDoc(chatId).update({
        'lastMessageText': 'Изображение группы обновлено',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error updating group chat image', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> markChatAsRead(String chatId, String userId) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      // Получаем текущее количество непрочитанных сообщений
      final Map<String, dynamic> unreadMessageCount = 
          Map<String, dynamic>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      // Обновляем количество непрочитанных сообщений
      unreadMessageCount[userId] = 0;
      
      // Обновляем документ чата
      await _chatDoc(chatId).update({
        'unreadMessageCount': unreadMessageCount,
      });
      
      // Получаем все непрочитанные сообщения для данного пользователя
      final unreadMessagesSnapshot = await _messagesCollection(chatId)
          .where('readStatus.$userId', isEqualTo: false)
          .get();
      
      // Если нет непрочитанных сообщений, выходим
      if (unreadMessagesSnapshot.docs.isEmpty) {
        return;
      }
      
      // Обновляем статус прочтения для всех непрочитанных сообщений
      final batch = _firestore.batch();
      
      for (final doc in unreadMessagesSnapshot.docs) {
        // Получаем текущий статус прочтения
        final Map<String, dynamic> readStatus = 
            Map<String, dynamic>.from(doc.data()['readStatus'] ?? {});
        
        // Обновляем статус прочтения для данного пользователя
        readStatus[userId] = true;
        
        // Добавляем обновление в batch
        batch.update(doc.reference, {
          'readStatus': readStatus,
        });
      }
      
      // Выполняем все обновления
      await batch.commit();
    } catch (e, stackTrace) {
      AppLogger.error('Error marking chat as read', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      // Получаем текущий статус печати
      final Map<String, dynamic> typing = 
          Map<String, dynamic>.from(chatSnapshot.data()?['typing'] ?? {});
      
      // Обновляем статус печати
      typing[userId] = isTyping;
      
      // Обновляем документ чата
      await _chatDoc(chatId).update({
        'typing': typing,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error updating typing status', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<MessageEntity> sendTextMessage(String chatId, String senderId, String text) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      // Получаем список участников чата
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      // Создаем новое сообщение
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Инициализируем статус прочтения для всех участников
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = participantId == senderId;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': senderId,
        'text': text,
        'type': MessageType.text.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о непрочитанных сообщениях
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
      // Обновляем информацию о последнем сообщении в чате
      await _chatDoc(chatId).update({
        'lastMessageText': text,
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': senderId,
        'unreadMessageCount': unreadMessageCount,
      });
      
      return MessageEntity.fromMap({...messageData, 'id': messageId});
    } catch (e, stackTrace) {
      AppLogger.error('Error sending text message', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<MessageEntity> sendImageMessage(String chatId, String senderId, File imageFile, {String? caption}) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      // Получаем список участников чата
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      // Загружаем изображение в хранилище
      final storageRef = _storage.ref().child('chat_images/${_uuid.v4()}_${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Создаем новое сообщение
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Инициализируем статус прочтения для всех участников
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = participantId == senderId;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': senderId,
        'text': caption ?? '',
        'type': MessageType.image.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
        'mediaUrl': downloadUrl,
        'mediaName': 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'mediaSizeBytes': await imageFile.length(),
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о непрочитанных сообщениях
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
      // Обновляем информацию о последнем сообщении в чате
      await _chatDoc(chatId).update({
        'lastMessageText': caption?.isNotEmpty == true ? 'Фото: $caption' : 'Фото',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': senderId,
        'unreadMessageCount': unreadMessageCount,
      });
      
      return MessageEntity.fromMap({...messageData, 'id': messageId});
    } catch (e, stackTrace) {
      AppLogger.error('Error sending image message', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<MessageEntity> sendFileMessage(String chatId, String senderId, File file, {String? caption}) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      // Получаем список участников чата
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      // Загружаем файл в хранилище
      final fileName = file.path.split('/').last;
      final storageRef = _storage.ref().child('chat_files/${_uuid.v4()}_$fileName');
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Создаем новое сообщение
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Инициализируем статус прочтения для всех участников
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = participantId == senderId;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': senderId,
        'text': caption ?? '',
        'type': MessageType.file.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
        'mediaUrl': downloadUrl,
        'mediaName': fileName,
        'mediaSizeBytes': await file.length(),
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о непрочитанных сообщениях
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
      // Обновляем информацию о последнем сообщении в чате
      await _chatDoc(chatId).update({
        'lastMessageText': 'Файл: $fileName',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': senderId,
        'unreadMessageCount': unreadMessageCount,
      });
      
      return MessageEntity.fromMap({...messageData, 'id': messageId});
    } catch (e, stackTrace) {
      AppLogger.error('Error sending file message', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<MessageEntity> sendVoiceMessage(String chatId, String senderId, File audioFile, int durationSeconds) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      // Получаем список участников чата
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      // Загружаем аудиофайл в хранилище
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = _storage.ref().child('chat_voice/${_uuid.v4()}_$fileName');
      final uploadTask = await storageRef.putFile(audioFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Создаем новое сообщение
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      // Инициализируем статус прочтения для всех участников
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = participantId == senderId;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': senderId,
        'text': '',
        'type': MessageType.voice.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
        'mediaUrl': downloadUrl,
        'mediaName': fileName,
        'mediaSizeBytes': await audioFile.length(),
        'voiceDurationSeconds': durationSeconds,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      // Обновляем информацию о непрочитанных сообщениях
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
      // Форматируем длительность голосового сообщения
      final int minutes = durationSeconds ~/ 60;
      final int seconds = durationSeconds % 60;
      final String duration = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      // Обновляем информацию о последнем сообщении в чате
      await _chatDoc(chatId).update({
        'lastMessageText': 'Голосовое сообщение ($duration)',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': senderId,
        'unreadMessageCount': unreadMessageCount,
      });
      
      return MessageEntity.fromMap({...messageData, 'id': messageId});
    } catch (e, stackTrace) {
      AppLogger.error('Error sending voice message', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final messageSnapshot = await _messageDoc(chatId, messageId).get();
      
      if (!messageSnapshot.exists) {
        throw Exception('Message does not exist');
      }
      
      final messageData = messageSnapshot.data()!;
      final messageType = MessageType.values[messageData['type'] ?? 0];
      
      // Если сообщение содержит медиафайл, удаляем его из хранилища
      if (messageType == MessageType.image || 
          messageType == MessageType.file || 
          messageType == MessageType.voice) {
        final String? mediaUrl = messageData['mediaUrl'];
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          try {
            final ref = _storage.refFromURL(mediaUrl);
            await ref.delete();
          } catch (e) {
            AppLogger.warning('Could not delete media from storage: $mediaUrl', e);
            // Продолжаем, даже если не удалось удалить файл
          }
        }
      }
      
      // Удаляем сообщение
      await _messageDoc(chatId, messageId).delete();
      
      // Проверяем, было ли это последнее сообщение в чате
      final chatSnapshot = await _chatDoc(chatId).get();
      final chatData = chatSnapshot.data()!;
      
      final lastMessageTimestamp = chatData['lastMessageTime'] ?? 0;
      final messageTimestamp = messageData['timestamp'] ?? 0;
      
      if (lastMessageTimestamp == messageTimestamp) {
        // Находим новое последнее сообщение
        final messagesSnapshot = await _messagesCollection(chatId)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        
        if (messagesSnapshot.docs.isNotEmpty) {
          final lastMessage = messagesSnapshot.docs.first.data();
          final lastMessageSenderId = lastMessage['senderId'];
          final lastMessageText = lastMessage['text'] ?? '';
          final lastMessageType = MessageType.values[lastMessage['type'] ?? 0];
          
          String displayText = lastMessageText;
          
          // Формируем текст для отображения в зависимости от типа сообщения
          if (lastMessageType == MessageType.image) {
            displayText = lastMessageText.isNotEmpty ? 'Фото: $lastMessageText' : 'Фото';
          } else if (lastMessageType == MessageType.file) {
            final fileName = lastMessage['mediaName'] ?? 'файл';
            displayText = 'Файл: $fileName';
          } else if (lastMessageType == MessageType.voice) {
            final durationSeconds = lastMessage['voiceDurationSeconds'] ?? 0;
            final int minutes = durationSeconds ~/ 60;
            final int seconds = durationSeconds % 60;
            final String duration = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
            displayText = 'Голосовое сообщение ($duration)';
          }
          
          // Обновляем информацию о последнем сообщении
          await _chatDoc(chatId).update({
            'lastMessageText': displayText,
            'lastMessageTime': lastMessage['timestamp'],
            'lastMessageSenderId': lastMessageSenderId,
          });
        } else {
          // Если нет сообщений, обновляем информацию о последнем сообщении
          await _chatDoc(chatId).update({
            'lastMessageText': 'Нет сообщений',
            'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
            'lastMessageSenderId': null,
          });
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting message', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> editTextMessage(String chatId, String messageId, String newText) async {
    try {
      final messageSnapshot = await _messageDoc(chatId, messageId).get();
      
      if (!messageSnapshot.exists) {
        throw Exception('Message does not exist');
      }
      
      final messageData = messageSnapshot.data()!;
      final messageType = MessageType.values[messageData['type'] ?? 0];
      
      // Проверяем, что это текстовое сообщение
      if (messageType != MessageType.text) {
        throw Exception('Only text messages can be edited');
      }
      
      // Обновляем текст сообщения
      await _messageDoc(chatId, messageId).update({
        'text': newText,
        'isEdited': true,
      });
      
      // Проверяем, было ли это последнее сообщение в чате
      final chatSnapshot = await _chatDoc(chatId).get();
      final chatData = chatSnapshot.data()!;
      
      final lastMessageTimestamp = chatData['lastMessageTime'] ?? 0;
      final messageTimestamp = messageData['timestamp'] ?? 0;
      
      if (lastMessageTimestamp == messageTimestamp) {
        // Обновляем информацию о последнем сообщении
        await _chatDoc(chatId).update({
          'lastMessageText': newText,
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error editing text message', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> markMessageAsRead(String chatId, String messageId, String userId) async {
    try {
      final messageSnapshot = await _messageDoc(chatId, messageId).get();
      
      if (!messageSnapshot.exists) {
        throw Exception('Message does not exist');
      }
      
      // Получаем текущий статус прочтения
      final Map<String, dynamic> readStatus = 
          Map<String, dynamic>.from(messageSnapshot.data()?['readStatus'] ?? {});
      
      // Если сообщение уже прочитано, выходим
      if (readStatus[userId] == true) {
        return;
      }
      
      // Обновляем статус прочтения
      readStatus[userId] = true;
      
      // Обновляем сообщение
      await _messageDoc(chatId, messageId).update({
        'readStatus': readStatus,
      });
      
      // Обновляем количество непрочитанных сообщений в чате
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      // Получаем текущее количество непрочитанных сообщений
      final Map<String, dynamic> unreadMessageCount = 
          Map<String, dynamic>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      // Уменьшаем количество непрочитанных сообщений
      final int currentUnreadCount = unreadMessageCount[userId] ?? 0;
      if (currentUnreadCount > 0) {
        unreadMessageCount[userId] = currentUnreadCount - 1;
        
        // Обновляем документ чата
        await _chatDoc(chatId).update({
          'unreadMessageCount': unreadMessageCount,
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error marking message as read', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<UserEntity>> searchUsers(String query, {int limit = 10}) async {
    try {
      // Поиск пользователей по имени (case-insensitive)
      final result = await _usersCollection
          .orderBy('name')
          .startAt([query])
          .endAt([query + '\uf8ff'])
          .limit(limit)
          .get();
      
      return result.docs
          .map((doc) => UserEntity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error searching users', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<UserEntity>> getRecentContacts(String userId, {int limit = 10}) async {
    try {
      // Получаем чаты пользователя
      final chatsSnapshot = await _chatsCollection
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .limit(limit)
          .get();
      
      final Set<String> contactIds = {};
      final List<UserEntity> contacts = [];
      
      // Получаем участников чатов
      for (final doc in chatsSnapshot.docs) {
        final chatData = doc.data();
        final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
        
        for (final participantId in participantIds) {
          if (participantId != userId && !contactIds.contains(participantId)) {
            contactIds.add(participantId);
            
            // Получаем данные пользователя
            final userSnapshot = await _userDoc(participantId).get();
            if (userSnapshot.exists) {
              contacts.add(UserEntity.fromMap({...userSnapshot.data()!, 'id': userSnapshot.id}));
            }
            
            // Ограничиваем количество контактов
            if (contacts.length >= limit) {
              break;
            }
          }
        }
        
        if (contacts.length >= limit) {
          break;
        }
      }
      
      return contacts;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting recent contacts', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getChatUserData(String userId) async {
    try {
      final userSnapshot = await _userDoc(userId).get();
      
      if (!userSnapshot.exists) {
        return null;
      }
      
      return UserEntity.fromMap({...userSnapshot.data()!, 'id': userSnapshot.id});
    } catch (e, stackTrace) {
      AppLogger.error('Error getting chat user data', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> chatExists(String userId1, String userId2) async {
    final existingChatId = await getExistingChatId(userId1, userId2);
    return existingChatId != null;
  }

  @override
  Future<String?> getExistingChatId(String userId1, String userId2) async {
    try {
      // Ищем чат, в котором участвуют оба пользователя
      final chatsSnapshot = await _chatsCollection
          .where('participantIds', arrayContains: userId1)
          .where('isGroup', isEqualTo: false)
          .get();
      
      for (final doc in chatsSnapshot.docs) {
        final participantIds = List<String>.from(doc.data()['participantIds'] ?? []);
        if (participantIds.contains(userId2)) {
          return doc.id;
        }
      }
      
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error checking if chat exists', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, UserEntity>> getChatUsersData(List<String> userIds) async {
    try {
      final Map<String, UserEntity> usersData = {};
      
      for (final userId in userIds) {
        final userSnapshot = await _userDoc(userId).get();
        if (userSnapshot.exists) {
          usersData[userId] = UserEntity.fromMap({...userSnapshot.data()!, 'id': userId});
        }
      }
      
      return usersData;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting chat users data', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isChatExists(String currentUserId, String otherUserId) async {
    return await chatExists(currentUserId, otherUserId);
  }
} 