import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/auth_event.dart';
import 'package:image_picker/image_picker.dart';
import 'package:monkey_messanger/services/storage_service.dart';
import 'package:monkey_messanger/utils/supabase_config.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthBloc>().state.user;

    return currentUser == null
        ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4A90E2),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: _isUploading ? Colors.grey : const Color(0xFF4A90E2),
                        child: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : currentUser.photoUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      currentUser.photoUrl!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => Text(
                                        currentUser.name.isNotEmpty
                                            ? currentUser.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    currentUser.name.isNotEmpty
                                        ? currentUser.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                      ),
                      if (!_isUploading)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentUser.email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Role: ${currentUser.role}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 20),
                Text(
                  'Аккаунт создан: ${_formatDate(currentUser.createdAt)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Последняя активность: ${_formatDate(currentUser.lastActive)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF2A2A2A),
                          title: const Text(
                            'Выход из аккаунта',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'Вы уверены, что хотите выйти?',
                            style: TextStyle(color: Colors.white),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Отмена',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                context.read<AuthBloc>().add(const AuthSignOutEvent());
                              },
                              child: const Text(
                                'Выйти',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return; // Prevent multiple uploads

    final currentUser = context.read<AuthBloc>().state.user;
    if (currentUser == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() => _isUploading = true);
        final file = File(pickedFile.path);
        
        // Define a unique path for the avatar
        final fileExtension = p.extension(file.path);
        final filePath = 'avatars/${currentUser.id}/profile_$fileExtension';
        
        // Upload using StorageService (which handles Supabase upload & compression)
        // Pass a fake chatId or adapt StorageService if needed for profile pics
        // For now, let's assume StorageService can handle general uploads
        // TODO: Update StorageService if needed to handle paths without chatId
        // For now, using user ID as the "chatId" equivalent for path structure
        final imageUrl = await _storageService.uploadImage(file, currentUser.id, specificPath: filePath);
        
        if (imageUrl.isNotEmpty && mounted) {
          // Update user profile via AuthBloc
          context.read<AuthBloc>().add(AuthUpdateUserEvent(photoUrl: imageUrl));
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Аватар обновлен!'),
              backgroundColor: Color(0xFF4A90E2),
            ),
          );
        } else if (mounted) {
          throw Exception('Не удалось загрузить изображение или получить URL.');
        }
      } else {
        AppLogger.info('Image picking cancelled.');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Ошибка при обновлении аватара', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
} 