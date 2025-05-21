import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  file,
  voice,
  system,  
}

class MessageEntity extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final MessageType type;
  final DateTime timestamp;
  final bool isEdited;
  final Map<String, bool>? readStatus; 
  final String? mediaUrl; 
  final String? mediaName; 
  final int? mediaSizeBytes; 
  final int? voiceDurationSeconds; 
  final Map<String, dynamic>? metadata; 

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    required this.type,
    required this.timestamp,
    this.isEdited = false,
    this.readStatus,
    this.mediaUrl,
    this.mediaName,
    this.mediaSizeBytes,
    this.voiceDurationSeconds,
    this.metadata,
  });

  MessageEntity copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    MessageType? type,
    DateTime? timestamp,
    bool? isEdited,
    Map<String, bool>? readStatus,
    String? mediaUrl,
    String? mediaName,
    int? mediaSizeBytes,
    int? voiceDurationSeconds,
    Map<String, dynamic>? metadata,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
      readStatus: readStatus ?? this.readStatus,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaName: mediaName ?? this.mediaName,
      mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type.index, 
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isEdited': isEdited,
      'readStatus': readStatus,
      'mediaUrl': mediaUrl,
      'mediaName': mediaName,
      'mediaSizeBytes': mediaSizeBytes,
      'voiceDurationSeconds': voiceDurationSeconds,
      'metadata': metadata,
    };
  }

  factory MessageEntity.fromMap(Map<String, dynamic> map) {
    DateTime _parseDateTime(dynamic time) {
      if (time is Timestamp) {
        return time.toDate();
      } else if (time is int) {
        return DateTime.fromMillisecondsSinceEpoch(time);
      }
      return DateTime.now();
    }

    return MessageEntity(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'],
      type: MessageType.values[map['type'] ?? 0],
      timestamp: _parseDateTime(map['timestamp']),
      isEdited: map['isEdited'] ?? false,
      readStatus: map['readStatus'] != null 
          ? Map<String, bool>.from(map['readStatus']) 
          : null,
      mediaUrl: map['mediaUrl'],
      mediaName: map['mediaName'],
      mediaSizeBytes: map['mediaSizeBytes'],
      voiceDurationSeconds: map['voiceDurationSeconds'],
      metadata: map['metadata'],
    );
  }

  factory MessageEntity.text({
    required String id,
    required String chatId,
    required String senderId,
    required String text,
    required DateTime timestamp,
    Map<String, bool>? readStatus,
  }) {
    return MessageEntity(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: text,
      type: MessageType.text,
      timestamp: timestamp,
      readStatus: readStatus,
    );
  }

  factory MessageEntity.image({
    required String id,
    required String chatId,
    required String senderId,
    String? caption,
    required String mediaUrl,
    required DateTime timestamp,
    Map<String, bool>? readStatus,
    int? mediaSizeBytes,
  }) {
    return MessageEntity(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: caption,
      type: MessageType.image,
      timestamp: timestamp,
      readStatus: readStatus,
      mediaUrl: mediaUrl,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  factory MessageEntity.file({
    required String id,
    required String chatId,
    required String senderId,
    String? caption,
    required String mediaUrl,
    required String mediaName,
    required int mediaSizeBytes,
    required DateTime timestamp,
    Map<String, bool>? readStatus,
  }) {
    return MessageEntity(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: caption,
      type: MessageType.file,
      timestamp: timestamp,
      readStatus: readStatus,
      mediaUrl: mediaUrl,
      mediaName: mediaName,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  factory MessageEntity.voice({
    required String id,
    required String chatId,
    required String senderId,
    required String mediaUrl,
    required int voiceDurationSeconds,
    required DateTime timestamp,
    Map<String, bool>? readStatus,
    int? mediaSizeBytes,
  }) {
    return MessageEntity(
      id: id,
      chatId: chatId,
      senderId: senderId,
      type: MessageType.voice,
      timestamp: timestamp,
      readStatus: readStatus,
      mediaUrl: mediaUrl,
      voiceDurationSeconds: voiceDurationSeconds,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  factory MessageEntity.system({
    required String id,
    required String chatId,
    required String text,
    required DateTime timestamp,
  }) {
    return MessageEntity(
      id: id,
      chatId: chatId,
      senderId: '', // Пустая строка для системных сообщений
      text: text,
      type: MessageType.system,
      timestamp: timestamp,
    );
  }

  bool isReadBy(String userId) {
    return readStatus?[userId] ?? false;
  }

  bool isReadByAll(List<String> participantIds, {List<String>? excludeUserIds}) {
    if (readStatus == null || readStatus!.isEmpty) return false;
    
    final List<String> usersToCheck = participantIds
        .where((uid) => uid != senderId && !(excludeUserIds?.contains(uid) ?? false))
        .toList();
    
    if (usersToCheck.isEmpty) return true;
    
    return usersToCheck.every((uid) => readStatus![uid] == true);
  }

  int getReadCount() {
    if (readStatus == null) return 0;
    return readStatus!.values.where((hasRead) => hasRead).length;
  }

  List<String> getReadUserIds() {
    if (readStatus == null) return [];
    return readStatus!.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        text,
        type,
        timestamp,
        isEdited,
        readStatus,
        mediaUrl,
        mediaName,
        mediaSizeBytes,
        voiceDurationSeconds,
        metadata,
      ];
} 