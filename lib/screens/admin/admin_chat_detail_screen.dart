import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:monkey_messanger/models/message_entity.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';

class AdminChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const AdminChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
  }) : super(key: key);

  @override
  State<AdminChatDetailScreen> createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<AdminChatDetailScreen> {
  List<MessageEntity> _messages = [];
  bool _isLoadingMessages = false;
  
  // Ключи шифрования
  late encrypt.Key _encryptionKey;
  late encrypt.IV _iv;
  
  // Фиксированные значения ключей, взятые из chat_bloc.dart
  static const String _fixedKeyString = 'MonkeyMessengerFixedEncryptionKey123';
  static const String _fixedIvString = 'MonkeyMsgFixedIV';

  @override
  void initState() {
    super.initState();
    _initEncryption();
    _loadMessages();
  }
  
  void _initEncryption() {
    try {
      // Используем фиксированные ключи
      _encryptionKey = encrypt.Key(utf8.encode(_fixedKeyString).sublist(0, 32));
      _iv = encrypt.IV(utf8.encode(_fixedIvString).sublist(0, 16));
    } catch (e) {
      _showErrorSnackBar('Ошибка инициализации шифрования: $e');
      // Создаем ключи из фиксированных строк в случае ошибки
      _encryptionKey = encrypt.Key(utf8.encode(_fixedKeyString).sublist(0, 32));
      _iv = encrypt.IV(utf8.encode(_fixedIvString).sublist(0, 16));
    }
  }
  
  String _decryptMessage(String encryptedMessage) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      return encrypter.decrypt64(encryptedMessage, iv: _iv);
    } catch (e) {
      print('Failed to decrypt message: $e');
      return '[Зашифрованное сообщение]';
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMessages = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.chatsCollection)
          .doc(widget.chatId)
          .collection(AppConstants.messagesCollection)
          .orderBy('timestamp', descending: true)
          .get();

      final messages = querySnapshot.docs
          .map((doc) => MessageEntity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
        _showErrorSnackBar('Ошибка при загрузке сообщений: $e');
      }
    }
  }

  Future<void> _deleteMessage(MessageEntity message) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.chatsCollection)
          .doc(message.chatId)
          .collection(AppConstants.messagesCollection)
          .doc(message.id)
          .delete();

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
        _showSuccessSnackBar('Сообщение удалено');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Ошибка при удалении сообщения: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text('Сообщения не найдены'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final bool isSystem = message.type == MessageType.system;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            leading: isSystem
              ? const Icon(Icons.info_outline, color: Colors.blueGrey)
              : const Icon(Icons.message_outlined, color: AppColors.primaryColor),
            title: Text(
              isSystem ? 'Система' : 'ID отправителя: ${message.senderId}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.type == MessageType.text && message.text != null ? _decryptMessage(message.text!) : (message.text ?? '')),
                Text(
                  'Отправлено: ${message.timestamp.toString()}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteMessageDialog(message),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteMessageDialog(MessageEntity message) {
    final displayText = message.type == MessageType.text && message.text != null
        ? _decryptMessage(message.text!)
        : (message.text ?? '');
        
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение'),
        content: Text('Вы уверены, что хотите удалить сообщение "$displayText"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteMessage(message);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Чат: ${widget.chatName}'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: _buildMessageList(),
      ),
    );
  }
} 