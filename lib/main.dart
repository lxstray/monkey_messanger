import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:monkey_messanger/screens/admin/admin_panel_screen.dart';
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

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPaintSizeEnabled = false;
  debugPrintMarkNeedsLayoutStacks = false;
  debugPrintMarkNeedsPaintStacks = false;
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  ImageCache().maximumSizeBytes = 1024 * 1024 * 50; // 50MB для кэша
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    debug: false, 
  );
  
  final sharedPreferences = await SharedPreferences.getInstance();
  
  final authRepository = AuthRepositoryImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    googleSignIn: GoogleSignIn(),
    prefs: sharedPreferences,
  );
  
  final emailService = EmailService(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    prefs: sharedPreferences,
  );
  
  Bloc.observer = SimpleBlocObserver();
  
  runApp(
    MyApp(
      authRepository: authRepository,
      emailService: emailService,
    ),
  );
}

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
              AppLogger.info('Current AuthState: ${state.status}');
              
              if (state.status == app_auth.AuthStatus.initial) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (state.isLoading == true) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (state.isTwoFactorRequired == true && state.email != null) {
                return TwoFactorAuthScreen(email: state.email!);
              }
              
              if (state.isAuthenticated == true) {
                if (state.user?.role == 'banned') {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.block,
                              color: AppColors.errorColor,
                              size: 64,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Аккаунт заблокирован',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Ваш аккаунт был заблокирован администратором. Если вы считаете, что это ошибка, пожалуйста, свяжитесь с поддержкой.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                context.read<AuthBloc>().add(const AuthSignOutEvent());
                              },
                              child: const Text('Выйти из аккаунта'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                
                return ChatListScreen();
              }
              
              return const LoginScreen();
            },
          ),
          routes: {
            '/admin': (context) => const AdminPanelScreen(),
          },
        ),
      ),
    );
  }
}
