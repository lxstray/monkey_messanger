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
              if (_isUploading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF4A90E2),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Uploading...',
                          style: TextStyle(
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl ?? '',
                placeholder: (context, url) => Container(
                  height: 150,
                  width: 200,
                  padding: const EdgeInsets.all(8),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  width: 200,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white70, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                memCacheWidth: 800,
                maxWidthDiskCache: 800,
                fadeInDuration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        );
      case MessageType.file:
        return Row(
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
          ],
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
          
          if (mounted) {
            context.read<ChatBloc>().add(
              SendMessageEvent(
                chatId: widget.chatId,
                content: url,
                type: MessageType.image,
                senderId: widget.currentUser.id,
              ),
            );
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
          
          if (mounted) {
            context.read<ChatBloc>().add(
              SendMessageEvent(
                chatId: widget.chatId,
                content: url,
                type: MessageType.file,
                senderId: widget.currentUser.id,
              ),
            );
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 