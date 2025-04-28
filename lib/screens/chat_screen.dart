import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/services/chat_bloc.dart';
import 'package:monkey_messanger/models/message_entity.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:monkey_messanger/services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:monkey_messanger/utils/app_logger.dart';
import 'package:monkey_messanger/utils/image_helper.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:external_path/external_path.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final UserEntity currentUser;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StorageService _storageService = StorageService();
  bool _isAttachmentMenuOpen = false;
  bool _isUploading = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    // Теперь загрузка сообщений происходит в chat_list_screen
    // перед переходом на этот экран, поэтому комментируем этот код
    // Future.delayed(const Duration(milliseconds: 100), () {
    //   if (mounted) {
    //     context.read<ChatBloc>().add(LoadMessagesEvent(widget.chatId));
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          widget.chatName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Implement chat settings menu
            },
          ),
        ],
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: state is ChatLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4A90E2),
                            ),
                          )
                        : state is ChatLoaded
                            ? _buildMessageList(state.messages)
                            : const Center(
                                child: Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                  ),
                  if (_isAttachmentMenuOpen) _buildAttachmentMenu(),
                  _buildMessageInput(),
                ],
              ),
              if (_isUploading || _isDownloading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF4A90E2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isUploading ? 'Uploading...' : 'Downloading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList(List<MessageEntity> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet\nStart a conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMyMessage = message.senderId == widget.currentUser.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMyMessage ? const Color(0xFF4A90E2) : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(message),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(MessageEntity message) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.text ?? '',
          style: const TextStyle(color: Colors.white),
        );
      case MessageType.image:
        final String imageUrl = message.mediaUrl ?? '';
        if (imageUrl.isEmpty) {
          return _buildImageErrorWidget('Invalid image URL');
        }
        
        ImageHelper().preloadImage(imageUrl);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text != null && message.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  message.text!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: 200,
                    maxHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 200,
                      height: 150,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 200,
                          height: 150,
                          color: Colors.grey[900],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xFF4A90E2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        AppLogger.error('Error loading image: $imageUrl', error, stackTrace);
                        return _buildImageErrorWidget('Failed to load image');
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: InkWell(
                    onTap: () => _downloadMedia(imageUrl, 'image_${message.id}.jpg'),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case MessageType.file:
        return InkWell(
          onTap: () {
            if (message.mediaUrl != null && message.mediaName != null) {
              _downloadMedia(message.mediaUrl!, message.mediaName!);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_file, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.mediaName ?? 'File',
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.mediaSizeBytes != null)
                      Text(
                        '${(message.mediaSizeBytes! / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.download,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        );
      case MessageType.voice:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              message.voiceDurationSeconds != null
                  ? '${message.voiceDurationSeconds}s'
                  : 'Voice message',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
      case MessageType.system:
        return Text(
          message.text ?? '',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }

  Widget _buildAttachmentMenu() {
    return Container(
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAttachmentButton(
            icon: Icons.image,
            label: 'Image',
            onTap: _pickImage,
          ),
          _buildAttachmentButton(
            icon: Icons.attach_file,
            label: 'File',
            onTap: _pickFile,
          ),
          _buildAttachmentButton(
            icon: Icons.mic,
            label: 'Voice',
            onTap: () {
              // TODO: Implement voice message recording
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isAttachmentMenuOpen ? Icons.close : Icons.add,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
              });
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF4A90E2)),
            onPressed: _sendTextMessage,
          ),
        ],
      ),
    );
  }

  void _sendTextMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      context.read<ChatBloc>().add(
            SendMessageEvent(
              chatId: widget.chatId,
              content: content,
              type: MessageType.text,
              senderId: widget.currentUser.id,
            ),
          );
      _messageController.clear();
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 1200,
      );
      
      if (image != null) {
        setState(() => _isUploading = true);
        try {
          final file = File(image.path);
          
          final fileSize = await file.length();
          if (fileSize > 5 * 1024 * 1024) {
            setState(() => _isUploading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image is too large. Maximum size is 5MB.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          final url = await _storageService.uploadImage(file, widget.chatId);
          
          if (url.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to get image URL from server'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          if (mounted) {
            try {
              context.read<ChatBloc>().add(
                SendMessageEvent(
                  chatId: widget.chatId,
                  content: url,
                  type: MessageType.image,
                  senderId: widget.currentUser.id,
                ),
              );
              AppLogger.info('Message with image sent successfully');
            } catch (e) {
              AppLogger.error('Failed to send message with image', e, StackTrace.current);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send message: ${e.toString().split('\n').first}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } catch (e) {
          AppLogger.error('Failed to upload image', e, StackTrace.current);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: ${e.toString().split('\n').first}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isUploading = false;
              _isAttachmentMenuOpen = false;
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to pick image', e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileName = result.files.first.name;
        final fileSize = result.files.first.size;
        
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File is too large. Maximum size is 10MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        setState(() => _isUploading = true);
        
        try {
          final url = await _storageService.uploadFile(file, widget.chatId);
          
          if (url.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to get file URL from server'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          if (mounted) {
            try {
              context.read<ChatBloc>().add(
                SendMessageEvent(
                  chatId: widget.chatId,
                  content: url,
                  type: MessageType.file,
                  senderId: widget.currentUser.id,
                ),
              );
              AppLogger.info('Message with file sent successfully');
            } catch (e) {
              AppLogger.error('Failed to send message with file', e, StackTrace.current);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send message: ${e.toString().split('\n').first}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } catch (e) {
          AppLogger.error('Failed to upload file', e, StackTrace.current);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload file: ${e.toString().split('\n').first}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isUploading = false;
              _isAttachmentMenuOpen = false;
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to pick file', e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageErrorWidget(String message) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Метод для скачивания медиафайлов
  Future<void> _downloadMedia(String url, String fileName) async {
    if (_isDownloading) return;
    
    setState(() => _isDownloading = true);
    
    try {
      // Проверяем разрешения на мобильных устройствах
      if (Platform.isAndroid) {
        // Определяем версию Android
        int? sdkVersion;
        try {
          final deviceInfoPlugin = DeviceInfoPlugin();
          final androidInfo = await deviceInfoPlugin.androidInfo;
          sdkVersion = androidInfo.version.sdkInt;
          AppLogger.info('Android SDK версия: $sdkVersion');
        } catch (e) {
          // Если не удалось получить версию, предполагаем, что версия < 33
          sdkVersion = 30;
          AppLogger.error('Ошибка при получении SDK версии', e, StackTrace.current);
        }
        
        // Запрашиваем разрешения в зависимости от версии Android
        if (sdkVersion >= 33) {
          // Android 13+ (API 33): запрашиваем новые типы разрешений
          if (fileName.toLowerCase().endsWith('.jpg') || 
              fileName.toLowerCase().endsWith('.jpeg') || 
              fileName.toLowerCase().endsWith('.png')) {
            final status = await Permission.photos.request();
            if (!status.isGranted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Требуется разрешение на доступ к фотографиям'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              setState(() => _isDownloading = false);
              return;
            }
          } else if (fileName.toLowerCase().endsWith('.mp3') || 
                    fileName.toLowerCase().endsWith('.wav')) {
            final status = await Permission.audio.request();
            if (!status.isGranted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Требуется разрешение на доступ к аудиофайлам'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              setState(() => _isDownloading = false);
              return;
            }
          } else if (fileName.toLowerCase().endsWith('.mp4') || 
                    fileName.toLowerCase().endsWith('.mov')) {
            final status = await Permission.videos.request();
            if (!status.isGranted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Требуется разрешение на доступ к видеофайлам'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              setState(() => _isDownloading = false);
              return;
            }
          } else {
            // Для других типов файлов на Android 13+ проверяем storage
            final status = await Permission.storage.request();
            if (!status.isGranted) {
              AppLogger.info('Storage permission not granted, but proceeding anyway on Android 13+');
              // На Android 13+ мы все равно можем сохранять файлы в специальную директорию приложения
            }
          }
        } else {
          // Android 12 и ниже: используем старые разрешения
          final storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Требуется разрешение на доступ к хранилищу'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            setState(() => _isDownloading = false);
            return;
          }
        }
      } else if (Platform.isIOS) {
        // На iOS запрашиваем разрешение на доступ к галерее
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          AppLogger.info('Photos permission not granted, but proceeding for non-image files on iOS');
          // На iOS мы все равно можем сохранять в директорию приложения
        }
      }
      
      // Получаем путь к папке Downloads
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        int? sdkVersion;
        try {
          final deviceInfoPlugin = DeviceInfoPlugin();
          final androidInfo = await deviceInfoPlugin.androidInfo;
          sdkVersion = androidInfo.version.sdkInt;
        } catch (e) {
          sdkVersion = 30;
          AppLogger.error('Ошибка при получении SDK версии', e, StackTrace.current);
        }
        
        try {
          AppLogger.info('Пытаемся получить путь к Downloads на Android');
          
          // Сначала пробуем получить путь через ExternalPath
          try {
            List<String>? externalStoragePaths = await ExternalPath.getExternalStorageDirectories();
            if (externalStoragePaths != null && externalStoragePaths.isNotEmpty) {
              final downloadDirPath = '${externalStoragePaths[0]}/Download';
              final downloadDir = Directory(downloadDirPath);
              if (await downloadDir.exists()) {
                downloadsDir = downloadDir;
                AppLogger.info('Путь к Downloads через ExternalPath: ${downloadsDir.path}');
                return;
              }
            }
          } catch (e) {
            AppLogger.error('Ошибка при получении пути через ExternalPath', e, StackTrace.current);
          }
          
          // На Android 10+ пробуем получить путь через getExternalStorageDirectory
          if (sdkVersion >= 29) {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              AppLogger.info('Получен путь через getExternalStorageDirectory: ${externalDir.path}');
              // Пытаемся найти папку Download ближе к корню
              Directory? foundDir = externalDir;
              List<String> pathSegments = externalDir.path.split('/');
              
              // Ищем Android
              int androidIndex = pathSegments.indexOf('Android');
              if (androidIndex != -1 && androidIndex > 0) {
                // Идем до Android и затем добавляем Downloads
                String pathToStorage = pathSegments.sublist(0, androidIndex).join('/');
                Directory possibleDownloadsDir = Directory('$pathToStorage/Download');
                if (await possibleDownloadsDir.exists()) {
                  foundDir = possibleDownloadsDir;
                  AppLogger.info('Найдена папка Download: ${foundDir.path}');
                }
              }
              
              downloadsDir = Directory('${foundDir.path}/Download');
              AppLogger.info('Будет использована директория: ${downloadsDir.path}');
            } else {
              AppLogger.info('getExternalStorageDirectory вернул null, используем альтернативный путь');
              // Альтернативный путь
              downloadsDir = Directory('/storage/emulated/0/Download');
            }
          } else {
            // На Android до 10 версии используем стандартную директорию Downloads
            downloadsDir = Directory('/storage/emulated/0/Download');
            AppLogger.info('Используем стандартный путь: ${downloadsDir.path}');
          }
        } catch (e) {
          AppLogger.error('Ошибка при определении пути к Downloads', e, StackTrace.current);
          // Запасной вариант - используем директорию приложения
          final appDocDir = await getApplicationDocumentsDirectory();
          downloadsDir = Directory('${appDocDir.path}/Downloads');
          AppLogger.info('Используем запасной путь: ${downloadsDir.path}');
        }
      } else if (Platform.isIOS) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${appDocDir.path}/Downloads');
        AppLogger.info('iOS директория для загрузок: ${downloadsDir.path}');
      } else if (Platform.isWindows) {
        // На Windows используем путь к папке Downloads
        final String? userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsDir = Directory('$userProfile\\Downloads');
          AppLogger.info('Windows директория для загрузок: ${downloadsDir.path}');
        } else {
          final appDocDir = await getApplicationDocumentsDirectory();
          downloadsDir = Directory('${appDocDir.path}\\Downloads');
          AppLogger.info('Альтернативная Windows директория: ${downloadsDir.path}');
        }
      } else if (Platform.isMacOS || Platform.isLinux) {
        downloadsDir = await getDownloadsDirectory();
        AppLogger.info('MacOS/Linux директория для загрузок: ${downloadsDir?.path}');
      } else {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadsDir = appDocDir;
        AppLogger.info('Директория приложения для загрузок: ${downloadsDir.path}');
      }
      
      if (downloadsDir == null) {
        throw Exception('Could not access downloads directory');
      }
      
      // Создаем директорию, если она не существует
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Создаем уникальное имя файла
      String uniqueFileName = fileName;
      File file = File('${downloadsDir.path}${Platform.pathSeparator}$uniqueFileName');
      int count = 1;
      while (await file.exists()) {
        final String extension = path.extension(fileName);
        final String nameWithoutExtension = path.basenameWithoutExtension(fileName);
        uniqueFileName = '${nameWithoutExtension}_$count$extension';
        file = File('${downloadsDir.path}${Platform.pathSeparator}$uniqueFileName');
        count++;
      }
      
      // Скачиваем файл
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: HTTP ${response.statusCode}');
      }
      
      // Сохраняем файл
      await file.writeAsBytes(response.bodyBytes);
      
      // Для Android пытаемся обновить галерею, если это медиафайл
      if (Platform.isAndroid) {
        bool isMediaFile = fileName.toLowerCase().endsWith('.jpg') || 
                          fileName.toLowerCase().endsWith('.jpeg') || 
                          fileName.toLowerCase().endsWith('.png') ||
                          fileName.toLowerCase().endsWith('.mp4') || 
                          fileName.toLowerCase().endsWith('.mp3');
                          
        if (isMediaFile) {
          try {
            await MediaScanner.loadMedia(path: file.path);
            AppLogger.info('MediaScanner обновил галерею');
          } catch (e) {
            AppLogger.error('Ошибка при сканировании медиафайла', e, StackTrace.current);
            // Продолжаем выполнение даже если MediaScanner завершился с ошибкой
          }
        }
      }
      
      AppLogger.info('File downloaded successfully: ${file.path}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл сохранен: $uniqueFileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'ОТКРЫТЬ',
              textColor: Colors.white,
              onPressed: () {
                if (Platform.isAndroid || Platform.isIOS) {
                  Share.shareXFiles([XFile(file.path)]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to download file', e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки файла: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 