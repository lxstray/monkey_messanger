import 'package:flutter_test/flutter_test.dart';

// Импортируем все тесты моделей
import 'models/user_entity_test.dart' as user_entity_test;
import 'models/message_entity_test.dart' as message_entity_test;
import 'models/chat_entity_test.dart' as chat_entity_test;

// Импортируем все тесты блоков
import 'blocs/auth_bloc_test.dart' as auth_bloc_test;
import 'blocs/chat_bloc_test.dart' as chat_bloc_test;

// Импортируем виджет-тесты
import 'widget_test.dart' as widget_test;

void main() {
  group('All model tests', () {
    user_entity_test.main();
    message_entity_test.main();
    chat_entity_test.main();
  });

  group('All BLoC tests', () {
    auth_bloc_test.main();
    chat_bloc_test.main();
  });

  group('All widget tests', () {
    widget_test.main();
  });
} 