import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseManagementScreen extends StatefulWidget {
  const DatabaseManagementScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> {
  bool _isLoadingFirestore = false;
  bool _isLoadingStorage = false;
  bool _isLoadingSupabase = false;
  int _firebaseStorageSize = 0;
  int _supabaseStorageSize = 0;
  int _firestoreCollectionsCounts = 0;
  bool _isLoadingStats = false;
  
  @override
  void initState() {
    super.initState();
    _loadStorageStats();
    _loadCollectionStats();
  }

  Future<void> _loadStorageStats() async {
    setState(() {
      _isLoadingStats = true;
    });
    
    try {
      // Get Firebase Storage stats
      final firebaseRef = FirebaseStorage.instance.ref();
      final firebaseResult = await firebaseRef.listAll();
      int totalFirebaseSize = 0;
      
      for (var item in firebaseResult.items) {
        final metadata = await item.getMetadata();
        if (metadata.size != null) {
          totalFirebaseSize += metadata.size!;
        }
      }
      
      // Get Supabase Storage stats
      final supabaseClient = Supabase.instance.client;
      final List<FileObject> files = await supabaseClient.storage.from('avatars').list();
      int totalSupabaseSize = 0;
      
      for (var file in files) {
        if (file.metadata != null && file.metadata!['size'] is int) {
          totalSupabaseSize += file.metadata!['size'] as int;
        }
      }
      
      setState(() {
        _firebaseStorageSize = totalFirebaseSize;
        _supabaseStorageSize = totalSupabaseSize;
        _isLoadingStats = false;
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при загрузке статистики хранилища: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }
  
  Future<void> _loadCollectionStats() async {
    setState(() {
      _isLoadingStats = true;
    });
    
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Count items in each collection
      final usersSnapshot = await firestore.collection(AppConstants.usersCollection).count().get();
      final chatsSnapshot = await firestore.collection(AppConstants.chatsCollection).count().get();
      final contactsSnapshot = await firestore.collection(AppConstants.contactsCollection).count().get();
      
      // We need to count messages across all chats
      final chatsQuerySnapshot = await firestore.collection(AppConstants.chatsCollection).get();
      int messagesCount = 0;
      
      for (var chatDoc in chatsQuerySnapshot.docs) {
        final messagesSnapshot = await firestore
            .collection(AppConstants.chatsCollection)
            .doc(chatDoc.id)
            .collection(AppConstants.messagesCollection)
            .count()
            .get();
        
        messagesCount += messagesSnapshot.count ?? 0;
      }
      
      setState(() {
        _firestoreCollectionsCounts = (usersSnapshot.count ?? 0) + 
                                     (chatsSnapshot.count ?? 0) + 
                                     (contactsSnapshot.count ?? 0) + 
                                     messagesCount;
        _isLoadingStats = false;
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при загрузке статистики коллекций: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }
  
  Future<void> _clearFirestoreCollections() async {
    setState(() {
      _isLoadingFirestore = true;
    });
    
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      // Clear messages from all chats
      final chatsQuerySnapshot = await firestore.collection(AppConstants.chatsCollection).get();
      
      for (var chatDoc in chatsQuerySnapshot.docs) {
        final messagesQuerySnapshot = await firestore
            .collection(AppConstants.chatsCollection)
            .doc(chatDoc.id)
            .collection(AppConstants.messagesCollection)
            .limit(500) // Process in batches to avoid memory issues
            .get();
        
        for (var messageDoc in messagesQuerySnapshot.docs) {
          batch.delete(messageDoc.reference);
        }
      }
      
      await batch.commit();
      
      // Show success message
      _showSuccessSnackBar('Сообщения успешно удалены из Firestore');
      
      // Refresh stats
      _loadCollectionStats();
      
      setState(() {
        _isLoadingFirestore = false;
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при очистке Firestore: $e');
      setState(() {
        _isLoadingFirestore = false;
      });
    }
  }
  
  Future<void> _clearFirebaseStorage() async {
    setState(() {
      _isLoadingStorage = true;
    });
    
    try {
      final firebaseRef = FirebaseStorage.instance.ref();
      final firebaseResult = await firebaseRef.listAll();
      
      for (var item in firebaseResult.items) {
        await item.delete();
      }
      
      // Show success message
      _showSuccessSnackBar('Файлы успешно удалены из Firebase Storage');
      
      // Refresh stats
      _loadStorageStats();
      
      setState(() {
        _isLoadingStorage = false;
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при очистке Firebase Storage: $e');
      setState(() {
        _isLoadingStorage = false;
      });
    }
  }
  
  Future<void> _clearSupabaseStorage() async {
    setState(() {
      _isLoadingSupabase = true;
    });
    
    try {
      final supabaseClient = Supabase.instance.client;
      final List<FileObject> files = await supabaseClient.storage.from('avatars').list();
      
      for (var file in files) {
        await supabaseClient.storage.from('avatars').remove([file.name]);
      }
      
      // Show success message
      _showSuccessSnackBar('Файлы успешно удалены из Supabase Storage');
      
      // Refresh stats
      _loadStorageStats();
      
      setState(() {
        _isLoadingSupabase = false;
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при очистке Supabase Storage: $e');
      setState(() {
        _isLoadingSupabase = false;
      });
    }
  }
  
  void _showConfirmationDialog({
    required String title,
    required String content,
    required Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Подтвердить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Управление базами данных',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Firebase Storage
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firebase Storage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Размер: ${_formatBytes(_firebaseStorageSize)}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoadingStorage 
                        ? null 
                        : () => _showConfirmationDialog(
                            title: 'Очистить Firebase Storage',
                            content: 'Вы уверены, что хотите удалить все файлы из Firebase Storage? Это действие нельзя отменить.',
                            onConfirm: _clearFirebaseStorage,
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: _isLoadingStorage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Очистить Firebase Storage'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Supabase Storage
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supabase Storage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Размер: ${_formatBytes(_supabaseStorageSize)}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoadingSupabase 
                        ? null 
                        : () => _showConfirmationDialog(
                            title: 'Очистить Supabase Storage',
                            content: 'Вы уверены, что хотите удалить все файлы из Supabase Storage? Это действие нельзя отменить.',
                            onConfirm: _clearSupabaseStorage,
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: _isLoadingSupabase
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Очистить Supabase Storage'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Firestore Collections
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firestore Collections',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Количество записей: $_firestoreCollectionsCounts'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoadingFirestore 
                        ? null 
                        : () => _showConfirmationDialog(
                            title: 'Очистить Firestore Collection',
                            content: 'Вы уверены, что хотите очистить все сообщения? Это действие нельзя отменить.',
                            onConfirm: _clearFirestoreCollections,
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: _isLoadingFirestore
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Очистить сообщения'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (_isLoadingStats)
              const Center(
                child: CircularProgressIndicator(),
              ),
              
            const Spacer(),
            
            Center(
              child: TextButton.icon(
                onPressed: () {
                  _loadStorageStats();
                  _loadCollectionStats();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить статистику'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 