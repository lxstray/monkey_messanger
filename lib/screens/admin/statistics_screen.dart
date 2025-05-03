import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_constants.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = false;
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalChats = 0;
  int _privateChats = 0;
  int _groupChats = 0;
  int _totalMessages = 0;
  int _textMessages = 0;
  int _mediaMessages = 0;
  DateTime _lastRefreshed = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get user statistics
      final usersSnapshot = await firestore.collection(AppConstants.usersCollection).get();
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      
      _totalUsers = usersSnapshot.docs.length;
      _activeUsers = usersSnapshot.docs.where((doc) {
        final data = doc.data();
        if (data.containsKey('lastActive')) {
          final lastActive = data['lastActive'];
          if (lastActive is Timestamp) {
            return lastActive.toDate().isAfter(oneWeekAgo);
          } else if (lastActive is int) {
            return DateTime.fromMillisecondsSinceEpoch(lastActive).isAfter(oneWeekAgo);
          }
        }
        return false;
      }).length;
      
      // Get chat statistics
      final chatsSnapshot = await firestore.collection(AppConstants.chatsCollection).get();
      _totalChats = chatsSnapshot.docs.length;
      
      _privateChats = chatsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['isGroup'] == false;
      }).length;
      
      _groupChats = chatsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['isGroup'] == true;
      }).length;
      
      // Get message statistics
      int textMsgCount = 0;
      int mediaMsgCount = 0;
      int totalMsgCount = 0;
      
      for (var chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await firestore
            .collection(AppConstants.chatsCollection)
            .doc(chatDoc.id)
            .collection(AppConstants.messagesCollection)
            .get();
            
        totalMsgCount += messagesSnapshot.docs.length;
        
        for (var msgDoc in messagesSnapshot.docs) {
          final data = msgDoc.data();
          final messageType = data['type'] as int?;
          
          if (messageType == 0) { // Text message
            textMsgCount++;
          } else if (messageType == 1 || messageType == 2 || messageType == 3) { // Media messages
            mediaMsgCount++;
          }
        }
      }
      
      setState(() {
        _totalMessages = totalMsgCount;
        _textMessages = textMsgCount;
        _mediaMessages = mediaMsgCount;
        _lastRefreshed = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при загрузке статистики: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }
  
  Widget _buildStatisticCard({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> statistics,
    Color? color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? AppColors.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            ...statistics.map((stat) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stat['name']),
                  Text(
                    '${stat['value']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Статистика',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Обновлено: ${DateFormat('dd.MM.yyyy HH:mm').format(_lastRefreshed)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // User statistics
                    _buildStatisticCard(
                      title: 'Пользователи',
                      icon: Icons.people,
                      color: Colors.blue,
                      statistics: [
                        {'name': 'Всего пользователей', 'value': _totalUsers},
                        {'name': 'Активных за неделю', 'value': _activeUsers},
                        {'name': 'Неактивных за неделю', 'value': _totalUsers - _activeUsers},
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Chat statistics
                    _buildStatisticCard(
                      title: 'Чаты',
                      icon: Icons.chat,
                      color: Colors.green,
                      statistics: [
                        {'name': 'Всего чатов', 'value': _totalChats},
                        {'name': 'Приватных чатов', 'value': _privateChats},
                        {'name': 'Групповых чатов', 'value': _groupChats},
                        {'name': 'Среднее сообщений на чат', 'value': _totalChats > 0 ? (_totalMessages / _totalChats).toStringAsFixed(1) : '0'},
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Message statistics
                    _buildStatisticCard(
                      title: 'Сообщения',
                      icon: Icons.message,
                      color: Colors.orange,
                      statistics: [
                        {'name': 'Всего сообщений', 'value': _totalMessages},
                        {'name': 'Текстовых сообщений', 'value': _textMessages},
                        {'name': 'Медиа сообщений', 'value': _mediaMessages},
                        {'name': '% текстовых сообщений', 'value': _totalMessages > 0 ? '${(_textMessages * 100 / _totalMessages).toStringAsFixed(1)}%' : '0%'},
                        {'name': '% медиа сообщений', 'value': _totalMessages > 0 ? '${(_mediaMessages * 100 / _totalMessages).toStringAsFixed(1)}%' : '0%'},
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _loadStatistics,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Обновить статистику'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 