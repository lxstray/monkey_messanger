import 'package:flutter_test/flutter_test.dart';
import 'package:monkey_messanger/models/user_entity.dart';

void main() {
  group('UserEntity', () {
    final DateTime now = DateTime.now();
    final testUser = UserEntity(
      id: 'test-id',
      name: 'Test User',
      email: 'test@example.com',
      photoUrl: 'https://example.com/photo.jpg',
      role: 'user',
      createdAt: now,
      lastActive: now,
      isOnline: true,
      is2faEnabled: false,
    );

    test('should create UserEntity instance correctly', () {
      expect(testUser.id, 'test-id');
      expect(testUser.name, 'Test User');
      expect(testUser.email, 'test@example.com');
      expect(testUser.photoUrl, 'https://example.com/photo.jpg');
      expect(testUser.role, 'user');
      expect(testUser.createdAt, now);
      expect(testUser.lastActive, now);
      expect(testUser.isOnline, true);
      expect(testUser.is2faEnabled, false);
    });

    test('copyWith should return a new instance with updated values', () {
      final updatedUser = testUser.copyWith(
        name: 'Updated Name',
        photoUrl: 'https://example.com/new-photo.jpg',
        isOnline: false,
        is2faEnabled: true,
      );

      // Проверяем обновленные поля
      expect(updatedUser.name, 'Updated Name');
      expect(updatedUser.photoUrl, 'https://example.com/new-photo.jpg');
      expect(updatedUser.isOnline, false);
      expect(updatedUser.is2faEnabled, true);

      // Проверяем, что остальные поля не изменились
      expect(updatedUser.id, testUser.id);
      expect(updatedUser.email, testUser.email);
      expect(updatedUser.role, testUser.role);
      expect(updatedUser.createdAt, testUser.createdAt);
      expect(updatedUser.lastActive, testUser.lastActive);
    });

    test('toMap should convert UserEntity to Map correctly', () {
      final map = testUser.toMap();

      expect(map['id'], testUser.id);
      expect(map['name'], testUser.name);
      expect(map['email'], testUser.email);
      expect(map['photoUrl'], testUser.photoUrl);
      expect(map['role'], testUser.role);
      expect(map['createdAt'], testUser.createdAt.millisecondsSinceEpoch);
      expect(map['lastActive'], testUser.lastActive.millisecondsSinceEpoch);
      expect(map['isOnline'], testUser.isOnline);
      expect(map['2faEnabled'], testUser.is2faEnabled);
    });

    test('fromMap should create UserEntity from Map correctly', () {
      final map = {
        'id': 'test-id',
        'name': 'Test User',
        'email': 'test@example.com',
        'photoUrl': 'https://example.com/photo.jpg',
        'role': 'user',
        'createdAt': now.millisecondsSinceEpoch,
        'lastActive': now.millisecondsSinceEpoch,
        'isOnline': true,
        '2faEnabled': false,
      };

      final userFromMap = UserEntity.fromMap(map);

      expect(userFromMap.id, 'test-id');
      expect(userFromMap.name, 'Test User');
      expect(userFromMap.email, 'test@example.com');
      expect(userFromMap.photoUrl, 'https://example.com/photo.jpg');
      expect(userFromMap.role, 'user');
      expect(userFromMap.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(userFromMap.lastActive.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(userFromMap.isOnline, true);
      expect(userFromMap.is2faEnabled, false);
    });

    test('fromMap with null values should set defaults', () {
      final map = <String, dynamic>{};
      final userFromMap = UserEntity.fromMap(map);

      expect(userFromMap.id, '');
      expect(userFromMap.name, '');
      expect(userFromMap.email, '');
      expect(userFromMap.photoUrl, null);
      expect(userFromMap.role, 'user');
      expect(userFromMap.isOnline, false);
      expect(userFromMap.is2faEnabled, false);
    });

    test('props should return a list containing all properties', () {
      expect(testUser.props, [
        testUser.id,
        testUser.name,
        testUser.email,
        testUser.photoUrl,
        testUser.role,
        testUser.createdAt,
        testUser.lastActive,
        testUser.isOnline,
        testUser.is2faEnabled,
      ]);
    });

    test('identical UserEntity instances should be equal', () {
      final user1 = UserEntity(
        id: 'test-id',
        name: 'Test User',
        email: 'test@example.com',
        photoUrl: 'https://example.com/photo.jpg',
        role: 'user',
        createdAt: now,
        lastActive: now,
        isOnline: true,
        is2faEnabled: false,
      );

      final user2 = UserEntity(
        id: 'test-id',
        name: 'Test User',
        email: 'test@example.com',
        photoUrl: 'https://example.com/photo.jpg',
        role: 'user',
        createdAt: now,
        lastActive: now,
        isOnline: true,
        is2faEnabled: false,
      );

      expect(user1, equals(user2));
    });

    test('UserEntity instances with different properties should not be equal', () {
      final user1 = UserEntity(
        id: 'test-id-1',
        name: 'Test User 1',
        email: 'test1@example.com',
        photoUrl: 'https://example.com/photo1.jpg',
        role: 'user',
        createdAt: now,
        lastActive: now,
        isOnline: true,
        is2faEnabled: false,
      );

      final user2 = UserEntity(
        id: 'test-id-2',
        name: 'Test User 2',
        email: 'test2@example.com',
        photoUrl: 'https://example.com/photo2.jpg',
        role: 'admin',
        createdAt: now,
        lastActive: now,
        isOnline: false,
        is2faEnabled: true,
      );

      expect(user1, isNot(equals(user2)));
    });
  });
} 