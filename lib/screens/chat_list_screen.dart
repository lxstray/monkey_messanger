import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:monkey_messanger/services/auth_state.dart';
import 'package:monkey_messanger/screens/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:monkey_messanger/services/chat_bloc.dart';
import 'package:monkey_messanger/screens/create_group_chat_screen.dart';
import 'package:monkey_messanger/services/chat_repository_impl.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Monkey Messenger',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutEvent());
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participantIds', arrayContains: currentUser?.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4A90E2),
              ),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No chats yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final chatName = chat['name'] as String? ?? 'Unnamed Chat';
              final lastMessage = chat['lastMessageText'] as String? ?? 'No messages yet';
              
              // Handle different timestamp formats (int or Timestamp)
              DateTime? lastMessageTime;
              final lastMessageTimeRaw = chat['lastMessageTime'];
              if (lastMessageTimeRaw is Timestamp) {
                lastMessageTime = lastMessageTimeRaw.toDate();
              } else if (lastMessageTimeRaw is int) {
                lastMessageTime = DateTime.fromMillisecondsSinceEpoch(lastMessageTimeRaw);
              }

              return Card(
                color: const Color(0xFF2A2A2A),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    chatName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: lastMessageTime != null
                      ? Text(
                          _formatTime(lastMessageTime),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        )
                      : null,
                  onTap: () {
                    // Устанавливаем текущий чат в существующем ChatBloc
                    context.read<ChatBloc>().add(LoadMessagesEvent(chatId));
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatId: chatId,
                          chatName: chatName,
                          currentUser: currentUser!,
                        ),
                      ),
                    ).then((_) {
                      // При возвращении из чата сбрасываем состояние чата
                      context.read<ChatBloc>().add(ResetChatEvent());
                    });
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A90E2),
        onPressed: () {
          _showNewChatDialog(context, currentUser?.id ?? '');
        },
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}';
  }

  void _showNewChatDialog(BuildContext context, String currentUserId) {
    final authState = context.read<AuthBloc>().state;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Новый чат',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF4A90E2)),
                title: const Text(
                  'Личный чат',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showPrivateChatDialog(context, currentUserId, authState);
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.group, color: Color(0xFF4A90E2)),
                title: const Text(
                  'Групповой чат',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCreateGroupChat(context, authState);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivateChatDialog(BuildContext context, String currentUserId, AuthState authState) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Новый личный чат',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email пользователя',
                  hintText: 'Введите email пользователя',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4A90E2)),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  try {
                    // Find user by email
                    final userQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: email)
                        .get();

                    if (userQuery.docs.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Пользователь не найден'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    final otherUserId = userQuery.docs.first.id;

                    if (otherUserId == currentUserId) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Вы не можете создать чат с собой'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    // Create chat
                    final chatRepository = ChatRepositoryImpl(
                      firestore: FirebaseFirestore.instance,
                      storage: FirebaseStorage.instance,
                    );

                    final chatEntity = await chatRepository.createPrivateChat(
                      currentUserId,
                      otherUserId,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      
                      // Navigate to chat screen
                      context.read<ChatBloc>().add(LoadMessagesEvent(chatEntity.id));
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chatEntity.id,
                            chatName: chatEntity.name,
                            currentUser: authState.user!,
                          ),
                        ),
                      ).then((_) {
                        // Reset chat state when returning from chat
                        context.read<ChatBloc>().add(ResetChatEvent());
                      });
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text(
                'Создать',
                style: TextStyle(color: Color(0xFF4A90E2)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToCreateGroupChat(BuildContext context, AuthState authState) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupChatScreen(
          currentUser: authState.user!,
        ),
      ),
    );
  }
} 