import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckStatusEvent extends AuthEvent {
  const AuthCheckStatusEvent();
}

class AuthSignInWithEmailPasswordEvent extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInWithEmailPasswordEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthSignInWithGoogleEvent extends AuthEvent {
  const AuthSignInWithGoogleEvent();
}

class AuthSignUpWithEmailPasswordEvent extends AuthEvent {
  final String name;
  final String email;
  final String password;

  const AuthSignUpWithEmailPasswordEvent({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [name, email, password];
}

class AuthSignOutEvent extends AuthEvent {
  const AuthSignOutEvent();
}

class AuthResetPasswordEvent extends AuthEvent {
  final String email;

  const AuthResetPasswordEvent({
    required this.email,
  });

  @override
  List<Object?> get props => [email];
}

class AuthUpdateUserEvent extends AuthEvent {
  final String? name;
  final String? photoUrl;

  const AuthUpdateUserEvent({
    this.name,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [name, photoUrl];
}

class AuthUpdatePasswordEvent extends AuthEvent {
  final String newPassword;

  const AuthUpdatePasswordEvent({
    required this.newPassword,
  });

  @override
  List<Object?> get props => [newPassword];
}

class AuthDeleteAccountEvent extends AuthEvent {
  const AuthDeleteAccountEvent();
} 