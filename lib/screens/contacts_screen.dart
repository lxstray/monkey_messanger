import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:monkey_messanger/services/contact_repository_impl.dart';
import 'package:monkey_messanger/screens/contact_edit_screen.dart';
import 'package:monkey_messanger/models/contact_entity.dart';

class ContactsScreen extends StatelessWidget {
  final Function(String) onAddContactPressed;
  
  const ContactsScreen({
    super.key, 
    required this.onAddContactPressed,
  });

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
      stream: ContactRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      ).getUserContacts(currentUser.id),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Контакты не найдены',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => onAddContactPressed(currentUser.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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

        return ListView.separated(
          itemCount: contacts.length,
          separatorBuilder: (context, index) => Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 1,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          itemBuilder: (context, index) {
            final contact = contacts[index];
            
            Widget leadingWidget;
            if (contact.photoUrl != null) {
              leadingWidget = ClipOval(
                child: Image.network(
                  contact.photoUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return CircleAvatar(
                      backgroundColor: const Color(0xFF4A90E2),
                      radius: 25,
                      child: Text(
                        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
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
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        'Вы уверены, что хотите удалить контакт "${contact.name}"?',
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
                  final contactRepository = ContactRepositoryImpl(
                    firestore: FirebaseFirestore.instance,
                  );
                  
                  await contactRepository.deleteContact(contact.id);
                  
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: leadingWidget,
                title: Text(
                  contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  contact.email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
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
  }
} 