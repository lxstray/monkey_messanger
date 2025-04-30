import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType {
  private,
  group,
}

class ChatEntity extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final List<String> participantIds;
  final String lastMessageText;
  final DateTime lastMessageTime;
  final String? lastMessageSenderId;
  final bool isGroup;
  final Map<String, int> unreadMessageCount; // Map<userId, unreadCount>
  final DateTime createdAt;
  final String? createdBy;
  final Map<String, bool>? typing; // Map<userId, isTyping>

  const ChatEntity({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.participantIds,
    required this.lastMessageText,
    required this.lastMessageTime,
    this.lastMessageSenderId,
    required this.isGroup,
    required this.unreadMessageCount,
    required this.createdAt,
    this.createdBy,
    this.typing,
  });

  // Копирование объекта с возможностью изменения отдельных полей
  ChatEntity copyWith({
    String? id,
    String? name,
    String? imageUrl,
    List<String>? participantIds,
    String? lastMessageText,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    bool? isGroup,
    Map<String, int>? unreadMessageCount,
    DateTime? createdAt,
    String? createdBy,
    Map<String, bool>? typing,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      participantIds: participantIds ?? this.participantIds,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      isGroup: isGroup ?? this.isGroup,
      unreadMessageCount: unreadMessageCount ?? this.unreadMessageCount,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      typing: typing ?? this.typing,
    );
  }

  // Преобразование в Map для Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'participantIds': participantIds,
      'lastMessageText': lastMessageText,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageType': 0, // По умолчанию текст
      'isGroup': isGroup,
      'unreadMessageCount': unreadMessageCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdBy': createdBy,
      'typing': typing,
    };
  }

  // Создание объекта из Map из Firebase
  factory ChatEntity.fromMap(Map<String, dynamic> map) {
    // Обработка времени, которое может быть в разных форматах
    DateTime _parseDateTime(dynamic time) {
      if (time is Timestamp) {
        return time.toDate();
      } else if (time is int) {
        return DateTime.fromMillisecondsSinceEpoch(time);
      }
      return DateTime.now();
    }

    // Обработка текста последнего сообщения (совместимость со старыми данными)
    String _getLastMessageText(Map<String, dynamic> data) {
      if (data.containsKey('lastMessageText') && data['lastMessageText'] != null) {
        return data['lastMessageText'] as String;
      }
      return '';
    }

    return ChatEntity(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'],
      participantIds: List<String>.from(map['participantIds'] ?? []),
      lastMessageText: _getLastMessageText(map),
      lastMessageTime: _parseDateTime(map['lastMessageTime']),
      lastMessageSenderId: map['lastMessageSenderId'],
      isGroup: map['isGroup'] ?? false,
      unreadMessageCount: Map<String, int>.from(map['unreadMessageCount'] ?? {}),
      createdAt: _parseDateTime(map['createdAt']),
      createdBy: map['createdBy'],
      typing: map['typing'] != null ? Map<String, bool>.from(map['typing']) : null,
    );
  }

  // Проверка, является ли участник админом группы (создатель чата)
  bool isAdmin(String userId) {
    return createdBy == userId;
  }

  // Получение имени чата для конкретного пользователя
  String getDisplayName(String currentUserId, Map<String, String> userNames) {
    if (isGroup) {
      return name;
    } else {
      // Для личного чата показываем имя собеседника
      String otherUserId = participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      return userNames[otherUserId] ?? name;
    }
  }

  // Получение аватара чата для конкретного пользователя
  String? getDisplayImage(String currentUserId, Map<String, String?> userImages) {
    if (isGroup || imageUrl != null) {
      return imageUrl;
    } else {
      // Для личного чата показываем аватар собеседника
      String otherUserId = participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      return userImages[otherUserId];
    }
  }

  // Проверка на наличие непрочитанных сообщений
  bool hasUnreadMessages(String userId) {
    return (unreadMessageCount[userId] ?? 0) > 0;
  }

  // Получение количества непрочитанных сообщений
  int getUnreadCount(String userId) {
    return unreadMessageCount[userId] ?? 0;
  }

  // Проверка, печатает ли кто-то в данный момент
  bool isSomeoneTyping() {
    return typing?.values.any((isTyping) => isTyping) ?? false;
  }

  // Получение списка пользователей, которые печатают
  List<String> getTypingUsers() {
    if (typing == null) return [];
    
    return typing!.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  List<Object?> get props => [
        id,
        name,
        imageUrl,
        participantIds,
        lastMessageText,
        lastMessageTime,
        lastMessageSenderId,
        isGroup,
        unreadMessageCount,
        createdAt,
        createdBy,
        typing,
      ];
} 