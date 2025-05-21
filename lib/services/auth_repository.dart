import 'package:firebase_auth/firebase_auth.dart';
import 'package:monkey_messanger/models/user_entity.dart';

abstract class AuthRepository {
  Future<UserCredential> signInWithEmailAndPassword(String email, String password);
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String newPassword);
  
  Stream<User?> get authStateChanges;
  Future<UserEntity?> getCurrentUser();
  Future<void> saveUserData(UserEntity user);
  Future<void> updateUserData(UserEntity user);
  Future<void> updateUserOnlineStatus(bool isOnline);
  Future<void> deleteUser();
  
  Future<void> enableTwoFactorAuth();
  Future<void> disableTwoFactorAuth();
  Future<bool> isTwoFactorAuthEnabled();
} 