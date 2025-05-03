import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:monkey_messanger/services/auth_state.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import '../mocks/mock_repositories.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockEmailService emailService;
  late AuthBloc authBloc;

  setUp(() {
    authRepository = MockAuthRepository();
    emailService = MockEmailService();
    authBloc = AuthBloc(
      authRepository: authRepository,
      emailService: emailService,
    );
  });

  tearDown(() {
    authBloc.close();
    authRepository.dispose();
  });

  group('AuthBloc', () {
    test('initial state is initial', () {
      expect(authBloc.state, equals(AuthState.initial()));
    });

    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] when no user is authenticated',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckStatusEvent()),
      expect: () => [
        AuthState.loading(),
        AuthState.unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when user is authenticated without 2FA',
      build: () {
        // Настраиваем мок репозитория для возврата аутентифицированного пользователя без 2FA
        final user = UserEntity(
          id: 'test-user-id',
          name: 'Test User',
          email: 'test@example.com',
          photoUrl: 'https://example.com/photo.jpg',
          role: 'user',
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
          isOnline: true,
          is2faEnabled: false,
        );
        
        authRepository.emitAuthState(MockUser());
        
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckStatusEvent()),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.authenticated,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, requiresTwoFactor] when user is authenticated with 2FA enabled',
      build: () {
        // Настраиваем мок репозитория для возврата аутентифицированного пользователя с 2FA
        authRepository.emitAuthState(MockUser());
        authRepository.enableTwoFactorAuth();
        
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckStatusEvent()),
      expect: () => [
        AuthState.loading(),
        AuthState.requiresTwoFactor('test@example.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when signing in with email and password without 2FA',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignInWithEmailPasswordEvent(
        email: 'test@example.com',
        password: 'password123',
      )),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.authenticated,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, error] when signing in with invalid credentials',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignInWithEmailPasswordEvent(
        email: 'error@example.com',
        password: 'password123',
      )),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.error,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when signing in with Google without 2FA',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignInWithGoogleEvent()),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.authenticated,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated, isNewUser: true] when signing up with email and password',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignUpWithEmailPasswordEvent(
        email: 'test@example.com',
        password: 'password123',
        name: 'Test User',
      )),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.isNewUser, 
          'isNewUser', 
          true,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, error] when signing up with existing email',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignUpWithEmailPasswordEvent(
        email: 'error@example.com',
        password: 'password123',
        name: 'Test User',
      )),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.error,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] when signing out',
      build: () {
        // Сначала имитируем аутентифицированного пользователя
        authRepository.emitAuthState(MockUser());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignOutEvent()),
      expect: () => [
        AuthState.unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, passwordResetSent] when resetting password',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthResetPasswordEvent(
        email: 'test@example.com',
      )),
      expect: () => [
        AuthState.loading(),
        AuthState.passwordResetSent(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, error] when resetting password for non-existent user',
      build: () {
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthResetPasswordEvent(
        email: 'error@example.com',
      )),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.error,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when toggling 2FA to enabled',
      build: () {
        // Настраиваем мок репозитория для возврата аутентифицированного пользователя без 2FA
        authRepository.emitAuthState(MockUser());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthToggle2FAEvent(enable: true)),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.user?.is2faEnabled, 
          'is2faEnabled', 
          true,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when toggling 2FA to disabled',
      build: () {
        // Настраиваем мок репозитория для возврата аутентифицированного пользователя с 2FA
        authRepository.emitAuthState(MockUser());
        authRepository.enableTwoFactorAuth();
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthToggle2FAEvent(enable: false)),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.user?.is2faEnabled, 
          'is2faEnabled', 
          false,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when updating user profile',
      build: () {
        // Настраиваем мок репозитория для возврата аутентифицированного пользователя
        authRepository.emitAuthState(MockUser());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthUpdateUserEvent(
        photoUrl: 'https://example.com/new-photo.jpg',
        name: 'Updated User',
      )),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.authenticated,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when updating password',
      build: () {
        // Настраиваем мок репозитория для возврата аутентифицированного пользователя
        authRepository.emitAuthState(MockUser());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthUpdatePasswordEvent(
        newPassword: 'newPassword123',
      )),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (state) => state.status, 
          'status', 
          AuthStatus.authenticated,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] when deleting account',
      build: () {
        // Сначала имитируем аутентифицированного пользователя
        authRepository.emitAuthState(MockUser());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthDeleteAccountEvent()),
      expect: () => [
        AuthState.loading(),
        AuthState.unauthenticated(),
      ],
    );
  });
} 