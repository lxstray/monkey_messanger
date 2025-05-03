import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/models/message_entity.dart';
import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/services/auth_repository.dart';
import 'package:monkey_messanger/services/chat_repository.dart';
import 'package:monkey_messanger/services/contact_repository.dart';
import 'package:monkey_messanger/services/email_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Мок для UserCredential, т.к. он не совсем абстрактный и его сложно замокать напрямую
class MockUserCredential extends Mock implements UserCredential {
  @override
  final User? user;

  MockUserCredential({this.user});
}

// Мок для User из FirebaseAuth
class MockUser extends Mock implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;

  MockUser({this.uid = 'test-user-id', this.email, this.displayName, this.photoURL});

  @override
  Future<void> updateDisplayName(String? displayName) async {
    return;
  }
}

// Мок для AuthRepository
class MockAuthRepository extends Mock implements AuthRepository {
  final _authStateController = StreamController<User?>.broadcast();
  MockUser? _currentUser;
  bool _is2faEnabled = false;
  String? _validEmail; // Для проверки логина
  String? _validPassword; // Для проверки логина
  UserEntity? _mockUserEntity; // Для возврата из getCurrentUser
  
  @override
  Stream<User?> get authStateChanges => _authStateController.stream;
  
  // Метод для настройки мока
  void configure({
    required String validEmail,
    required String validPassword,
    required UserEntity userEntity,
    bool is2faEnabled = false,
  }) {
    _validEmail = validEmail;
    _validPassword = validPassword;
    _mockUserEntity = userEntity; // Сохраняем UserEntity для getCurrentUser
    _is2faEnabled = is2faEnabled;
    // Создаем MockUser на основе UserEntity
    _currentUser = MockUser(
      uid: userEntity.id,
      email: userEntity.email,
      displayName: userEntity.name,
      photoURL: userEntity.photoUrl,
    );
  }

  // Метод для сброса состояния мока
  void reset() {
    _currentUser = null;
    _is2faEnabled = false;
    _validEmail = null;
    _validPassword = null;
    _mockUserEntity = null;
    // Не очищаем контроллер, если подписчики еще есть
    if (!_authStateController.hasListener) {
       // _authStateController = StreamController<User?>.broadcast(); // Пересоздание может быть опасным
    }
  }
  
  void emitAuthState(User? user) {
    _currentUser = user as MockUser?;
    _authStateController.add(user);
  }
  
  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    if (email == _validEmail && password == _validPassword) {
      // Используем _currentUser, созданный в configure
      if (_currentUser == null) {
         // На всякий случай, если configure не был вызван
         _currentUser = MockUser(uid: 'fallback-id', email: email);
      }
      // Не вызываем emitAuthState здесь, так как BLoC сам обработает UserCredential
      return MockUserCredential(user: _currentUser);
    } else {
      throw FirebaseAuthException(code: 'user-not-found'); // Или wrong-password
    }
  }
  
  @override
  Future<UserCredential> signInWithGoogle() async {
    // Для этого теста можно вернуть ошибку или успешный вход без 2FA
    // _currentUser = MockUser(); // Пример успешного входа
    // return MockUserCredential(user: _currentUser);
    throw UnimplementedError('Google Sign-In mock not fully configured for this test');
  }
  
  @override
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    // Для этого теста можно вернуть ошибку или успешное создание без 2FA
    // _currentUser = MockUser(uid: 'new-user-id', email: email);
    // return MockUserCredential(user: _currentUser);
    throw UnimplementedError('Sign Up mock not fully configured for this test');
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _is2faEnabled = false; // Сбрасываем 2FA при выходе
    _mockUserEntity = null;
    emitAuthState(null);
  }
  
  @override
  Future<UserEntity?> getCurrentUser() async {
    // Возвращаем UserEntity, сохраненный при конфигурации
    // или созданный на основе _currentUser, если он есть
    if (_mockUserEntity != null && _currentUser != null && _currentUser!.uid == _mockUserEntity!.id) {
      // Обновляем состояние 2FA из _is2faEnabled
      return _mockUserEntity!.copyWith(is2faEnabled: _is2faEnabled);
    } else if (_currentUser != null) {
      // Фоллбэк, если configure не вызывался, но _currentUser есть
      return UserEntity(
        id: _currentUser!.uid,
        name: _currentUser!.displayName ?? '',
        email: _currentUser!.email ?? '',
        photoUrl: _currentUser!.photoURL,
        role: 'user',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastActive: DateTime.now(),
        isOnline: true,
        is2faEnabled: _is2faEnabled,
      );
    }
    return null;
  }
  
  @override
  Future<bool> isTwoFactorAuthEnabled() async {
    // Этот метод вызывается AuthBloc *после* успешного входа,
    // чтобы определить, нужен ли экран 2FA.
    // Он должен возвращать состояние, актуальное для _currentUser.
    return _is2faEnabled;
  }
  
  @override
  Future<void> enableTwoFactorAuth() async {
    _is2faEnabled = true;
  }
  
  @override
  Future<void> disableTwoFactorAuth() async {
    _is2faEnabled = false;
  }
  
  @override
  Future<void> resetPassword(String email) async {
    if (email == 'error@example.com') {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    return;
  }
  
  @override
  Future<void> updatePassword(String newPassword) async {
    return;
  }
  
  @override
  Future<void> deleteUser() async {
    _currentUser = null;
    emitAuthState(null);
  }
  
  void dispose() {
    _authStateController.close();
  }
}

