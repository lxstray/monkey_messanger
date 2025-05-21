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
  
  late final ChatRepositoryImpl _chatRepository;
  Stream<ChatEntity?>? _chatStream;
  ChatEntity? _currentChatEntity;
  
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
    
    _chatRepository = ChatRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
    
    _chatStream = _chatRepository.getChatById(widget.chatId);
    
    context.read<ChatBloc>().add(LoadMessagesEvent(widget.chatId));
  }
  
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
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
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
      
      await _audioRecorder.start(
        RecordConfig(),
        path: filePath,
      );
      
      _recordingPath = filePath;
      _recordingStartTime = DateTime.now();
      _recordingDuration = 0;
      
      setState(() {
        _isRecording = true;
      });
      
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
  
  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    
    try {
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
  
  Future<void> _playVoiceMessage(String url, String messageId) async {
    if (_isPlaying && _currentlyPlayingId == messageId) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = null;
      });
      return;
    }
    
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      
      await _audioPlayer.play(UrlSource(url));
      
      setState(() {
        _isPlaying = true;
        _currentlyPlayingId = messageId;
      });
      
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

  Future<void> _downloadMedia(String url, String fileName) async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);
    AppLogger.info('Starting download for: $fileName from $url');

    try {
      bool permissionsGranted = await _checkAndRequestPermissions(fileName);
      if (!permissionsGranted) {
        AppLogger.warning('Permissions not granted. Aborting download.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Требуются разрешения для сохранения файла'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isDownloading = false);
        return;
      }

      Directory? downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Не удалось получить доступ к папке загрузок');
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Generate unique filename
      String uniqueFileName = fileName;
      File file = File(path.join(downloadsDir.path, uniqueFileName));
      int count = 1;
      while (await file.exists()) {
        final String extension = path.extension(fileName);
        final String nameWithoutExtension = path.basenameWithoutExtension(fileName);
        uniqueFileName = '${nameWithoutExtension}_$count$extension';
        file = File(path.join(downloadsDir.path, uniqueFileName));
        count++;
      }

      // Download file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки файла: HTTP ${response.statusCode}');
      }

      // Save file
      await file.writeAsBytes(response.bodyBytes);
      AppLogger.info('File saved successfully: ${file.path}');

      // Scan media file on Android
      if (Platform.isAndroid) {
        bool isMediaFile = ['.jpg', '.jpeg', '.png', '.mp4', '.mov', '.mp3', '.wav']
            .any((ext) => fileName.toLowerCase().endsWith(ext));

        if (isMediaFile) {
          try {
            await MediaScanner.loadMedia(path: file.path);
            AppLogger.info('Media file scanned successfully');
          } catch (e, s) {
            AppLogger.error('Failed to scan media file', e, s);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл сохранен в: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ОТКРЫТЬ',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(file.path)], text: 'Открыт файл $uniqueFileName');
              },
            ),
          ),
        );
      }
    } catch (e, s) {
      AppLogger.error('Failed to download file "$fileName"', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки файла: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<bool> _checkAndRequestPermissions(String fileName) async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;

      List<Permission> permissionsToRequest = [];

      if (sdkInt >= 33) { 
        AppLogger.info('Android SDK $sdkInt >= 33. Requesting media specific permissions.');
        if (_isImageFile(fileName)) {
          permissionsToRequest.add(Permission.photos);
        } else if (_isVideoFile(fileName)) {
          permissionsToRequest.add(Permission.videos);
        } else if (_isAudioFile(fileName)) {
          permissionsToRequest.add(Permission.audio);
           AppLogger.info('File type is not media-specific. No specific permission needed on SDK 33+ for Downloads via MediaStore.');
           return true; 
        }
      } else { 
        AppLogger.info('Android SDK $sdkInt < 33. Requesting storage permission.');
        permissionsToRequest.add(Permission.storage);
      }

      if (permissionsToRequest.isNotEmpty) {
        Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();
        bool allGranted = statuses.values.every((status) => status.isGranted);
        if (!allGranted) {
           AppLogger.warning('Permissions not granted: $statuses');
           statuses.forEach((perm, status) {
               if (!status.isGranted) {
                   AppLogger.error('Permission denied: $perm');
               }
           });
        }
        return allGranted;
      } else {
          return true; 
      }

    } else if (Platform.isIOS) {
      if (_isImageFile(fileName) || _isVideoFile(fileName)) {
        AppLogger.info('iOS: Requesting Photos permission for media file.');
        final status = await Permission.photos.request();
        if (!status.isGranted) {
            AppLogger.warning('iOS Photos permission denied.');
        }
        return true;
      }
      return true; 
    }

    return true;
  }

  Future<Directory?> _getDownloadsDirectory() async {
    Directory? downloadsDir;
    try {
      if (Platform.isAndroid) {
        AppLogger.info('Attempting to get Downloads directory on Android...');
        
        // Try to get the public downloads directory first
        downloadsDir = await getExternalStorageDirectory();
        if (downloadsDir != null) {
          // Navigate up to the root of external storage
          String path = downloadsDir.path;
          List<String> pathParts = path.split('/');
          while (pathParts.isNotEmpty && pathParts.last != 'Android') {
            pathParts.removeLast();
          }
          if (pathParts.isNotEmpty) {
            pathParts.removeLast(); // Remove 'Android'
            String externalPath = pathParts.join('/');
            downloadsDir = Directory('$externalPath/Download');
            AppLogger.info('Using Android public Downloads directory: ${downloadsDir.path}');
            
            // Check if directory exists and is writable
            if (await downloadsDir.exists() && await _isDirectoryWritable(downloadsDir)) {
              return downloadsDir;
            }
          }
        }
        
        // Fallback to app-specific directory
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory(path.join(appDocDir.path, 'Downloads'));
        AppLogger.info('Using app-specific directory as fallback: ${downloadsDir.path}');
        
      } else if (Platform.isIOS) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory(path.join(appDocDir.path, 'Downloads'));
        AppLogger.info('Using app documents directory for Downloads on iOS: ${downloadsDir.path}');
        
      } else if (Platform.isWindows) {
        final String? downloadsPath = await getDownloadsPath();
        if (downloadsPath != null) {
          downloadsDir = Directory(downloadsPath);
          AppLogger.info('Using Windows Downloads directory: ${downloadsDir.path}');
        } else {
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          downloadsDir = Directory(path.join(appDocDir.path, 'Downloads'));
          AppLogger.warning('Using app documents directory as fallback on Windows: ${downloadsDir.path}');
        }
      } else {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory(path.join(appDocDir.path, 'Downloads'));
        AppLogger.warning('Using app documents directory as fallback: ${downloadsDir.path}');
      }
      
      // Create directory if it doesn't exist
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
        AppLogger.info('Created downloads directory: ${downloadsDir.path}');
      }
      
    } catch (e, s) {
      AppLogger.error('Error getting downloads directory', e, s);
      return null;
    }
    return downloadsDir;
  }

  Future<bool> _isDirectoryWritable(Directory directory) async {
    try {
      final testFile = File('${directory.path}/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      AppLogger.error('Directory is not writable: ${directory.path}', e, StackTrace.current);
      return false;
    }
  }

  bool _isImageFile(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.gif' || ext == '.bmp' || ext == '.webp';
  }

  bool _isVideoFile(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    return ext == '.mp4' || ext == '.mov' || ext == '.avi' || ext == '.wmv' || ext == '.mkv';
  }

  bool _isAudioFile(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    return ext == '.mp3' || ext == '.wav' || ext == '.m4a' || ext == '.ogg' || ext == '.aac';
  }

  Future<String?> getDownloadsPath() async {
    if (!Platform.isWindows) return null;
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir.path;

      final String? userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final winDownloadsPath = path.join(userProfile, 'Downloads');
        if (await Directory(winDownloadsPath).exists()) {
          return winDownloadsPath;
        }
      }
    } catch (e, s) {
      AppLogger.error("Error getting Windows Downloads path", e, s);
    }
    return null; 
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2A2A2A),
      title: StreamBuilder<ChatEntity?>(
        stream: _chatStream,
        initialData: null,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _currentChatEntity = snapshot.data;
          }
          
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