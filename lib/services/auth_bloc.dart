import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:monkey_messanger/services/auth_repository.dart';
import 'package:monkey_messanger/services/auth_state.dart';
import 'package:monkey_messanger/services/email_service.dart';
import 'package:monkey_messanger/utils/app_logger.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final EmailService _emailService;
  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({
    required AuthRepository authRepository,
    required EmailService emailService,
  })  : _authRepository = authRepository,
        _emailService = emailService,
        super(AuthState.initial()) {
    on<AuthCheckStatusEvent>(_onAuthCheckStatus);
    on<AuthSignInWithEmailPasswordEvent>(_onSignInWithEmailPassword);
    on<AuthSignInWithGoogleEvent>(_onSignInWithGoogle);
    on<AuthSignUpWithEmailPasswordEvent>(_onSignUpWithEmailPassword);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthResetPasswordEvent>(_onResetPassword);
    on<AuthUpdateUserEvent>(_onUpdateUser);
    on<AuthUpdatePasswordEvent>(_onUpdatePassword);
    on<AuthDeleteAccountEvent>(_onDeleteAccount);
    on<AuthToggle2FAEvent>(_onToggle2FA);

    add(const AuthCheckStatusEvent());

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
        final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
        
        if (is2faEnabled) {
          final sent = await _emailService.sendVerificationCode(user.email);
          if (sent) {
            emit(AuthState.requiresTwoFactor(user.email));
          } else {
            emit(AuthState.error('Failed to send verification code. Please try again.'));
          }
        } else {
          emit(AuthState.authenticated(user));
        }
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
          final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
          if (is2faEnabled) {
            final sent = await _emailService.sendVerificationCode(user.email);
            if (sent) {
              emit(AuthState.requiresTwoFactor(user.email));
            } else {
              emit(AuthState.error('Failed to send verification code. Please try again.'));
            }
          } else {
            emit(AuthState.authenticated(user));
          }
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
          final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
          if (is2faEnabled) {
            final sent = await _emailService.sendVerificationCode(user.email);
            if (sent) {
              emit(AuthState.requiresTwoFactor(user.email));
            } else {
              emit(AuthState.error('Failed to send verification code. Please try again.'));
            }
          } else {
            emit(AuthState.authenticated(user));
          }
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
        await credential.user!.updateDisplayName(event.name);
        
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
    final currentUser = state.user;
    if (currentUser == null) {
      AppLogger.warning('Attempted to update user but state.user was null.');
      return;
    }
    
    emit(AuthState.loading());
    try {
      final updatedUser = currentUser.copyWith(
        name: event.name ?? currentUser.name ?? '', 
        photoUrl: event.photoUrl ?? currentUser.photoUrl, 
      );
      
      await _authRepository.updateUserData(updatedUser);
      
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

  Future<void> _onToggle2FA(
    AuthToggle2FAEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentUser = state.user;
    if (currentUser == null) {
      AppLogger.warning('Attempted to toggle 2FA but state.user was null.');
      return;
    }
    
    emit(AuthState.loading());
    try {
      if (event.enable) {
        await _authRepository.enableTwoFactorAuth();
        final sent = await _emailService.sendVerificationCode(currentUser.email);
        if (sent) {
          emit(AuthState.requiresTwoFactor(currentUser.email));
          return;
        } else {
          throw Exception('Failed to send verification code');
        }
      } else {
        await _authRepository.disableTwoFactorAuth();
        await _fetchAndEmitUserData();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error toggling 2FA', e, stackTrace);
      emit(AuthState.error('An error occurred while updating 2FA settings. Please try again.'));
    }
  }

  Future<bool> verify2FACode(String email, String code) async {
    try {
      final isValid = await _emailService.verifyCode(email, code);
      if (isValid) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          emit(AuthState.authenticated(user));
        }
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Error verifying 2FA code', e, stackTrace);
      return false;
    }
  }

  Future<void> _fetchAndEmitUserData() async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
        
        final bool isPending2FA = state.isTwoFactorRequired;
        
        if (is2faEnabled && !isPending2FA) {
          if (state.status != AuthStatus.loading) {
            final sent = await _emailService.sendVerificationCode(user.email);
            if (sent) {
              emit(AuthState.requiresTwoFactor(user.email));
              return; 
            }
          }
        }
        
        if (!is2faEnabled) {
          emit(AuthState.authenticated(user));
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching user data', e, stackTrace);
    }
  }
} 