import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:monkey_messanger/services/contact_repository_impl.dart';
import 'package:monkey_messanger/services/contact_repository.dart';
import 'package:monkey_messanger/screens/contact_edit_screen.dart';
import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/models/user_entity.dart';

class ContactsScreen extends StatefulWidget {
  final Function(String) onAddContactPressed;
  
  const ContactsScreen({
    super.key, 
    required this.onAddContactPressed,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactRepository _contactRepository = ContactRepositoryImpl(
    firestore: FirebaseFirestore.instance,
  );

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthBloc>().state.user;
    
    if (currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4A90E2),
        ),
      );
    }
    
    return StreamBuilder<List<ContactEntity>>(
      stream: _contactRepository.getUserContacts(currentUser.id),
      builder: (context, contactSnapshot) {
        if (contactSnapshot.hasError) {
          return Center(
            child: Text(
              'Ошибка: ${contactSnapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (contactSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4A90E2),
            ),
          );
        }

        final contacts = contactSnapshot.data ?? [];

        if (contacts.isEmpty) {
          return Center(
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
                  'Контакты не найдены',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => widget.onAddContactPressed(currentUser.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  ),
                  icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
                  label: const Text(
                    'Добавить контакт',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }
        
        final contactUserIds = contacts.map((c) => c.contactId).toList();
        
        return FutureBuilder<Map<String, UserEntity>>(
          future: _contactRepository.getUsersByIds(contactUserIds),
          builder: (context, userSnapshot) {
            
            if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4A90E2),
                ),
              );
            }

            if (userSnapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка загрузки данных пользователей: ${userSnapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            
            final userDataMap = userSnapshot.data ?? {};

            return ListView.separated(
              itemCount: contacts.length,
              separatorBuilder: (context, index) => Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: 0.8,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                final userEntity = userDataMap[contact.contactId];
                
                final displayPhotoUrl = contact.photoUrl ?? userEntity?.photoUrl;

                Widget leadingWidget;
                if (displayPhotoUrl != null) {
                  leadingWidget = ClipOval(
                    child: Image.network(
                      displayPhotoUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return CircleAvatar(
                          backgroundColor: const Color(0xFF4A90E2),
                          radius: 22,
                          child: Text(
                            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
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
                    radius: 22,
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                return Dismissible(
                  key: Key(contact.id),
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
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          content: Text(
                            'Вы уверены, что хотите удалить контакт "${contact.name}"?',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text(
                                'Отмена',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) async {
                    try {
                      await _contactRepository.deleteContact(contact.id);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Контакт "${contact.name}" удален'),
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
                            content: Text('Ошибка при удалении контакта: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: leadingWidget,
                    title: Text(
                      contact.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      contact.email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 22,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContactEditScreen(
                            contact: contact,
                            currentUser: currentUser,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
} 