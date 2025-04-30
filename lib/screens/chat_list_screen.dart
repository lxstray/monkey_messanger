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
import 'package:monkey_messanger/services/contact_repository_impl.dart';
import 'package:monkey_messanger/screens/contact_edit_screen.dart';
import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/models/message_entity.dart';
import 'package:monkey_messanger/screens/profile_screen.dart';
import 'package:monkey_messanger/screens/contacts_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentPage = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight - 8),
        child: AppBar(
          backgroundColor: const Color(0xFF2A2A2A),
          title: null,
          automaticallyImplyLeading: false,
          elevation: 0,
          toolbarHeight: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF4A90E2),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.5),
            tabs: const [
              Tab(text: 'Чаты'),
              Tab(text: 'Контакты'),
              Tab(text: 'Профиль'),
            ],
            labelPadding: EdgeInsets.zero,
            indicatorPadding: EdgeInsets.zero,
            indicator: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF4A90E2),
                  width: 3.0,
                ),
              ),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
            _tabController.animateTo(index);
          });
        },
        children: [
          _buildChatsPage(currentUser),
          ContactsScreen(
            onAddContactPressed: (userId) => _showAddContactDialog(context, userId),
          ),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _currentPage != 2 ? FloatingActionButton(
        backgroundColor: const Color(0xFF4A90E2),
        onPressed: () {
          if (_currentPage == 0) {
            _showNewChatDialog(context, currentUser?.id ?? '');
          } else if (_currentPage == 1) {
            _showAddContactDialog(context, currentUser?.id ?? '');
          }
        },
        child: Icon(
          _currentPage == 0 ? Icons.chat : Icons.person_add,
          color: Colors.white,
        ),
      ) : null,
    );
  }

  Widget _buildChatsPage(currentUser) {
    return StreamBuilder<QuerySnapshot>(
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

        return RefreshIndicator(
          color: const Color(0xFF4A90E2),
          backgroundColor: const Color(0xFF2A2A2A),
          onRefresh: () async {
            // Force refresh of the Firestore query by temporarily using a different query
            // and then immediately switching back to the original query
            await FirebaseFirestore.instance
                .collection('chats')
                .where('participantIds', arrayContains: currentUser?.id)
                .get();
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(), // Enable scrolling even when list is small
            itemCount: chats.length,
            separatorBuilder: (context, index) => Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final chatName = chat['name'] as String? ?? 'Unnamed Chat';
              
              // Декодируем последнее сообщение с учетом типа
              String lastMessage = '';
              final lastMessageType = chat['lastMessageType'] as int? ?? 0;
              final messageType = MessageType.values[lastMessageType];
              
              // Если это текстовое сообщение, которое нужно расшифровать
              if (messageType == MessageType.text) {
                final encryptedMessage = chat['lastMessageText'] as String? ?? '';
                try {
                  // Используем безопасный метод расшифрования из блока
                  lastMessage = context.read<ChatBloc>().decryptMessageSafe(encryptedMessage);
                } catch (e) {
                  lastMessage = '[Зашифрованное сообщение]';
                }
              } else {
                // Для нетекстовых сообщений берем как есть
                lastMessage = chat['lastMessageText'] as String? ?? 'No messages yet';
              }
              
              final isGroup = chat['isGroup'] as bool? ?? false;
              final imageUrl = chat['imageUrl'] as String?;
              
              // Handle different timestamp formats (int or Timestamp)
              DateTime? lastMessageTime;
              final lastMessageTimeRaw = chat['lastMessageTime'];
              if (lastMessageTimeRaw is Timestamp) {
                lastMessageTime = lastMessageTimeRaw.toDate();
              } else if (lastMessageTimeRaw is int) {
                lastMessageTime = DateTime.fromMillisecondsSinceEpoch(lastMessageTimeRaw);
              }

              Widget leadingWidget;
              if (imageUrl != null) {
                leadingWidget = ClipOval(
                  child: Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return CircleAvatar(
                        backgroundColor: const Color(0xFF4A90E2),
                        radius: 25,
                        child: Text(
                          chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                );
              } else {
                leadingWidget = CircleAvatar(
                  backgroundColor: const Color(0xFF4A90E2),
                  radius: 25,
                  child: Icon(
                    isGroup ? Icons.group : Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                );
              }

              return Dismissible(
                key: Key(chatId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFF2A2A2A),
                        title: const Text(
                          'Подтверждение',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          'Вы уверены, что хотите удалить чат "$chatName"?',
                          style: const TextStyle(color: Colors.white),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(
                              'Отмена',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Удалить',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) async {
                  try {
                    // Create repository instance
                    final chatRepository = ChatRepositoryImpl(
                      firestore: FirebaseFirestore.instance,
                      storage: FirebaseStorage.instance,
                    );
                    
                    // Delete the chat
                    await chatRepository.deleteChat(chatId);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Чат "$chatName" удален'),
                          backgroundColor: const Color(0xFF4A90E2),
                          action: SnackBarAction(
                            label: 'OK',
                            textColor: Colors.white,
                            onPressed: () {},
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка при удалении чата: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: leadingWidget,
                  title: Text(
                    chatName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (lastMessageTime != null)
                        Text(
                          _formatTime(lastMessageTime),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (isGroup)
                        Icon(
                          Icons.group,
                          size: 16,
                          color: Colors.white.withOpacity(0.5),
                        ),
                    ],
                  ),
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
          ),
        );
      },
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
    // Instead of asking for email, show a list of contacts
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Выберите контакт',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<ContactEntity>>(
              stream: ContactRepositoryImpl(
                firestore: FirebaseFirestore.instance,
              ).getUserContacts(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Ошибка: ${snapshot.error}',
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

                final contacts = snapshot.data ?? [];

                if (contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 48,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'У вас нет контактов',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddContactDialog(context, currentUserId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.person_add, color: Colors.white),
                          label: const Text(
                            'Добавить контакт',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4A90E2),
                        child: contact.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  contact.photoUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Text(
                                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                            : Text(
                                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                      title: Text(
                        contact.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        contact.email,
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      onTap: () async {
                        // Create chat with the selected contact
                        try {
                          Navigator.pop(context);
                          
                          final chatRepository = ChatRepositoryImpl(
                            firestore: FirebaseFirestore.instance,
                            storage: FirebaseStorage.instance,
                          );

                          final chatEntity = await chatRepository.createPrivateChat(
                            currentUserId,
                            contact.contactId,
                          );

                          if (context.mounted) {
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
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.white70),
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

  void _showAddContactDialog(BuildContext context, String currentUserId) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Добавить новый контакт',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Имя',
                  hintText: 'Введите имя контакта',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4A90E2)),
                  ),
                ),
              ),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Введите email контакта',
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
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isNotEmpty && email.isNotEmpty) {
                  try {
                    final contactRepository = ContactRepositoryImpl(
                      firestore: FirebaseFirestore.instance,
                    );

                    final contactEntity = await contactRepository.createContact(
                      name,
                      email,
                      currentUserId,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      
                      // Navigate to contact edit screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContactEditScreen(
                            contact: contactEntity,
                            currentUser: context.read<AuthBloc>().state.user!,
                          ),
                        ),
                      );
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
} 