// Мок для EmailService
class MockEmailService extends Mock implements EmailService {
  @override
  Future<bool> sendVerificationCode(String email) async {
    if (email == 'error@example.com') {
      return false;
    }
    return true;
  }
  
  @override
  Future<bool> verifyCode(String email, String code) async {
    if (code == '123456') {
      return true;
    }
    return false;
  }
}

// Мок для ChatRepository
class MockChatRepository extends Mock implements ChatRepository {
  final _chatsController = StreamController<List<ChatEntity>>.broadcast();
  final _messagesController = StreamController<List<MessageEntity>>.broadcast();
  final _chatController = StreamController<ChatEntity?>.broadcast();
  
  final List<ChatEntity> _chats = [];
  final Map<String, List<MessageEntity>> _messages = {};
  
  @override
  Stream<List<ChatEntity>> getUserChats(String userId) {
    return _chatsController.stream;
  }
  
  @override
  Stream<List<MessageEntity>> getChatMessages(String chatId, {int limit = 50}) {
    return _messagesController.stream;
  }
  
  @override
  Stream<ChatEntity?> getChatById(String chatId) {
    return _chatController.stream;
  }
  
  void emitChats(List<ChatEntity> chats) {
    _chats.clear();
    _chats.addAll(chats);
    _chatsController.add(_chats);
  }
  
  void emitMessages(String chatId, List<MessageEntity> messages) {
    _messages[chatId] = messages;
    _messagesController.add(messages);
  }
  
  void emitChat(ChatEntity? chat) {
    _chatController.add(chat);
  }
  
  @override
  Future<MessageEntity> sendTextMessage(String chatId, String senderId, String text) async {
    final message = MessageEntity.text(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );
    
    if (!_messages.containsKey(chatId)) {
      _messages[chatId] = [];
    }
    
    _messages[chatId]!.add(message);
    _messagesController.add(_messages[chatId]!);
    
    return message;
  }
  
  @override
  Future<void> deleteMessage(String messageId, String chatId) async {
    if (_messages.containsKey(chatId)) {
      _messages[chatId] = _messages[chatId]!.where((m) => m.id != messageId).toList();
      _messagesController.add(_messages[chatId]!);
    }
  }
  
  @override
  Future<void> editTextMessage(String messageId, String chatId, String newText) async {
    if (_messages.containsKey(chatId)) {
      final index = _messages[chatId]!.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final message = _messages[chatId]![index];
        _messages[chatId]![index] = message.copyWith(text: newText, isEdited: true);
        _messagesController.add(_messages[chatId]!);
      }
    }
  }
  
  void dispose() {
    _chatsController.close();
    _messagesController.close();
    _chatController.close();
  }
}

// Мок для ContactRepository
class MockContactRepository extends Mock implements ContactRepository {
  final List<ContactEntity> _contacts = [];
  
  @override
  Stream<List<ContactEntity>> getUserContacts(String userId) {
    return Stream.value(_contacts);
  }

  @override
  Future<ContactEntity> addContact(String userId, String contactEmail) async {
    final contact = ContactEntity(
      id: 'contact-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: userId,
      contactId: 'contact-user-id',
      name: 'Test Contact',
      email: contactEmail,
      photoUrl: 'https://example.com/contact.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _contacts.add(contact);
    return contact;
  }
  
  @override
  Future<ContactEntity> createContact(String name, String email, String ownerId) async {
    final contact = ContactEntity(
      id: 'contact-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: ownerId,
      contactId: 'contact-user-id',
      name: name,
      email: email,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _contacts.add(contact);
    return contact;
  }
  
  @override
  Future<void> updateContact(ContactEntity contact) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      _contacts[index] = contact;
    }
  }
  
  @override
  Future<void> deleteContact(String contactId) async {
    _contacts.removeWhere((c) => c.id == contactId);
  }
  
  @override
  Future<ContactEntity?> getContactById(String contactId) async {
    return _contacts.firstWhere((c) => c.id == contactId, orElse: () => throw Exception('Contact not found'));
  }
  
  @override
  Future<Map<String, UserEntity>> getUsersByIds(List<String> userIds) async {
    return {
      for (final id in userIds)
        id: UserEntity(
          id: id,
          name: 'User $id',
          email: 'user$id@example.com',
          role: 'user',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          lastActive: DateTime.now(),
          isOnline: true,
        )
    };
  }
  
  void setContacts(List<ContactEntity> contacts) {
    _contacts.clear();
    _contacts.addAll(contacts);
  }
}

// Мок для SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {
  final Map<String, Object> _data = {};
  
  @override
  String? getString(String key) {
    return _data[key] as String?;
  }
  
  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }
  
  @override
  bool containsKey(String key) {
    return _data.containsKey(key);
  }
} 