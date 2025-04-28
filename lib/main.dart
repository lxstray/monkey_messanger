import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_theme.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:monkey_messanger/services/auth_repository_impl.dart';
import 'package:monkey_messanger/services/auth_repository.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:monkey_messanger/services/auth_state.dart';
import 'package:monkey_messanger/services/chat_bloc.dart';
import 'package:monkey_messanger/screens/login_screen.dart';
import 'package:monkey_messanger/screens/chat_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Create repository instances
  final authRepository = AuthRepositoryImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    googleSignIn: GoogleSignIn(),
    prefs: sharedPreferences,
  );
  
  // Регистрируем наблюдатель для Bloc
  Bloc.observer = SimpleBlocObserver();
  
  runApp(
    MyApp(
      authRepository: authRepository,
    ),
  );
}

// Наблюдатель для отслеживания состояний блока
class SimpleBlocObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    AppLogger.info('${bloc.runtimeType} | Event: $event');
    super.onEvent(bloc, event);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    AppLogger.info('${bloc.runtimeType} | Transition: $transition');
    super.onTransition(bloc, transition);
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    AppLogger.error('${bloc.runtimeType} | Error: $error', error, stackTrace);
    
    // Добавляем дополнительную обработку специфичных ошибок Firebase
    if (error.toString().contains('firebase') || error.toString().contains('network')) {
      AppLogger.warning('Обнаружена ошибка Firebase или сети. Возможно, проблемы с подключением.');
    }
    
    super.onError(bloc, error, stackTrace);
  }
  
  @override
  void onCreate(BlocBase bloc) {
    AppLogger.info('${bloc.runtimeType} | Created');
    super.onCreate(bloc);
  }

  @override
  void onClose(BlocBase bloc) {
    AppLogger.info('${bloc.runtimeType} | Closed');
    super.onClose(bloc);
  }
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  
  const MyApp({
    super.key,
    required this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: authRepository,
            ),
          ),
          BlocProvider<ChatBloc>(
            create: (context) => ChatBloc(),
          ),
        ],
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state.hasError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
              }
            },
            builder: (context, state) {
              // Логирование текущего состояния
              AppLogger.info('Current AuthState: ${state.status}');
              
              if (state.status == AuthStatus.initial) {
                // Возвращаем загрузочный экран для начального состояния
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (state.isAuthenticated) {
                // Используем экран списка чатов для аутентифицированных пользователей
                return const ChatListScreen();
              }
              
              if (state.isLoading) {
                // Возвращаем загрузочный экран для состояния загрузки
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}
