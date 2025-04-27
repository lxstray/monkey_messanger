import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/services/auth_repository.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final SharedPreferences _prefs;

  AuthRepositoryImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
    required SharedPreferences prefs,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _googleSignIn = googleSignIn,
        _prefs = prefs;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final user = UserEntity(
          id: credential.user!.uid,
          name: credential.user!.displayName ?? email.split('@')[0],
          email: email,
          role: AppConstants.userRole,
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
          isOnline: true,
        );
        
        await saveUserData(user);
      }
      
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error creating user with email and password', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore.collection(AppConstants.usersCollection).doc(user.uid).delete();
        await user.delete();
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error deleting user', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> disableTwoFactorAuth() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore.collection(AppConstants.usersCollection).doc(user.uid).update({
          '2faEnabled': false,
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error disabling 2FA', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> enableTwoFactorAuth() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore.collection(AppConstants.usersCollection).doc(user.uid).update({
          '2faEnabled': true,
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error enabling 2FA', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection(AppConstants.usersCollection).doc(user.uid).get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Обработка Timestamp для createdAt и lastActive
          final createdAt = data['createdAt'];
          final lastActive = data['lastActive'];
          
          DateTime createdAtDate;
          DateTime lastActiveDate;
          
          if (createdAt is Timestamp) {
            createdAtDate = createdAt.toDate();
          } else if (createdAt is int) {
            createdAtDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
          } else {
            createdAtDate = DateTime.now();
          }
          
          if (lastActive is Timestamp) {
            lastActiveDate = lastActive.toDate();
          } else if (lastActive is int) {
            lastActiveDate = DateTime.fromMillisecondsSinceEpoch(lastActive);
          } else {
            lastActiveDate = DateTime.now();
          }
          
          return UserEntity(
            id: user.uid,
            name: data['name'] ?? user.displayName ?? 'User',
            email: data['email'] ?? user.email ?? '',
            photoUrl: data['photoUrl'] ?? user.photoURL,
            role: data['role'] ?? AppConstants.userRole,
            createdAt: createdAtDate,
            lastActive: lastActiveDate,
            isOnline: data['isOnline'] ?? false,
          );
        } else {
          // Пользователь аутентифицирован через Firebase Auth, но данные в Firestore отсутствуют
          // Создаем новую запись пользователя
          final newUser = UserEntity(
            id: user.uid,
            name: user.displayName ?? user.email?.split('@')[0] ?? 'User',
            email: user.email ?? '',
            photoUrl: user.photoURL,
            role: AppConstants.userRole,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            isOnline: true,
          );
          
          // Сохраняем данные нового пользователя
          await saveUserData(newUser);
          return newUser;
        }
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting current user', e, stackTrace);
      return null;
    }
  }

  @override
  Future<bool> isTwoFactorAuthEnabled() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection(AppConstants.usersCollection).doc(user.uid).get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          return data['2faEnabled'] ?? false;
        }
      }
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Error checking 2FA status', e, stackTrace);
      return false;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error resetting password', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> saveUserData(UserEntity user) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(user.id).set(user.toMap());
      
      // Save some user data locally
      await _prefs.setString(AppConstants.userIdKey, user.id);
      await _prefs.setString(AppConstants.userEmailKey, user.email);
      await _prefs.setString(AppConstants.userNameKey, user.name);
      await _prefs.setString(AppConstants.userRoleKey, user.role);
    } catch (e, stackTrace) {
      AppLogger.error('Error saving user data', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        await updateUserOnlineStatus(true);
      }
      
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error signing in with email and password', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Check if user already exists in database
        final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(userCredential.user!.uid).get();
        
        if (!userDoc.exists) {
          // Create new user entity
          final newUser = UserEntity(
            id: userCredential.user!.uid,
            name: userCredential.user!.displayName ?? googleUser.email.split('@')[0],
            email: userCredential.user!.email!,
            photoUrl: userCredential.user!.photoURL,
            role: AppConstants.userRole,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            isOnline: true,
          );
          
          await saveUserData(newUser);
        } else {
          await updateUserOnlineStatus(true);
        }
      }
      
      return userCredential;
    } catch (e, stackTrace) {
      AppLogger.error('Error signing in with Google', e, stackTrace);
      if (e is FirebaseAuthException) {
        rethrow;
      }
      throw FirebaseAuthException(
        code: 'ERROR_GOOGLE_SIGN_IN',
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await updateUserOnlineStatus(false);
      
      await _prefs.remove(AppConstants.userIdKey);
      await _prefs.remove(AppConstants.userEmailKey);
      await _prefs.remove(AppConstants.userNameKey);
      await _prefs.remove(AppConstants.userRoleKey);
      
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e, stackTrace) {
      AppLogger.error('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error updating password', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateUserData(UserEntity user) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(user.id).update(user.toMap());
    } catch (e, stackTrace) {
      AppLogger.error('Error updating user data', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateUserOnlineStatus(bool isOnline) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore.collection(AppConstants.usersCollection).doc(user.uid).update({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error updating user online status', e, stackTrace);
      // Don't rethrow, as this is a background operation
    }
  }
} 