import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:monkey_messanger/screens/two_factor_auth_screen.dart';
import 'package:monkey_messanger/services/email_service.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_theme.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:monkey_messanger/utils/supabase_config.dart';
import 'package:monkey_messanger/services/auth_repository_impl.dart';
import 'package:monkey_messanger/services/auth_repository.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:monkey_messanger/services/auth_state.dart' as app_auth;
import 'package:monkey_messanger/services/chat_bloc.dart';
import 'package:monkey_messanger/screens/login_screen.dart';
import 'package:monkey_messanger/screens/chat_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:cached_network_image/cached_network_image.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Отключаем отладочные режимы для повышения производительности
  debugPaintSizeEnabled = false;
  debugPrintMarkNeedsLayoutStacks = false;
  debugPrintMarkNeedsPaintStacks = false;
  
  // Устанавливаем предпочтительную ориентацию экрана
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Оптимизируем использование памяти
  ImageCache().maximumSizeBytes = 1024 * 1024 * 50; // 50MB для кэша
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    debug: false, // Отключаем debug режим в production
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
  
  // Create email service for 2FA
  final emailService = EmailService(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    prefs: sharedPreferences,
  );
  
  // Регистрируем наблюдатель для Bloc
  Bloc.observer = SimpleBlocObserver();
  
  runApp(
    MyApp(
      authRepository: authRepository,
      emailService: emailService,
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
  final EmailService emailService;
  
  const MyApp({
    super.key,
    required this.authRepository,
    required this.emailService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<EmailService>.value(value: emailService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: authRepository,
              emailService: emailService,
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
          home: BlocConsumer<AuthBloc, app_auth.AuthState>(
            listener: (context, state) {
              if (state.hasError == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage ?? 'Произошла ошибка'),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
              }
            },
            builder: (context, state) {
              // Логирование текущего состояния
              AppLogger.info('Current AuthState: ${state.status}');
              
              if (state.status == app_auth.AuthStatus.initial) {
                // Возвращаем загрузочный экран для начального состояния
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (state.isAuthenticated == true) {
                // Используем экран списка чатов для аутентифицированных пользователей
                return const ChatListScreen();
              }
              
              if (state.isLoading == true) {
                // Возвращаем загрузочный экран для состояния загрузки
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // Show 2FA verification screen if required
              if (state.isTwoFactorRequired == true && state.email != null) {
                return TwoFactorAuthScreen(email: state.email!);
              }
              
              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}
