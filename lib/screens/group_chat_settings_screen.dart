import 'package:flutter/material.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/services/chat_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:monkey_messanger/utils/app_logger.dart';

class GroupChatSettingsScreen extends StatefulWidget {
  final String chatId;
  final UserEntity currentUser;
  final ChatEntity chatEntity;

  const GroupChatSettingsScreen({
    Key? key,
    required this.chatId,
    required this.currentUser,
    required this.chatEntity,
  }) : super(key: key);

  @override
  State<GroupChatSettingsScreen> createState() => _GroupChatSettingsScreenState();
}

class _GroupChatSettingsScreenState extends State<GroupChatSettingsScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<UserEntity> _chatParticipants = [];
  final TextEditingController _groupNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  bool get _isAdmin => widget.chatEntity.isAdmin(widget.currentUser.id);

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.chatEntity.name;
    _loadChatParticipants();
  }

  Future<void> _loadChatParticipants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestoreInstance = FirebaseFirestore.instance;
      final usersCollection = firestoreInstance.collection('users');
      _chatParticipants = [];

      for (final userId in widget.chatEntity.participantIds) {
        final userDoc = await usersCollection.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          _chatParticipants.add(UserEntity.fromMap({...userData, 'id': userDoc.id}));
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при загрузке участников: ${e.toString()}';
      });
      AppLogger.error('Error loading chat participants', e);
    }
  }

  Future<void> _updateGroupName() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя группы не может быть пустым')),
      );
      return;
    }

    if (_groupNameController.text.trim() == widget.chatEntity.name) {
      return; // Имя не изменилось
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      await chatRepository.updateGroupChatName(
        widget.chatId,
        _groupNameController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Название группы обновлено')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при обновлении названия: ${e.toString()}';
      });
      AppLogger.error('Error updating group name', e);
    }
  }

  Future<void> _updateGroupImage() async {
    if (_selectedImage == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child('chat_images/${widget.chatId}.jpg');
      
      await ref.putFile(_selectedImage!);
      final imageUrl = await ref.getDownloadURL();

      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      await chatRepository.updateGroupChatImage(widget.chatId, imageUrl);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Изображение группы обновлено')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при обновлении изображения: ${e.toString()}';
      });
      AppLogger.error('Error updating group image', e);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      AppLogger.error('Error picking image', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе изображения: ${e.toString()}')),
      );
    }
  }

  Future<void> _removeUserFromGroup(String userId) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только администратор может удалить участников')),
      );
      return;
    }

    final user = _chatParticipants.firstWhere((user) => user.id == userId);
    
    // Показать диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Удалить участника',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Вы уверены, что хотите удалить ${user.name} из группы?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      await chatRepository.removeUserFromGroupChat(widget.chatId, userId);

      // Обновляем список участников
      await _loadChatParticipants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} удален из группы')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при удалении участника: ${e.toString()}';
      });
      AppLogger.error('Error removing user from group', e);
    }
  }

  Future<void> _addUserToGroup() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только администратор может добавлять участников')),
      );
      return;
    }

    final TextEditingController emailController = TextEditingController();

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Добавить участника',
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Добавить',
                style: TextStyle(color: Color(0xFF4A90E2)),
              ),
            ),
          ],
        );
      },
    );

    if (proceed != true || emailController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Найти пользователя по email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailController.text.trim())
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Пользователь не найден';
        });
        return;
      }

      final userId = userQuery.docs.first.id;

      // Проверяем, не является ли пользователь уже участником группы
      if (widget.chatEntity.participantIds.contains(userId)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Пользователь уже является участником группы';
        });
        return;
      }

      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      await chatRepository.addUserToGroupChat(widget.chatId, userId);

      // Обновляем список участников
      await _loadChatParticipants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь добавлен в группу')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при добавлении участника: ${e.toString()}';
      });
      AppLogger.error('Error adding user to group', e);
    }
  }

  Future<void> _leaveGroup() async {
    // Показать диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Покинуть группу',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Вы уверены, что хотите покинуть эту группу?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Покинуть',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      await chatRepository.leaveGroupChat(widget.chatId, widget.currentUser.id);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы покинули группу')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при выходе из группы: ${e.toString()}';
      });
      AppLogger.error('Error leaving group', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Настройки группы',
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
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadChatParticipants,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                          ),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Изображение группы
                      Center(
                        child: GestureDetector(
                          onTap: _isAdmin ? _pickImage : null,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF4A90E2),
                                backgroundImage: _selectedImage != null
                                    ? FileImage(_selectedImage!)
                                    : widget.chatEntity.imageUrl != null
                                        ? NetworkImage(widget.chatEntity.imageUrl!) as ImageProvider<Object>
                                        : null,
                                child: widget.chatEntity.imageUrl == null && _selectedImage == null
                                    ? Text(
                                        widget.chatEntity.name.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 40,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              if (_isAdmin)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4A90E2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Название группы
                      if (_isAdmin)
                        TextField(
                          controller: _groupNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Название группы',
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF4A90E2)),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.save, color: Color(0xFF4A90E2)),
                              onPressed: _updateGroupName,
                            ),
                          ),
                        )
                      else
                        Card(
                          color: const Color(0xFF2A2A2A),
                          child: ListTile(
                            title: const Text(
                              'Название группы',
                              style: TextStyle(color: Colors.white70),
                            ),
                            subtitle: Text(
                              widget.chatEntity.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Создатель группы
                      Card(
                        color: const Color(0xFF2A2A2A),
                        child: ListTile(
                          title: const Text(
                            'Создатель группы',
                            style: TextStyle(color: Colors.white70),
                          ),
                          subtitle: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.chatEntity.createdBy)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Text(
                                  'Загрузка...',
                                  style: TextStyle(color: Colors.white),
                                );
                              }
                              
                              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                                return const Text(
                                  'Неизвестно',
                                  style: TextStyle(color: Colors.white),
                                );
                              }
                              
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              return Text(
                                data['name'] ?? 'Неизвестно',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Список участников
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Участники',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isAdmin)
                            IconButton(
                              icon: const Icon(Icons.person_add, color: Color(0xFF4A90E2)),
                              onPressed: _addUserToGroup,
                              tooltip: 'Добавить участника',
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _chatParticipants.length,
                        itemBuilder: (context, index) {
                          final participant = _chatParticipants[index];
                          final isCreator = participant.id == widget.chatEntity.createdBy;
                          
                          return Card(
                            color: const Color(0xFF2A2A2A),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF4A90E2),
                                backgroundImage: participant.photoUrl != null
                                    ? NetworkImage(participant.photoUrl!)
                                    : null,
                                child: participant.photoUrl == null
                                    ? Text(
                                        participant.name.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text(
                                participant.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                participant.email,
                                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              ),
                              trailing: isCreator
                                  ? const Icon(Icons.star, color: Colors.yellow)
                                  : _isAdmin && participant.id != widget.currentUser.id
                                      ? IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () => _removeUserFromGroup(participant.id),
                                          tooltip: 'Удалить участника',
                                        )
                                      : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Кнопка "Покинуть группу"
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _leaveGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Покинуть группу'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Если выбрано изображение, добавляем кнопку "Сохранить изображение"
                      if (_selectedImage != null && _isAdmin)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _updateGroupImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.save),
                            label: const Text('Сохранить изображение'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
} 