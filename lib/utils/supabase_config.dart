class SupabaseConfig {
  // URL вашего проекта Supabase
  static const String supabaseUrl = 'https://khnlqijzbyjbamchsfks.supabase.co';
  
  // Публичный (anon) ключ вашего проекта Supabase
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtobmxxaWp6YnlqYmFtY2hzZmtzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU4MTkyNTAsImV4cCI6MjA2MTM5NTI1MH0.aQjzeCWU0tEd0UbyqnQ4yKwJMUKqzl86GYtK8JUrzJE';
  
  // Названия корзин (buckets) для хранения файлов
  static const String chatFilesBucket = 'chatfiles';
  static const String chatImagesBucket = 'chatimages';
  static const String chatVoiceBucket = 'chatvoice';
} 