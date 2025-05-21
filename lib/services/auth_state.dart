import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:monkey_messanger/models/user_entity.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
  passwordResetSent,
  requiresTwoFactor,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;
  final bool isNewUser;
  final String? email; 

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.isNewUser = false,
    this.email,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
    bool? isNewUser,
    String? email,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isNewUser: isNewUser ?? this.isNewUser,
      email: email ?? this.email,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get hasError => status == AuthStatus.error;
  bool get isPasswordResetSent => status == AuthStatus.passwordResetSent;
  bool get isTwoFactorRequired => status == AuthStatus.requiresTwoFactor;

  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.initial);
  }

  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading);
  }

  factory AuthState.authenticated(UserEntity user, {bool isNewUser = false}) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      isNewUser: isNewUser,
    );
  }

  factory AuthState.unauthenticated() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  factory AuthState.error(String message) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
    );
  }

  factory AuthState.passwordResetSent() {
    return const AuthState(status: AuthStatus.passwordResetSent);
  }
  
  factory AuthState.requiresTwoFactor(String email) {
    return AuthState(
      status: AuthStatus.requiresTwoFactor,
      email: email,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, isNewUser, email];
}

extension FirebaseAuthExceptionExtension on FirebaseAuthException {
  String get friendlyMessage {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'email-already-in-use':
        return 'This email is already in use by another account.';
      case 'operation-not-allowed':
        return 'This sign-in method is not allowed.';
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many sign-in attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'ERROR_ABORTED_BY_USER':
        return 'Sign-in cancelled by user.';
      default:
        return message ?? 'An unknown error occurred.';
    }
  }
} 