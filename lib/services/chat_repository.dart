import 'dart:io';

import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/models/message_entity.dart';

abstract class ChatRepository {
  // Потоки для реального времени
  Stream<List<ChatEntity>> getUserChats(String userId);
  Stream<List<MessageEntity>> getChatMessages(String chatId, {int limit = 50});
  Stream<ChatEntity?> getChatById(String chatId);

  // Операции с чатами
  Future<ChatEntity> createPrivateChat(String currentUserId, String otherUserId);
  Future<ChatEntity> createGroupChat(String creatorId, String name, List<String> participantIds, {String? imageUrl});
  Future<void> deleteChat(String chatId);
  Future<void> deleteOrLeaveChat(String chatId, String userId);
  Future<void> leaveGroupChat(String chatId, String userId);
  Future<bool> chatExists(String currentUserId, String otherUserId);
  Future<void> addUserToGroupChat(String chatId, String userId);
  Future<void> removeUserFromGroupChat(String chatId, String userId);
  Future<void> updateGroupChatName(String chatId, String newName);
  Future<void> updateGroupChatImage(String chatId, String imageUrl);
  Future<void> addGroupAdmin(String chatId, String adminId, String userId);
  Future<void> removeGroupAdmin(String chatId, String adminId, String userId);
  Future<void> markChatAsRead(String chatId, String userId);
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping);

  // Операции с сообщениями
  Future<MessageEntity> sendTextMessage(String chatId, String senderId, String text);
  Future<MessageEntity> sendImageMessage(String chatId, String senderId, File imageFile, {String? caption});
  Future<MessageEntity> sendFileMessage(String chatId, String senderId, File file, {String? caption});
  Future<MessageEntity> sendVoiceMessage(String chatId, String senderId, File audioFile, int durationSeconds);
  Future<void> deleteMessage(String messageId, String chatId);
  Future<void> editTextMessage(String messageId, String chatId, String newText);
  Future<void> markMessageAsRead(String messageId, String chatId, String userId);

  // Поиск пользователей
  Future<List<UserEntity>> searchUsers(String searchQuery, {int limit = 20});
  Future<List<UserEntity>> getRecentContacts(String userId, {int limit = 10});

  // Утилиты
  Future<Map<String, UserEntity>> getChatUsersData(List<String> userIds);
  Future<bool> isChatExists(String currentUserId, String otherUserId);
  Future<String?> getExistingChatId(String currentUserId, String otherUserId);
} 