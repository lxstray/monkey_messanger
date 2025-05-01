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
    on<AuthToggle2FAEvent>(_onToggle2FA);

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
        // Проверяем, включена ли 2FA
        final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
        
        if (is2faEnabled) {
          // Если 2FA включена, отправляем код и показываем экран 2FA
          final sent = await _emailService.sendVerificationCode(user.email);
          if (sent) {
            emit(AuthState.requiresTwoFactor(user.email));
          } else {
            emit(AuthState.error('Failed to send verification code. Please try again.'));
          }
        } else {
          // Если 2FA не включена, то просто аутентифицируем пользователя
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
          // Check if 2FA is enabled for this user
          final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
          if (is2faEnabled) {
            // User has 2FA enabled, we need to send a verification code
            final sent = await _emailService.sendVerificationCode(user.email);
            if (sent) {
              // Need to show 2FA verification screen
              emit(AuthState.requiresTwoFactor(user.email));
            } else {
              emit(AuthState.error('Failed to send verification code. Please try again.'));
            }
          } else {
            // No 2FA, proceed with normal authentication
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
          // Check if 2FA is enabled for this user
          final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
          if (is2faEnabled) {
            // User has 2FA enabled, we need to send a verification code
            final sent = await _emailService.sendVerificationCode(user.email);
            if (sent) {
              // Need to show 2FA verification screen
              emit(AuthState.requiresTwoFactor(user.email));
            } else {
              emit(AuthState.error('Failed to send verification code. Please try again.'));
            }
          } else {
            // No 2FA, proceed with normal authentication
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
    // Ensure user is not null before proceeding
    final currentUser = state.user;
    if (currentUser == null) {
      AppLogger.warning('Attempted to update user but state.user was null.');
      return; // Exit if user is null
    }
    
    emit(AuthState.loading());
    try {
      // Use currentUser which is guaranteed non-null here
      final updatedUser = currentUser.copyWith(
        // Provide default empty string if event.name and currentUser.name are null
        name: event.name ?? currentUser.name ?? '', 
        // Use event.photoUrl if available, otherwise keep existing (could be null)
        photoUrl: event.photoUrl ?? currentUser.photoUrl, 
      );
      
      await _authRepository.updateUserData(updatedUser);
      
      // Fetch updated user data to ensure the state is consistent
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

  Future<void> _onToggle2FA(
    AuthToggle2FAEvent event,
    Emitter<AuthState> emit,
  ) async {
    // Ensure user is not null before proceeding
    final currentUser = state.user;
    if (currentUser == null) {
      AppLogger.warning('Attempted to toggle 2FA but state.user was null.');
      return; // Exit if user is null
    }
    
    emit(AuthState.loading());
    try {
      if (event.enable) {
        await _authRepository.enableTwoFactorAuth();
      } else {
        await _authRepository.disableTwoFactorAuth();
      }
      
      // Fetch updated user data to ensure the state is consistent
      await _fetchAndEmitUserData();
      
    } catch (e, stackTrace) {
      AppLogger.error('Error toggling 2FA', e, stackTrace);
      emit(AuthState.error('An error occurred while updating 2FA settings. Please try again.'));
    }
  }

  // Method to verify 2FA code
  Future<bool> verify2FACode(String email, String code) async {
    try {
      final isValid = await _emailService.verifyCode(email, code);
      if (isValid) {
        // Получаем данные пользователя
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          // Код верный, устанавливаем флаг 2FA-верифицировано и эмитим состояние authenticated
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
        // Проверяем, включена ли 2FA и верифицирован ли уже пользователь
        final is2faEnabled = await _authRepository.isTwoFactorAuthEnabled();
        
        // Получаем статус верификации 2FA из текущего состояния
        final bool isPending2FA = state.isTwoFactorRequired;
        
        if (is2faEnabled && !isPending2FA) {
          // Если 2FA включена и пользователь еще не на экране верификации,
          // то отправляем код и показываем экран 2FA
          final sent = await _emailService.sendVerificationCode(user.email);
          if (sent) {
            emit(AuthState.requiresTwoFactor(user.email));
            return; // Важно! Выходим, чтобы не эмитить состояние authenticated
          }
        }
        
        // Если 2FA не включена или мы уже находимся в процессе верификации 2FA,
        // то не меняем состояние
        if (!is2faEnabled) {
          emit(AuthState.authenticated(user));
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching user data', e, stackTrace);
    }
  }
} 