class AppConstants {
  // App name
  static const String appName = 'Monkey Messenger';
  
  // Firebase collections
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String contactsCollection = 'contacts';
  static const String verificationCodesCollection = 'verification_codes';

  // User roles
  static const String adminRole = 'admin';
  static const String userRole = 'user';
  
  // Shared preferences keys
  static const String themeKey = 'theme_mode';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String userNameKey = 'user_name';
  static const String userRoleKey = 'user_role';
  
  // Email service configuration
  static const String emailServiceUrl = 'http://10.0.2.2:3000';
  static const String emailServiceApiKey = 'monkey-messenger-api-key';
} 