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
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: _isUploading ? Colors.grey : const Color(0xFF4A90E2),
                          child: _isUploading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : currentUser.photoUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        currentUser.photoUrl!,
                                        width: 90,
                                        height: 90,
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
                                            fontSize: 32,
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
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                        ),
                        if (!_isUploading)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2A2A2A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentUser.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentUser.email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 0.8),
                  const SizedBox(height: 10),
                  Text(
                    'Аккаунт создан: ${_formatDate(currentUser.createdAt)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Последняя активность: ${_formatDate(currentUser.lastActive)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 0.8),
                  const SizedBox(height: 12),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.security,
                      color: Color(0xFF4A90E2),
                      size: 22,
                    ),
                    title: const Text(
                      'Двухфакторная аутентификация',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Код подтверждения будет отправлен на email',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    trailing: Switch(
                      value: currentUser.is2faEnabled,
                      onChanged: (value) {
                        _toggle2FA(value);
                      },
                      activeColor: const Color(0xFF4A90E2),
                      activeTrackColor: const Color(0xFF4A90E2).withOpacity(0.5),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 0.8),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                              actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              title: const Text(
                                'Выход из аккаунта',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              content: const Text(
                                'Вы уверены, что хотите выйти?',
                                style: TextStyle(color: Colors.white, fontSize: 15),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Отмена',
                                    style: TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    context.read<AuthBloc>().add(const AuthSignOutEvent());
                                  },
                                  child: const Text(
                                    'Выйти',
                                    style: TextStyle(color: Colors.red, fontSize: 14),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                      label: const Text(
                        'Выйти из аккаунта',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
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
  
  void _toggle2FA(bool enable) {
    context.read<AuthBloc>().add(AuthToggle2FAEvent(enable: enable));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enable 
          ? 'Двухфакторная аутентификация включена' 
          : 'Двухфакторная аутентификация отключена'),
        backgroundColor: const Color(0xFF4A90E2),
      ),
    );
  }
} 