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
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:monkey_messanger/models/chat_entity.dart';
import 'package:monkey_messanger/screens/group_chat_settings_screen.dart';
import 'package:monkey_messanger/services/chat_repository_impl.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  
  // Репозиторий чата для получения обновлений
  late final ChatRepositoryImpl _chatRepository;
  // Поток обновлений чата
  Stream<ChatEntity?>? _chatStream;
  // Текущие данные чата
  ChatEntity? _currentChatEntity;
  
  // Переменные для работы с голосовыми сообщениями
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isRecordingInitialized = false;
  String? _recordingPath;
  int _recordingDuration = 0;
  DateTime? _recordingStartTime;
  bool _isPlaying = false;
  String? _currentlyPlayingId;
  
  @override
  void initState() {
    super.initState();
    _initAudioRecorder();
    
    // Инициализируем репозиторий
    _chatRepository = ChatRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
    
    // Подписываемся на обновления чата
    _chatStream = _chatRepository.getChatById(widget.chatId);
    
    // Загружаем сообщения
    context.read<ChatBloc>().add(LoadMessagesEvent(widget.chatId));
  }
  
  // Инициализация рекордера
  Future<void> _initAudioRecorder() async {
    try {
      final status = await Permission.microphone.request();
      _isRecordingInitialized = status.isGranted;
      if (!_isRecordingInitialized) {
        AppLogger.error('Microphone permission denied', null, StackTrace.current);
      }
    } catch (e) {
      _isRecordingInitialized = false;
      AppLogger.error('Failed to initialize audio recorder', e, StackTrace.current);
    }
  }
  
  // Начать запись голосового сообщения
  Future<void> _startRecording() async {
    if (!_isRecordingInitialized) {
      await _initAudioRecorder();
      if (!_isRecordingInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Требуется доступ к микрофону для записи голосовых сообщений'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    try {
      // Создаем временную директорию для записи
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // Проверяем, есть ли нужные разрешения
      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Требуется доступ к микрофону для записи голосовых сообщений'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      // Проверяем, доступен ли рекордер
      if (!(await _audioRecorder.hasPermission())) {
        AppLogger.error('Recording permission not granted', null, StackTrace.current);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Требуется доступ к микрофону для записи голосовых сообщений'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Начинаем запись
      await _audioRecorder.start(
        RecordConfig(),
        path: filePath,
      );
      
      _recordingPath = filePath;
      _recordingStartTime = DateTime.now();
      _recordingDuration = 0;
      
      // Запускаем таймер для обновления длительности записи
      setState(() {
        _isRecording = true;
      });
      
      // Запускаем таймер обновления длительности записи
      _startRecordingTimer();
      
    } catch (e) {
      AppLogger.error('Failed to start recording', e, StackTrace.current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при записи голосового сообщения: ${e.toString().split('\n').first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Таймер для обновления длительности записи
  void _startRecordingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!).inSeconds;
        });
        _startRecordingTimer();
      }
    });
  }
  
  // Остановить запись и отправить голосовое сообщение
  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    
    try {
      // Останавливаем запись
      final result = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _isUploading = true;
      });
      
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось получить запись'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Проверяем длительность записи
      if (_recordingDuration < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запись слишком короткая'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final file = File(result);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл записи не найден'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Загружаем файл в хранилище
      final url = await _storageService.uploadVoiceMessage(file, widget.chatId);
      
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить голосовое сообщение'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Отправляем сообщение
      context.read<ChatBloc>().add(SendMessageEvent(
        chatId: widget.chatId,
        content: url,
        type: MessageType.voice,
        senderId: widget.currentUser.id,
        voiceDurationSeconds: _recordingDuration,
      ));
      
      AppLogger.info('Voice message sent successfully');
      
    } catch (e) {
      AppLogger.error('Failed to send voice message', e, StackTrace.current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при отправке голосового сообщения: ${e.toString().split('\n').first}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
  
  // Воспроизведение голосового сообщения
  Future<void> _playVoiceMessage(String url, String messageId) async {
    if (_isPlaying && _currentlyPlayingId == messageId) {
      // Если уже воспроизводится это сообщение, останавливаем
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = null;
      });
      return;
    }
    
    try {
      // Если воспроизводится другое сообщение, останавливаем его
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      
      // Воспроизводим новое сообщение
      await _audioPlayer.play(UrlSource(url));
      
      setState(() {
        _isPlaying = true;
        _currentlyPlayingId = messageId;
      });
      
      // Обработчик завершения воспроизведения
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingId = null;
          });
        }
      });
      
    } catch (e) {
      AppLogger.error('Failed to play voice message', e, StackTrace.current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при воспроизведении: ${e.toString().split('\n').first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Форматирование времени записи
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: _buildAppBar(),
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
                                    fontSize: 15,
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
                            fontSize: 15,
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

  void _openGroupSettings(BuildContext context, ChatEntity chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatSettingsScreen(
          chatId: widget.chatId,
          currentUser: widget.currentUser,
          chatEntity: chat,
        ),
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
              size: 56,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No messages yet\nStart a conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMyMessage = message.senderId == widget.currentUser.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Align(
            alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMyMessage ? const Color(0xFF4A90E2) : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(message),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
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
          style: const TextStyle(color: Colors.white, fontSize: 15),
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
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  message.text!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: 180,
                    maxHeight: 180,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      imageUrl,
                      width: 180,
                      height: 135,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 180,
                          height: 135,
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
                  right: 6,
                  bottom: 6,
                  child: InkWell(
                    onTap: () => _downloadMedia(imageUrl, 'image_${message.id}.jpg'),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 14,
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
              const Icon(Icons.attach_file, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.mediaName ?? 'File',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.mediaSizeBytes != null)
                      Text(
                        '${(message.mediaSizeBytes! / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.download,
                color: Colors.white.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        );
      case MessageType.voice:
        return GestureDetector(
          onTap: () {
            if (message.mediaUrl != null) {
              _playVoiceMessage(message.mediaUrl!, message.id);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPlaying && _currentlyPlayingId == message.id 
                    ? Icons.pause_circle_filled 
                    : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.voiceDurationSeconds != null)
                      Text(
                        _formatDuration(message.voiceDurationSeconds!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      'Голосовое сообщение',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case MessageType.system:
        return Text(
          message.text ?? '',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        );
    }
  }

  Widget _buildAttachmentMenu() {
    return Container(
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final bool hasText = _messageController.text.trim().isNotEmpty;
    
    return Container(
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              ),
              onChanged: (text) {
                // Trigger rebuild when text changes
                setState(() {});
              },
            ),
          ),
          if (hasText)
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF4A90E2)),
              iconSize: 24,
              padding: const EdgeInsets.all(8),
              onPressed: _sendTextMessage,
            )
          else
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isAttachmentMenuOpen ? Icons.close : Icons.add,
                    color: Colors.white,
                  ),
                  iconSize: 24,
                  padding: const EdgeInsets.all(8),
                  onPressed: () {
                    setState(() {
                      _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
                    });
                  },
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecordingAndSend(),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : const Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
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
          const Icon(Icons.broken_image, color: Colors.white70, size: 32),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
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
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Отдельный метод для построения AppBar, который обновляется вместе с обновлениями чата
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2A2A2A),
      title: StreamBuilder<ChatEntity?>(
        stream: _chatStream,
        initialData: null,
        builder: (context, snapshot) {
          // Сохраняем последнее известное состояние чата
          if (snapshot.hasData) {
            _currentChatEntity = snapshot.data;
          }
          
          // Используем текущие данные чата или переданное имя
          final displayName = _currentChatEntity?.name ?? widget.chatName;
          
          return Text(
            displayName,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          );
        },
      ),
      actions: [
        StreamBuilder<ChatEntity?>(
          stream: _chatStream,
          initialData: null,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data?.isGroup == true) {
              return IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 24),
                padding: const EdgeInsets.only(right: 12),
                onPressed: () => _openGroupSettings(context, snapshot.data!),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
} 