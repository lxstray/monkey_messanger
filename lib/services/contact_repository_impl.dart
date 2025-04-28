import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/services/contact_repository.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

class ContactRepositoryImpl implements ContactRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ContactRepositoryImpl({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _contactsCollection =>
      _firestore.collection('contacts');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  @override
  Stream<List<ContactEntity>> getUserContacts(String userId) {
    return _contactsCollection
        .where('ownerId', isEqualTo: userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ContactEntity.fromMap({...doc.data(), 'id': doc.id}))
              .toList();
        });
  }

  @override
  Future<ContactEntity> addContact(String userId, String contactEmail) async {
    try {
      // First check if user with this email exists
      final userQuery = await _usersCollection
          .where('email', isEqualTo: contactEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('Пользователь не найден');
      }

      final contactUserData = userQuery.docs.first.data();
      final contactUserId = userQuery.docs.first.id;

      // Check if the user is trying to add themselves
      if (contactUserId == userId) {
        throw Exception('Вы не можете добавить себя в контакты');
      }

      // Check if the contact already exists
      final existingContactQuery = await _contactsCollection
          .where('ownerId', isEqualTo: userId)
          .where('contactId', isEqualTo: contactUserId)
          .get();

      if (existingContactQuery.docs.isNotEmpty) {
        throw Exception('Этот контакт уже добавлен');
      }

      // Create a new contact
      final contactId = _uuid.v4();
      final now = DateTime.now();

      final contactData = {
        'ownerId': userId,
        'contactId': contactUserId,
        'name': contactUserData['name'] ?? 'Пользователь',
        'email': contactEmail,
        'photoUrl': contactUserData['photoUrl'],
        'notes': '',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      };

      await _contactsCollection.doc(contactId).set(contactData);

      return ContactEntity.fromMap({...contactData, 'id': contactId});
    } catch (e, stackTrace) {
      AppLogger.error('Error adding contact', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateContact(ContactEntity contact) async {
    try {
      final updateData = {
        'name': contact.name,
        'notes': contact.notes,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _contactsCollection.doc(contact.id).update(updateData);
    } catch (e, stackTrace) {
      AppLogger.error('Error updating contact', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteContact(String contactId) async {
    try {
      await _contactsCollection.doc(contactId).delete();
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting contact', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<ContactEntity?> getContactById(String contactId) async {
    try {
      final doc = await _contactsCollection.doc(contactId).get();
      if (doc.exists) {
        return ContactEntity.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting contact by ID', e, stackTrace);
      rethrow;
    }
  }

  // Alias method for compatibility
  Future<ContactEntity> createContact(String name, String email, String ownerId) async {
    try {
      // First check if user with this email exists
      final userQuery = await _usersCollection
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('Пользователь не найден');
      }

      final contactUserData = userQuery.docs.first.data();
      final contactUserId = userQuery.docs.first.id;

      // Check if the user is trying to add themselves
      if (contactUserId == ownerId) {
        throw Exception('Вы не можете добавить себя в контакты');
      }

      // Check if the contact already exists
      final existingContactQuery = await _contactsCollection
          .where('ownerId', isEqualTo: ownerId)
          .where('contactId', isEqualTo: contactUserId)
          .get();

      if (existingContactQuery.docs.isNotEmpty) {
        throw Exception('Этот контакт уже добавлен');
      }

      // Create a new contact
      final contactId = _uuid.v4();
      final now = DateTime.now();

      final contactData = {
        'ownerId': ownerId,
        'contactId': contactUserId,
        'name': name,
        'email': email,
        'photoUrl': contactUserData['photoUrl'],
        'notes': '',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      };

      await _contactsCollection.doc(contactId).set(contactData);

      return ContactEntity.fromMap({...contactData, 'id': contactId});
    } catch (e, stackTrace) {
      AppLogger.error('Error creating contact', e, stackTrace);
      rethrow;
    }
  }
} 