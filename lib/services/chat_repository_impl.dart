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

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection(AppConstants.chatsCollection);

  CollectionReference<Map<String, dynamic>> _messagesCollection(String chatId) =>
      _chatsCollection.doc(chatId).collection(AppConstants.messagesCollection);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

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
      if (!snapshot.exists) {
        return null;
      }
      return ChatEntity.fromMap({...snapshot.data()!, 'id': snapshot.id});
    });
  }

  @override
  Future<ChatEntity> createPrivateChat(String currentUserId, String otherUserId) async {
    try {
      final existingChatId = await getExistingChatId(currentUserId, otherUserId);
      if (existingChatId != null) {
        final chatSnapshot = await _chatDoc(existingChatId).get();
        return ChatEntity.fromMap({...chatSnapshot.data()!, 'id': chatSnapshot.id});
      }
      
      final currentUserSnapshot = await _userDoc(currentUserId).get();
      final otherUserSnapshot = await _userDoc(otherUserId).get();
      
      final currentUserData = currentUserSnapshot.data() ?? {};
      final otherUserData = otherUserSnapshot.data() ?? {};
      
      final currentUserName = currentUserData['name'] ?? 'User';
      final otherUserName = otherUserData['name'] ?? 'User';
      
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
      if (!participantIds.contains(creatorId)) {
        participantIds.add(creatorId);
      }
      
      final chatId = _uuid.v4();
      final now = DateTime.now();
      
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
        'lastMessageType': MessageType.system.index,
        'isGroup': true,
        'unreadMessageCount': unreadMessageCount,
        'createdAt': now.millisecondsSinceEpoch,
        'createdBy': creatorId,
        'typing': typing,
        'adminIds': [creatorId], 
      };
      
      await _chatDoc(chatId).set(chatData);
      
      final messageId = _uuid.v4();
      
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
      final messagesSnapshot = await _messagesCollection(chatId).get();
      
      final messagesToDeleteFromStorage = messagesSnapshot.docs
          .map((doc) => MessageEntity.fromMap({...doc.data(), 'id': doc.id}))
          .where((message) => 
              message.type == MessageType.image || 
              message.type == MessageType.file || 
              message.type == MessageType.voice)
          .toList();
      
      for (final message in messagesToDeleteFromStorage) {
        if (message.mediaUrl != null) {
          try {
            final ref = _storage.refFromURL(message.mediaUrl!);
            await ref.delete();
          } catch (e) {
            AppLogger.warning('Could not delete file from storage: ${message.mediaUrl}', e);
          }
        }
      }
      
      final batch = _firestore.batch();
      
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      batch.delete(_chatDoc(chatId));
      
      await batch.commit();
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting chat', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteOrLeaveChat(String chatId, String userId) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      final bool isGroup = chatData['isGroup'] ?? false;
      
      if (!isGroup) {
        await deleteChat(chatId);
        return;
      }
      
      final List<String> adminIds = List<String>.from(chatData['adminIds'] ?? []);
      final String creatorId = chatData['createdBy'] ?? '';
      
      if (userId == creatorId || adminIds.contains(userId)) {
        await deleteChat(chatId);
      } else {
        await leaveGroupChat(chatId, userId);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting or leaving chat', e, stackTrace);
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
      
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot leave a non-group chat');
      }
      
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      if (!participantIds.contains(userId)) {
        throw Exception('User is not a member of this chat');
      }
      
      participantIds.remove(userId);
      
      if (participantIds.isEmpty) {
        await deleteChat(chatId);
        return;
      }
      
      final Map<String, int> unreadMessageCount = Map<String, int>.from(chatData['unreadMessageCount'] ?? {});
      final Map<String, bool> typing = Map<String, bool>.from(chatData['typing'] ?? {});
      
      unreadMessageCount.remove(userId);
      typing.remove(userId);
      
      await _chatDoc(chatId).update({
        'participantIds': participantIds,
        'unreadMessageCount': unreadMessageCount,
        'typing': typing,
      });
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      final userSnapshot = await _userDoc(userId).get();
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      
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
      
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot add user to a non-group chat');
      }
      
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      if (participantIds.contains(userId)) {
        throw Exception('User is already a member of this chat');
      }
      
      participantIds.add(userId);
      
      final Map<String, int> unreadMessageCount = Map<String, int>.from(chatData['unreadMessageCount'] ?? {});
      final Map<String, bool> typing = Map<String, bool>.from(chatData['typing'] ?? {});
      
      unreadMessageCount[userId] = 0;
      typing[userId] = false;
      
      await _chatDoc(chatId).update({
        'participantIds': participantIds,
        'unreadMessageCount': unreadMessageCount,
        'typing': typing,
      });
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      final userSnapshot = await _userDoc(userId).get();
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      
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
      
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot remove user from a non-group chat');
      }
      
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      if (!participantIds.contains(userId)) {
        throw Exception('User is not a member of this chat');
      }
      
      final String creatorId = chatData['createdBy'] ?? '';
      if (userId == creatorId) {
        throw Exception('Cannot remove the creator of the chat');
      }
      
      participantIds.remove(userId);
      
      final Map<String, int> unreadMessageCount = Map<String, int>.from(chatData['unreadMessageCount'] ?? {});
      final Map<String, bool> typing = Map<String, bool>.from(chatData['typing'] ?? {});
      
      unreadMessageCount.remove(userId);
      typing.remove(userId);
      
      await _chatDoc(chatId).update({
        'participantIds': participantIds,
        'unreadMessageCount': unreadMessageCount,
        'typing': typing,
      });
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      final userSnapshot = await _userDoc(userId).get();
      final adminSnapshot = await _userDoc(creatorId).get();
      
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      final adminName = adminSnapshot.data()?['name'] ?? 'Администратор';
      
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
      
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot update name of a non-group chat');
      }
      
      await _chatDoc(chatId).update({
        'name': newName,
      });
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
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
      
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot update image of a non-group chat');
      }
      
      final String? oldImageUrl = chatData['imageUrl'];
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(oldImageUrl);
          await ref.delete();
        } catch (e) {
          AppLogger.warning('Could not delete old image from storage: $oldImageUrl', e);
        }
      }
      
      await _chatDoc(chatId).update({
        'imageUrl': imageUrl,
      });
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
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
      
      final Map<String, dynamic> unreadMessageCount = 
          Map<String, dynamic>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      unreadMessageCount[userId] = 0;
      
      await _chatDoc(chatId).update({
        'unreadMessageCount': unreadMessageCount,
      });
      
      final unreadMessagesSnapshot = await _messagesCollection(chatId)
          .where('readStatus.$userId', isEqualTo: false)
          .get();
      
      if (unreadMessagesSnapshot.docs.isEmpty) {
        return;
      }
      
      final batch = _firestore.batch();
      
      for (final doc in unreadMessagesSnapshot.docs) {
        final Map<String, dynamic> readStatus = 
            Map<String, dynamic>.from(doc.data()['readStatus'] ?? {});
        
        readStatus[userId] = true;
        
        batch.update(doc.reference, {
          'readStatus': readStatus,
        });
      }
      
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
      
      final Map<String, dynamic> typing = 
          Map<String, dynamic>.from(chatSnapshot.data()?['typing'] ?? {});
      
      typing[userId] = isTyping;
      
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
      
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
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
      
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
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
      
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      final storageRef = _storage.ref().child('chat_images/${_uuid.v4()}_${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
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
      
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
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
      
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      final fileName = file.path.split('/').last;
      final storageRef = _storage.ref().child('chat_files/${_uuid.v4()}_$fileName');
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
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
      
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
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
      
      final List<String> participantIds = List<String>.from(chatSnapshot.data()?['participantIds'] ?? []);
      
      if (!participantIds.contains(senderId)) {
        throw Exception('User is not a member of this chat');
      }
      
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = _storage.ref().child('chat_voice/${_uuid.v4()}_$fileName');
      final uploadTask = await storageRef.putFile(audioFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
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
      
      final Map<String, int> unreadMessageCount = 
          Map<String, int>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      for (final participantId in participantIds) {
        if (participantId != senderId) {
          unreadMessageCount[participantId] = (unreadMessageCount[participantId] ?? 0) + 1;
        }
      }
      
      final int minutes = durationSeconds ~/ 60;
      final int seconds = durationSeconds % 60;
      final String duration = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
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
          }
        }
      }
      
      await _messageDoc(chatId, messageId).delete();
      
      final chatSnapshot = await _chatDoc(chatId).get();
      final chatData = chatSnapshot.data()!;
      
      final lastMessageTimestamp = chatData['lastMessageTime'] ?? 0;
      final messageTimestamp = messageData['timestamp'] ?? 0;
      
      if (lastMessageTimestamp == messageTimestamp) {
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
          
          await _chatDoc(chatId).update({
            'lastMessageText': displayText,
            'lastMessageTime': lastMessage['timestamp'],
            'lastMessageSenderId': lastMessageSenderId,
          });
        } else {
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
      
      if (messageType != MessageType.text) {
        throw Exception('Only text messages can be edited');
      }
      
      await _messageDoc(chatId, messageId).update({
        'text': newText,
        'isEdited': true,
      });
      
      final chatSnapshot = await _chatDoc(chatId).get();
      final chatData = chatSnapshot.data()!;
      
      final lastMessageTimestamp = chatData['lastMessageTime'] ?? 0;
      final messageTimestamp = messageData['timestamp'] ?? 0;
      
      if (lastMessageTimestamp == messageTimestamp) {
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
      
      final Map<String, dynamic> readStatus = 
          Map<String, dynamic>.from(messageSnapshot.data()?['readStatus'] ?? {});
      
      if (readStatus[userId] == true) {
        return;
      }
      
      readStatus[userId] = true;
      
      await _messageDoc(chatId, messageId).update({
        'readStatus': readStatus,
      });
      
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final Map<String, dynamic> unreadMessageCount = 
          Map<String, dynamic>.from(chatSnapshot.data()?['unreadMessageCount'] ?? {});
      
      final int currentUnreadCount = unreadMessageCount[userId] ?? 0;
      if (currentUnreadCount > 0) {
        unreadMessageCount[userId] = currentUnreadCount - 1;
        
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
      final chatsSnapshot = await _chatsCollection
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .limit(limit)
          .get();
      
      final Set<String> contactIds = {};
      final List<UserEntity> contacts = [];
      
      for (final doc in chatsSnapshot.docs) {
        final chatData = doc.data();
        final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
        
        for (final participantId in participantIds) {
          if (participantId != userId && !contactIds.contains(participantId)) {
            contactIds.add(participantId);
            
            final userSnapshot = await _userDoc(participantId).get();
            if (userSnapshot.exists) {
              contacts.add(UserEntity.fromMap({...userSnapshot.data()!, 'id': userSnapshot.id}));
            }
            
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

  @override
  Future<void> addGroupAdmin(String chatId, String adminId, String userId) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot add admin to a non-group chat');
      }
      
      final List<String> adminIds = List<String>.from(chatData['adminIds'] ?? []);
      final String creatorId = chatData['createdBy'] ?? '';
      
      if (!adminIds.contains(adminId) && adminId != creatorId) {
        throw Exception('Only admins can add new admins');
      }
      
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      if (!participantIds.contains(userId)) {
        throw Exception('User is not a member of this chat');
      }
      
      if (adminIds.contains(userId)) {
        throw Exception('User is already an admin of this chat');
      }
      
      adminIds.add(userId);
      
      await _chatDoc(chatId).update({
        'adminIds': adminIds,
      });
      
      final userSnapshot = await _userDoc(userId).get();
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      
      final adminSnapshot = await _userDoc(adminId).get();
      final adminName = adminSnapshot.data()?['name'] ?? 'Администратор';
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = false;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': '$adminName назначил(а) $userName администратором группы',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      await _chatDoc(chatId).update({
        'lastMessageText': '$adminName назначил(а) $userName администратором группы',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
        'lastMessageType': MessageType.system.index,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error adding group admin', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> removeGroupAdmin(String chatId, String adminId, String userId) async {
    try {
      final chatSnapshot = await _chatDoc(chatId).get();
      
      if (!chatSnapshot.exists) {
        throw Exception('Chat does not exist');
      }
      
      final chatData = chatSnapshot.data()!;
      
      if (!(chatData['isGroup'] ?? false)) {
        throw Exception('Cannot remove admin from a non-group chat');
      }
      
      final List<String> adminIds = List<String>.from(chatData['adminIds'] ?? []);
      final String creatorId = chatData['createdBy'] ?? '';
      
      if (!adminIds.contains(adminId) && adminId != creatorId) {
        throw Exception('Only admins can remove admins');
      }
      
      if (!adminIds.contains(userId)) {
        throw Exception('User is not an admin of this chat');
      }
      
      if (userId == creatorId) {
        throw Exception('Cannot remove creator from admins');
      }
      
      adminIds.remove(userId);
      
      await _chatDoc(chatId).update({
        'adminIds': adminIds,
      });
      
      final userSnapshot = await _userDoc(userId).get();
      final userName = userSnapshot.data()?['name'] ?? 'Пользователь';
      
      final adminSnapshot = await _userDoc(adminId).get();
      final adminName = adminSnapshot.data()?['name'] ?? 'Администратор';
      
      final List<String> participantIds = List<String>.from(chatData['participantIds'] ?? []);
      
      final messageId = _uuid.v4();
      final now = DateTime.now();
      
      final Map<String, bool> readStatus = {};
      for (final participantId in participantIds) {
        readStatus[participantId] = false;
      }
      
      final messageData = {
        'chatId': chatId,
        'senderId': '',
        'text': '$adminName снял(а) с $userName права администратора',
        'type': MessageType.system.index,
        'timestamp': now.millisecondsSinceEpoch,
        'isEdited': false,
        'readStatus': readStatus,
      };
      
      await _messageDoc(chatId, messageId).set(messageData);
      
      await _chatDoc(chatId).update({
        'lastMessageText': '$adminName снял(а) с $userName права администратора',
        'lastMessageTime': now.millisecondsSinceEpoch,
        'lastMessageSenderId': null,
        'lastMessageType': MessageType.system.index,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error removing group admin', e, stackTrace);
      rethrow;
    }
  }
} 