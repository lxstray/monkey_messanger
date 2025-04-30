import 'package:flutter/material.dart';
import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/services/chat_repository_impl.dart';
import 'package:monkey_messanger/services/contact_repository_impl.dart';
import 'package:monkey_messanger/services/contact_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:monkey_messanger/screens/chat_screen.dart';
import 'package:monkey_messanger/services/chat_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/utils/app_logger.dart';

class ContactEditScreen extends StatefulWidget {
  final ContactEntity contact;
  final UserEntity currentUser;

  const ContactEditScreen({
    Key? key,
    required this.contact,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends State<ContactEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  bool _isLoading = true;
  String _errorMessage = '';
  UserEntity? _contactUserEntity;

  final ContactRepository _contactRepository = ContactRepositoryImpl(
    firestore: FirebaseFirestore.instance,
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _notesController = TextEditingController(text: widget.contact.notes ?? '');
    _loadContactUserData();
  }

  Future<void> _loadContactUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final usersMap = await _contactRepository.getUsersByIds([widget.contact.contactId]);
      if (mounted) {
        setState(() {
          _contactUserEntity = usersMap[widget.contact.contactId];
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading contact user data', e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Не удалось загрузить данные контакта: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Имя контакта не может быть пустым'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final updatedContact = widget.contact.copyWith(
        name: _nameController.text.trim(),
        notes: _notesController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await _contactRepository.updateContact(updatedContact);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка сохранения: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _messageContact() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final chatRepository = ChatRepositoryImpl(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      final chatEntity = await chatRepository.createPrivateChat(
        widget.currentUser.id,
        widget.contact.contactId,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        context.read<ChatBloc>().add(LoadMessagesEvent(chatEntity.id));
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatEntity.id,
              chatName: chatEntity.name,
              currentUser: widget.currentUser,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка создания чата: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPhotoUrl = widget.contact.photoUrl ?? _contactUserEntity?.photoUrl;
    final displayName = widget.contact.name;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Редактирование контакта',
          style: TextStyle(color: Colors.white),
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF4A90E2),
                      child: displayPhotoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                displayPhotoUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Имя контакта',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Введите имя контакта',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4A90E2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Заметки',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Добавьте заметки о контакте',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4A90E2)),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email: ${widget.contact.email}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveContact,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Сохранить',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _messageContact,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.message, color: Colors.white),
                          label: const Text(
                            'Написать сообщение',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
} 