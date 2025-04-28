import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/services/chat_repository_impl.dart';
import 'package:monkey_messanger/utils/app_logger.dart';

class CreateGroupChatScreen extends StatefulWidget {
  final UserEntity currentUser;

  const CreateGroupChatScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<UserEntity> _selectedUsers = [];
  List<UserEntity> _availableUsers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем всех пользователей, кроме текущего
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isNotEqualTo: widget.currentUser.id)
          .get();

      setState(() {
        _availableUsers = usersSnapshot.docs
            .map((doc) => UserEntity.fromMap({...doc.data(), 'id': doc.id}))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при загрузке пользователей: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _toggleUserSelection(UserEntity user) {
    setState(() {
      if (_selectedUsers.contains(user)) {
        _selectedUsers.remove(user);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _createGroupChat() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название группы')),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного пользователя')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Добавляем таймаут для предотвращения бесконечной загрузки
    Future<void> timeoutFuture = Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        AppLogger.warning('Timeout при создании группового чата');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Время ожидания создания чата истекло. Пожалуйста, попробуйте снова.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Время ожидания истекло. Пожалуйста, попробуйте снова.')),
        );
      }
    });

    try {
      AppLogger.info('Creating group chat with name: ${_groupNameController.text.trim()}');
      AppLogger.info('Current user ID: ${widget.currentUser.id}');
      
      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );
      
      final participantIds = _selectedUsers.map((user) => user.id).toList();
      AppLogger.info('Selected participants: ${participantIds.join(", ")}');
      AppLogger.info('Total number of participants: ${participantIds.length}');
      
      AppLogger.info('Calling createGroupChat method...');
      final chatEntity = await chatRepository.createGroupChat(
        widget.currentUser.id,
        _groupNameController.text.trim(),
        participantIds,
      );
      AppLogger.info('Group chat created successfully with ID: ${chatEntity.id}');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Групповой чат успешно создан')),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in _createGroupChat: ${e.toString()}', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка при создании группы: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать групповой чат: ${e.toString()}')),
        );
      }
    } finally {
      // Отменяем таймаут если операция завершилась
      timeoutFuture.timeout(Duration.zero, onTimeout: () {}).catchError((_) {});
      
      // Гарантируем, что флаг загрузки будет сброшен в любом случае
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Создание группового чата',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4A90E2),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _groupNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Название группы',
                          hintText: 'Введите название группы',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF4A90E2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Выберите участников:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = _availableUsers[index];
                            final isSelected = _selectedUsers.contains(user);
                            return ListTile(
                              title: Text(
                                user.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                user.email,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF4A90E2),
                                child: user.photoUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          user.photoUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Text(
                                        user.name.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                              ),
                              trailing: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? const Color(0xFF4A90E2)
                                    : Colors.white70,
                              ),
                              onTap: () => _toggleUserSelection(user),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _createGroupChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Создать группу',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
} 