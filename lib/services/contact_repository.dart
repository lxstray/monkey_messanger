import 'package:monkey_messanger/models/contact_entity.dart';
import 'package:monkey_messanger/models/user_entity.dart';

abstract class ContactRepository {
  Stream<List<ContactEntity>> getUserContacts(String userId);
  Future<ContactEntity> addContact(String userId, String contactEmail);
  Future<ContactEntity> createContact(String name, String email, String ownerId);
  Future<void> updateContact(ContactEntity contact);
  Future<void> deleteContact(String contactId);
  Future<ContactEntity?> getContactById(String contactId);
  Future<Map<String, UserEntity>> getUsersByIds(List<String> userIds);
} 