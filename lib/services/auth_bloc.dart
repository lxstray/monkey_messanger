import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:monkey_messanger/services/auth_repository.dart';
import 'package:monkey_messanger/services/auth_state.dart';
import 'package:monkey_messanger/utils/app_logger.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthState.initial()) {
    // Register event handlers
    on<AuthCheckStatusEvent>(_onAuthCheckStatus);
    on<AuthSignInWithEmailPasswordEvent>(_onSignInWithEmailPassword);
    on<AuthSignInWithGoogleEvent>(_onSignInWithGoogle);
    on<AuthSignUpWithEmailPasswordEvent>(_onSignUpWithEmailPassword);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthResetPasswordEvent>(_onResetPassword);
    on<AuthUpdateUserEvent>(_onUpdateUser);
    on<AuthUpdatePasswordEvent>(_onUpdatePassword);
    on<AuthDeleteAccountEvent>(_onDeleteAccount);

    // Check initial auth status
    add(const AuthCheckStatusEvent());

    // Listen to auth state changes
    _authStateSubscription = _authRepository.authStateChanges.listen((user) {
      if (user != null) {
        _fetchAndEmitUserData();
      } else {
        emit(AuthState.unauthenticated());
      }
    });
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAuthCheckStatus(
    AuthCheckStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthState.authenticated(user));
      } else {
        emit(AuthState.unauthenticated());
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error checking auth status', e, stackTrace);
      emit(AuthState.unauthenticated());
    }
  }

  Future<void> _onSignInWithEmailPassword(
    AuthSignInWithEmailPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());
    try {
      final credential = await _authRepository.signInWithEmailAndPassword(
        event.email,
        event.password,
      );
      
      if (credential.user != null) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          emit(AuthState.authenticated(user));
        }
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error signing in with email and password', e, stackTrace);
      emit(AuthState.error(e.friendlyMessage));
    } catch (e, stackTrace) {
      AppLogger.error('Unknown error signing in with email and password', e, stackTrace);
      emit(AuthState.error('An unknown error occurred. Please try again.'));
    }
  }

  Future<void> _onSignInWithGoogle(
    AuthSignInWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());
    try {
      final credential = await _authRepository.signInWithGoogle();
      
      if (credential.user != null) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          emit(AuthState.authenticated(user));
        }
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error signing in with Google', e, stackTrace);
      emit(AuthState.error(e.friendlyMessage));
    } catch (e, stackTrace) {
      AppLogger.error('Unknown error signing in with Google', e, stackTrace);
      emit(AuthState.error('An unknown error occurred. Please try again.'));
    }
  }

  Future<void> _onSignUpWithEmailPassword(
    AuthSignUpWithEmailPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());
    try {
      final credential = await _authRepository.createUserWithEmailAndPassword(
        event.email,
        event.password,
      );
      
      if (credential.user != null) {
        // Update the display name
        await credential.user!.updateDisplayName(event.name);
        
        // Fetch updated user data
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          emit(AuthState.authenticated(user, isNewUser: true));
        }
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error signing up with email and password', e, stackTrace);
      emit(AuthState.error(e.friendlyMessage));
    } catch (e, stackTrace) {
      AppLogger.error('Unknown error signing up with email and password', e, stackTrace);
      emit(AuthState.error('An unknown error occurred. Please try again.'));
    }
  }

  Future<void> _onSignOut(
    AuthSignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.signOut();
      emit(AuthState.unauthenticated());
    } catch (e, stackTrace) {
      AppLogger.error('Error signing out', e, stackTrace);
      emit(AuthState.error('An error occurred while signing out. Please try again.'));
    }
  }

  Future<void> _onResetPassword(
    AuthResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());
    try {
      await _authRepository.resetPassword(event.email);
      emit(AuthState.passwordResetSent());
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error resetting password', e, stackTrace);
      emit(AuthState.error(e.friendlyMessage));
    } catch (e, stackTrace) {
      AppLogger.error('Unknown error resetting password', e, stackTrace);
      emit(AuthState.error('An unknown error occurred. Please try again.'));
    }
  }

  Future<void> _onUpdateUser(
    AuthUpdateUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (state.user == null) return;
    
    emit(AuthState.loading());
    try {
      final updatedUser = state.user!.copyWith(
        name: event.name ?? state.user!.name,
        photoUrl: event.photoUrl ?? state.user!.photoUrl,
      );
      
      await _authRepository.updateUserData(updatedUser);
      
      // Fetch updated user data
      await _fetchAndEmitUserData();
    } catch (e, stackTrace) {
      AppLogger.error('Error updating user', e, stackTrace);
      emit(AuthState.error('An error occurred while updating your profile. Please try again.'));
    }
  }

  Future<void> _onUpdatePassword(
    AuthUpdatePasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());
    try {
      await _authRepository.updatePassword(event.newPassword);
      
      // Re-emit authenticated state
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthState.authenticated(user));
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error updating password', e, stackTrace);
      emit(AuthState.error(e.friendlyMessage));
    } catch (e, stackTrace) {
      AppLogger.error('Unknown error updating password', e, stackTrace);
      emit(AuthState.error('An unknown error occurred. Please try again.'));
    }
  }

  Future<void> _onDeleteAccount(
    AuthDeleteAccountEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());
    try {
      await _authRepository.deleteUser();
      emit(AuthState.unauthenticated());
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Error deleting account', e, stackTrace);
      emit(AuthState.error(e.friendlyMessage));
    } catch (e, stackTrace) {
      AppLogger.error('Unknown error deleting account', e, stackTrace);
      emit(AuthState.error('An unknown error occurred. Please try again.'));
    }
  }

  Future<void> _fetchAndEmitUserData() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthState.authenticated(user));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching user data', e, stackTrace);
    }
  }
} 