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
  final FocusNode _groupNameFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  List<ContactEntity> _userContacts = [];
  bool _loadingContacts = false;
  
  late final ChatRepositoryImpl _chatRepository;
  Stream<ChatEntity?>? _chatStream;
  ChatEntity? _currentChatEntity;
  
  final StorageService _storageService = StorageService();

  bool get _isAdmin => (_currentChatEntity ?? widget.chatEntity).isAdmin(widget.currentUser.id);

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
    
    _currentChatEntity = widget.chatEntity;
    _groupNameController.text = widget.chatEntity.name;
    
    _chatStream = _chatRepository.getChatById(widget.chatId);
    
    _loadChatParticipants();
    
    if (_isAdmin) {
      _loadUserContacts();
    }
  }
  
  @override
  void dispose() {
    _groupNameController.dispose();
    _groupNameFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserContacts() async {
    setState(() {
      _loadingContacts = true;
    });
    
    try {
      final contactRepository = ContactRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      );
      
      final contactsStream = contactRepository.getUserContacts(widget.currentUser.id);
      
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

      for (final userId in (_currentChatEntity ?? widget.chatEntity).participantIds) {
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

    if (_groupNameController.text.trim() == (_currentChatEntity ?? widget.chatEntity).name) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _chatRepository.updateGroupChatName(
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
      final imageUrl = await _storageService.uploadImage(
        _selectedImage!, 
        widget.chatId
      );
      
      if (imageUrl.isEmpty) {
        throw Exception('Не удалось загрузить изображение');
      }

      await _chatRepository.updateGroupChatImage(widget.chatId, imageUrl);

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
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000, 
        maxHeight: 1000,
        imageQuality: 85, 
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
      await _chatRepository.removeUserFromGroupChat(widget.chatId, userId);

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
  
  Future<void> _toggleUserAdmin(String userId, bool makeAdmin) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только администратор может управлять правами')),
      );
      return;
    }
    
    if (userId == (_currentChatEntity ?? widget.chatEntity).createdBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Невозможно изменить права создателя группы')),
      );
      return;
    }
    
    final user = _chatParticipants.firstWhere((user) => user.id == userId);
    
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
      if (makeAdmin) {
        await _chatRepository.addGroupAdmin(widget.chatId, widget.currentUser.id, userId);
      } else {
        await _chatRepository.removeGroupAdmin(widget.chatId, widget.currentUser.id, userId);
      }

      if (mounted) {
        Navigator.pop(context, true); 
        
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
      return !(_currentChatEntity ?? widget.chatEntity).participantIds.contains(contact.contactId);
    }).toList();
    
    if (availableContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все ваши контакты уже добавлены в группу')),
      );
      return;
    }

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
      return;
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
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableContacts.length,
              itemBuilder: (context, index) {
                final contact = availableContacts[index];
                final contactUser = availableContactsUserData[contact.contactId];
                final displayPhotoUrl = contactUser?.photoUrl ?? contact.photoUrl;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4A90E2),
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
      await _chatRepository.addUserToGroupChat(widget.chatId, selectedContact.contactId);

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
      await _chatRepository.leaveGroupChat(widget.chatId, widget.currentUser.id);

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
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<ChatEntity?>(
        stream: _chatStream,
        initialData: widget.chatEntity,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            _currentChatEntity = snapshot.data;
            
            if (!_isLoading && !_participantsMatch(snapshot.data!.participantIds)) {
              Future.microtask(() => _loadChatParticipants());
            }
            
            if (!_groupNameFocusNode.hasFocus && _groupNameController.text != snapshot.data!.name) {
              _groupNameController.text = snapshot.data!.name;
            }
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ошибка загрузки данных чата: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          
          return _buildBody();
        },
      ),
    );
  }
  
  bool _participantsMatch(List<String> newParticipantIds) {
    if (newParticipantIds.length != _chatParticipants.length) {
      return false;
    }
    
    final currentParticipantIds = _chatParticipants.map((user) => user.id).toList();
    for (final id in newParticipantIds) {
      if (!currentParticipantIds.contains(id)) {
        return false;
      }
    }
    
    return true;
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4A90E2),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadChatParticipants,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                ),
                child: const Text('Повторить', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: _isAdmin ? _pickImage : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFF4A90E2),
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (_currentChatEntity ?? widget.chatEntity).imageUrl != null
                            ? NetworkImage((_currentChatEntity ?? widget.chatEntity).imageUrl!) as ImageProvider<Object>
                            : null,
                    child: (_currentChatEntity ?? widget.chatEntity).imageUrl == null && _selectedImage == null
                        ? Text(
                            (_currentChatEntity ?? widget.chatEntity).name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
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
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_isAdmin)
            TextField(
              controller: _groupNameController,
              focusNode: _groupNameFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Название группы',
                labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4A90E2)),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save, color: Color(0xFF4A90E2), size: 22),
                  onPressed: _updateGroupName,
                ),
              ),
            )
          else
            Card(
              color: const Color(0xFF2A2A2A),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: const Text(
                  'Название группы',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                subtitle: Text(
                  (_currentChatEntity ?? widget.chatEntity).name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),

          Card(
            color: const Color(0xFF2A2A2A),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: const Text(
                'Создатель группы',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              subtitle: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc((_currentChatEntity ?? widget.chatEntity).createdBy)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text(
                      'Загрузка...',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    );
                  }
                  
                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return const Text(
                      'Неизвестно',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    );
                  }
                  
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  return Text(
                    data['name'] ?? 'Неизвестно',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Участники',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.person_add, color: Color(0xFF4A90E2), size: 22),
                  onPressed: _addUserToGroup,
                  tooltip: 'Добавить участника',
                ),
            ],
          ),
          const SizedBox(height: 6),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chatParticipants.length,
            itemBuilder: (context, index) {
              final participant = _chatParticipants[index];
              final isCreator = participant.id == (_currentChatEntity ?? widget.chatEntity).createdBy;
              final isParticipantAdmin = (_currentChatEntity ?? widget.chatEntity).isAdmin(participant.id);
              
              return Card(
                color: const Color(0xFF2A2A2A),
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF4A90E2),
                    backgroundImage: participant.photoUrl != null
                        ? NetworkImage(participant.photoUrl!)
                        : null,
                    child: participant.photoUrl == null
                        ? Text(
                            participant.name.isNotEmpty ? participant.name.substring(0, 1).toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        participant.name,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      if (isParticipantAdmin)
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: Icon(
                            isCreator ? Icons.star : Icons.admin_panel_settings,
                            color: isCreator ? Colors.yellow : Colors.green,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    participant.email,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                  trailing: participant.id != widget.currentUser.id && _isAdmin
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
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
                            
                            if (!isCreator) { 
                              if (isParticipantAdmin) {
                                items.add(
                                  const PopupMenuItem<String>(
                                    value: 'remove_admin',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove, color: Colors.red, size: 18),
                                        SizedBox(width: 8),
                                        Text('Снять админа', style: TextStyle(color: Colors.white, fontSize: 14)),
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
                                        Icon(Icons.admin_panel_settings, color: Colors.green, size: 18),
                                        SizedBox(width: 8),
                                        Text('Сделать админом', style: TextStyle(color: Colors.white, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              if (items.isNotEmpty) {
                                items.add(const PopupMenuDivider());
                              }
                            }
                            
                            if (!isCreator) { 
                              items.add(
                                const PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Удалить из группы', style: TextStyle(color: Colors.white, fontSize: 14)),
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
          const SizedBox(height: 20),

          Center(
            child: ElevatedButton.icon(
              onPressed: _leaveGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.exit_to_app, size: 20),
              label: const Text('Покинуть группу', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedImage != null && _isAdmin)
            Center(
              child: ElevatedButton.icon(
                onPressed: _updateGroupImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.save, size: 20),
                label: const Text('Сохранить изображение', style: TextStyle(fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }
} 