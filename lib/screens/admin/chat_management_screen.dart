import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/models/message_entity.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_constants.dart';

class ChatManagementScreen extends StatefulWidget {
  const ChatManagementScreen({Key? key}) : super(key: key);

  @override
  State<ChatManagementScreen> createState() => _ChatManagementScreenState();
}

class _ChatManagementScreenState extends State<ChatManagementScreen> {
  bool _isLoading = false;
  List<ChatEntity> _chats = [];
  ChatEntity? _selectedChat;
  List<MessageEntity> _messages = [];
  bool _isLoadingMessages = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  List<ChatEntity> get _filteredChats {
    if (_searchQuery.isEmpty) {
      return _chats;
    }
    return _chats.where((chat) {
      return chat.name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.chatsCollection)
          .orderBy('lastMessageTime', descending: true)
          .get();

      final chats = querySnapshot.docs
          .map((doc) => ChatEntity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Ошибка при загрузке чатов: $e');
    }
  }

  Future<void> _loadMessages(String chatId) async {
    setState(() {
      _isLoadingMessages = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .orderBy('timestamp', descending: true)
          .get();

      final messages = querySnapshot.docs
          .map((doc) => MessageEntity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMessages = false;
      });
      _showErrorSnackBar('Ошибка при загрузке сообщений: $e');
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

      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });

      _showSuccessSnackBar('Сообщение удалено');
    } catch (e) {
      _showErrorSnackBar('Ошибка при удалении сообщения: $e');
    }
  }

  Future<void> _deleteChat(ChatEntity chat) async {
    try {
      // Get messages in the chat
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.chatsCollection)
          .doc(chat.id)
          .collection(AppConstants.messagesCollection)
          .get();

      // Delete all messages
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete the chat
      await FirebaseFirestore.instance
          .collection(AppConstants.chatsCollection)
          .doc(chat.id)
          .delete();

      setState(() {
        _chats.removeWhere((c) => c.id == chat.id);
        if (_selectedChat?.id == chat.id) {
          _selectedChat = null;
          _messages = [];
        }
      });

      _showSuccessSnackBar('Чат удален');
    } catch (e) {
      _showErrorSnackBar('Ошибка при удалении чата: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }

  void _selectChat(ChatEntity chat) {
    setState(() {
      _selectedChat = chat;
      _messages = [];
    });
    _loadMessages(chat.id);
  }

  Widget _buildChatList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredChats.isEmpty) {
      return const Center(
        child: Text('Чаты не найдены'),
      );
    }

    return ListView.builder(
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];
        final bool isSelected = _selectedChat?.id == chat.id;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryColor,
            backgroundImage: chat.imageUrl != null ? NetworkImage(chat.imageUrl!) : null,
            child: chat.imageUrl == null 
              ? chat.isGroup 
                ? const Icon(Icons.group)
                : Text(chat.name.isNotEmpty ? chat.name[0].toUpperCase() : 'C')
              : null,
          ),
          title: Text(
            chat.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            'Последнее сообщение: ${chat.lastMessageText}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isSelected,
          selectedTileColor: Colors.blue.withOpacity(0.1),
          onTap: () => _selectChat(chat),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteChatDialog(chat),
          ),
        );
      },
    );
  }

  void _showDeleteChatDialog(ChatEntity chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить чат'),
        content: Text('Вы уверены, что хотите удалить чат "${chat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteChat(chat);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_selectedChat == null) {
      return const Center(
        child: Text('Выберите чат для просмотра сообщений'),
      );
    }

    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text('Сообщения не найдены'),
      );
    }

    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final bool isSystem = message.type == MessageType.system;

        return ListTile(
          leading: isSystem
            ? const Icon(Icons.info)
            : const Icon(Icons.message),
          title: Text(
            isSystem ? 'Система' : 'ID отправителя: ${message.senderId}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.text ?? ''),
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
        );
      },
    );
  }

  void _showDeleteMessageDialog(MessageEntity message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение'),
        content: Text('Вы уверены, что хотите удалить сообщение "${message.text ?? ''}"?'),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск чатов',
                hintText: 'Введите название чата',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                filled: true,
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Чаты
                Expanded(
                  flex: 2,
                  child: RefreshIndicator(
                    onRefresh: _loadChats,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Чаты',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _buildChatList(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Вертикальный разделитель
                Container(
                  width: 1,
                  color: Colors.grey.withOpacity(0.3),
                ),
                // Сообщения
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _selectedChat != null
                              ? 'Сообщения чата "${_selectedChat!.name}"'
                              : 'Сообщения',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildMessageList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 