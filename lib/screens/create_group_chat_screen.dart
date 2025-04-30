import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/services/chat_repository_impl.dart';
import 'package:monkey_messanger/services/contact_repository_impl.dart';
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
  final List<ContactEntity> _selectedContacts = [];
  List<ContactEntity> _availableContacts = [];
  Map<String, UserEntity> _contactsUserData = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }
  
  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final contactRepository = ContactRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      );
      
      final contactsSnapshot = await contactRepository
          .getUserContacts(widget.currentUser.id)
          .first;
          
      final contactUserIds = contactsSnapshot.map((c) => c.contactId).toList();
      Map<String, UserEntity> usersData = {};
      if (contactUserIds.isNotEmpty) {
        usersData = await contactRepository.getUsersByIds(contactUserIds);
      }

      if (mounted) {
        setState(() {
          _availableContacts = contactsSnapshot;
          _contactsUserData = usersData;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading contacts or user data', e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при загрузке контактов: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleContactSelection(ContactEntity contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
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

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

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
      
      final participantIds = _selectedContacts.map((contact) => contact.contactId).toList();
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
      timeoutFuture.timeout(Duration.zero, onTimeout: () {}).catchError((_) {});
      
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
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
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
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                )
              : _availableContacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 56,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'У вас нет контактов',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 17,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Добавьте контакты в разделе "Контакты"',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _groupNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'Название группы',
                              hintText: 'Введите название группы',
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF4A90E2)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Выберите участников:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _availableContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _availableContacts[index];
                                final isSelected = _selectedContacts.contains(contact);
                                final contactUser = _contactsUserData[contact.contactId];
                                final displayPhotoUrl = contactUser?.photoUrl ?? contact.photoUrl;
                                
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  title: Text(
                                    contact.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    contact.email,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  leading: CircleAvatar(
                                    radius: 20,
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
                                                style: const TextStyle(
                                                    color: Colors.white, fontSize: 16),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 16),
                                          ),
                                  ),
                                  trailing: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? const Color(0xFF4A90E2)
                                        : Colors.white70,
                                    size: 22,
                                  ),
                                  onTap: () => _toggleContactSelection(contact),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _createGroupChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              disabledBackgroundColor: const Color(0xFF4A90E2).withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Создать группу',
                              style: TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
} 