import 'package:flutter/material.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/services/chat_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/services/contact_repository_impl.dart';
import 'package:monkey_messanger/services/storage_service.dart';

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
  List<ContactEntity> _userContacts = [];
  bool _loadingContacts = false;
  
  // Создаем экземпляр StorageService для работы с Supabase
  final StorageService _storageService = StorageService();

  bool get _isAdmin => widget.chatEntity.isAdmin(widget.currentUser.id);

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.chatEntity.name;
    _loadChatParticipants();
    if (_isAdmin) {
      _loadUserContacts();
    }
  }
  
  // Загрузка контактов пользователя
  Future<void> _loadUserContacts() async {
    setState(() {
      _loadingContacts = true;
    });
    
    try {
      final contactRepository = ContactRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      );
      
      // Подписываемся на стрим контактов
      final contactsStream = contactRepository.getUserContacts(widget.currentUser.id);
      
      // Получаем первое значение из стрима
      final contacts = await contactsStream.first;
      
      setState(() {
        _userContacts = contacts;
        _loadingContacts = false;
      });
    } catch (e) {
      AppLogger.error('Error loading contacts', e);
      setState(() {
        _loadingContacts = false;
      });
    }
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
      // Используем StorageService вместо напрямую Firebase Storage
      final imageUrl = await _storageService.uploadImage(
        _selectedImage!, 
        widget.chatId,
        specificPath: 'chats/${widget.chatId}/profile/group_avatar.jpg'
      );
      
      // Проверяем результат загрузки
      if (imageUrl.isEmpty) {
        throw Exception('Не удалось загрузить изображение');
      }

      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      await chatRepository.updateGroupChatImage(widget.chatId, imageUrl);

      setState(() {
        _isLoading = false;
        _selectedImage = null; // Сбрасываем выбранное изображение после успешной загрузки
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
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000, // Ограничиваем размер изображения
        maxHeight: 1000,
        imageQuality: 85, // Снижаем качество для экономии трафика
      );
      
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
  
  // Добавление пользователя в качестве администратора
  Future<void> _toggleUserAdmin(String userId, bool makeAdmin) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только администратор может управлять правами')),
      );
      return;
    }
    
    // Проверяем, не является ли пользователь создателем группы
    if (userId == widget.chatEntity.createdBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Невозможно изменить права создателя группы')),
      );
      return;
    }
    
    final user = _chatParticipants.firstWhere((user) => user.id == userId);
    
    // Показать диалог подтверждения
    final String actionText = makeAdmin ? 'назначить' : 'снять с';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          makeAdmin ? 'Назначить администратором' : 'Снять права администратора',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Вы уверены, что хотите $actionText ${user.name} ${makeAdmin ? 'администратором' : 'прав администратора'}?',
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
            child: Text(
              makeAdmin ? 'Назначить' : 'Снять',
              style: TextStyle(color: makeAdmin ? Colors.green : Colors.red),
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

      if (makeAdmin) {
        await chatRepository.addGroupAdmin(widget.chatId, widget.currentUser.id, userId);
      } else {
        await chatRepository.removeGroupAdmin(widget.chatId, widget.currentUser.id, userId);
      }

      // Для простоты обновляем весь объект чата через навигацию
      if (mounted) {
        Navigator.pop(context, true); // Возвращаемся с флагом обновления
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              makeAdmin 
                ? '${user.name} назначен администратором' 
                : 'Права администратора ${user.name} отменены'
            )),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при изменении прав администратора: ${e.toString()}';
      });
      AppLogger.error('Error changing admin status', e);
    }
  }

  Future<void> _addUserToGroup() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только администратор может добавлять участников')),
      );
      return;
    }
    
    if (_loadingContacts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Загрузка контактов, пожалуйста подождите...')),
      );
      return;
    }
    
    if (_userContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет контактов для добавления')),
      );
      return;
    }
    
    final List<ContactEntity> availableContacts = _userContacts.where((contact) {
      return !widget.chatEntity.participantIds.contains(contact.contactId);
    }).toList();
    
    if (availableContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все ваши контакты уже добавлены в группу')),
      );
      return;
    }

    // Загрузка данных UserEntity для доступных контактов
    Map<String, UserEntity> availableContactsUserData = {};
    try {
      final contactRepository = ContactRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      );
      final contactUserIds = availableContacts.map((c) => c.contactId).toList();
      if (contactUserIds.isNotEmpty) {
        availableContactsUserData = await contactRepository.getUsersByIds(contactUserIds);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching user data for available contacts', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки данных контактов')),
        );
      }
      return; // Прерываем выполнение, если не удалось загрузить данные
    }

    final ContactEntity? selectedContact = await showDialog<ContactEntity>(
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
            height: 300, // Можно сделать адаптивным или убрать ограничение
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableContacts.length,
              itemBuilder: (context, index) {
                final contact = availableContacts[index];
                // Получаем UserEntity для текущего контакта из загруженных данных
                final contactUser = availableContactsUserData[contact.contactId];
                // Определяем URL для аватара
                final displayPhotoUrl = contactUser?.photoUrl ?? contact.photoUrl;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4A90E2),
                    // Используем displayPhotoUrl
                    child: displayPhotoUrl != null && displayPhotoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              displayPhotoUrl,
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
                  onTap: () => Navigator.pop(context, contact),
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

    if (selectedContact == null) {
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

      await chatRepository.addUserToGroupChat(widget.chatId, selectedContact.contactId);

      // Обновляем список участников
      await _loadChatParticipants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedContact.name} добавлен в группу')),
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
                          // Проверяем, является ли пользователь админом
                          final isParticipantAdmin = widget.chatEntity.isAdmin(participant.id);
                          
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
                              title: Row(
                                children: [
                                  Text(
                                    participant.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (isParticipantAdmin)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Icon(
                                        isCreator ? Icons.star : Icons.admin_panel_settings,
                                        color: isCreator ? Colors.yellow : Colors.green,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                participant.email,
                                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              ),
                              // Меню действий для администраторов
                              trailing: participant.id != widget.currentUser.id && _isAdmin
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.white),
                                      onSelected: (value) {
                                        if (value == 'remove') {
                                          _removeUserFromGroup(participant.id);
                                        } else if (value == 'make_admin') {
                                          _toggleUserAdmin(participant.id, true);
                                        } else if (value == 'remove_admin') {
                                          _toggleUserAdmin(participant.id, false);
                                        }
                                      },
                                      itemBuilder: (context) {
                                        final items = <PopupMenuEntry<String>>[];
                                        
                                        // Опция для назначения/снятия админа
                                        if (!isCreator) { // Создателя нельзя менять
                                          if (isParticipantAdmin) {
                                            items.add(
                                              const PopupMenuItem<String>(
                                                value: 'remove_admin',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.person_remove, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Снять админа', style: TextStyle(color: Colors.white)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          } else {
                                            items.add(
                                              const PopupMenuItem<String>(
                                                value: 'make_admin',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.admin_panel_settings, color: Colors.green),
                                                    SizedBox(width: 8),
                                                    Text('Сделать админом', style: TextStyle(color: Colors.white)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }
                                          
                                          // Добавляем разделитель
                                          if (items.isNotEmpty) {
                                            items.add(const PopupMenuDivider());
                                          }
                                        }
                                        
                                        // Опция для удаления участника
                                        if (!isCreator) { // Создателя нельзя удалить
                                          items.add(
                                            const PopupMenuItem<String>(
                                              value: 'remove',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Удалить из группы', style: TextStyle(color: Colors.white)),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                        
                                        return items;
                                      },
                                      color: const Color(0xFF333333),
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