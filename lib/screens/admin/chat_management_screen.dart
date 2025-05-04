import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/models/message_entity.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:monkey_messanger/screens/admin/admin_chat_detail_screen.dart';

class ChatManagementScreen extends StatefulWidget {
  const ChatManagementScreen({Key? key}) : super(key: key);

  @override
  State<ChatManagementScreen> createState() => _ChatManagementScreenState();
}

class _ChatManagementScreenState extends State<ChatManagementScreen> {
  bool _isLoading = false;
  List<ChatEntity> _chats = [];
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
      });

      _showErrorSnackBar('Чат удален');
    } catch (e) {
      _showErrorSnackBar('Ошибка при удалении чата: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
      ),
    );
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
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            leading: CircleAvatar(
              radius: 24,
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
            ),
            subtitle: Text(
              'ID: ${chat.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminChatDetailScreen(
                    chatId: chat.id,
                    chatName: chat.name,
                  ),
                ),
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteChatDialog(chat),
            ),
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
        content: Text('Вы уверены, что хотите удалить чат "${chat.name}"? Все сообщения будут удалены.'),
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
                hintText: 'Введите название чата или ID',
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
            child: RefreshIndicator(
              onRefresh: _loadChats,
              child: _buildChatList(),
            ),
          ),
        ],
      ),
    );
  }
} 