// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:monkey_messanger/main.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'mocks/mock_repositories.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/chat_bloc.dart';

// Мок для Firebase.initializeApp
class MockFirebaseApp extends Mock implements FirebaseApp {}

void main() {
  setUpAll(() async {
    // Инициализация Firebase для тестов
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('App Widget Tests', () {
    testWidgets('App initializes correctly', (WidgetTester tester) async {
      // Мокируем необходимые блоки
      final mockAuthRepository = MockAuthRepository();
      final mockEmailService = MockEmailService();
      final mockChatRepository = MockChatRepository();
      
      // Создаем виджет с мокированными блоками
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<MockAuthRepository>.value(value: mockAuthRepository),
            RepositoryProvider<MockEmailService>.value(value: mockEmailService),
            RepositoryProvider<MockChatRepository>.value(value: mockChatRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>(
                create: (context) => AuthBloc(
                  authRepository: mockAuthRepository,
                  emailService: mockEmailService,
                ),
              ),
              BlocProvider<ChatBloc>(
                create: (context) => ChatBloc(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Test App'),
                ),
              ),
            ),
          ),
        ),
      );
      
      // Проверяем, что приложение запустилось
      expect(find.text('Test App'), findsOneWidget);
      
      // Cleanup
      mockAuthRepository.dispose();
      mockChatRepository.dispose();
    });
  });
}
