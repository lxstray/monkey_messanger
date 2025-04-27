import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:monkey_messanger/services/auth_state.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monkey Messenger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutEvent());
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Здесь будет список чатов'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Показываем диалог создания нового чата
          _showNewChatDialog(context, currentUser?.id ?? '');
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context, String currentUserId) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Новый чат'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email пользователя',
                  hintText: 'Введите email пользователя',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  // TODO: Implement chat creation with the user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Создание чата с $email: будет реализовано в следующем обновлении'),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
  }
} 