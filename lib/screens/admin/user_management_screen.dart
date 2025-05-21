import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:monkey_messanger/models/user_entity.dart';
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_constants.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<UserEntity> _users = [];
  List<UserEntity> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filterUsers();
    });
  }

  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = List.from(_users);
    } else {
      _filteredUsers = _users.where((user) {
        return user.name.toLowerCase().contains(_searchQuery) ||
               user.email.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserEntity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      setState(() {
        _users = users;
        _filterUsers();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Ошибка при загрузке пользователей: $e');
    }
  }

  Future<void> _toggleUserBan(UserEntity user) async {
    final bool isBanned = user.role == 'banned';
    
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.id)
          .update({
        'role': isBanned ? AppConstants.userRole : 'banned',
      });

      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        final updatedUser = user.copyWith(
          role: isBanned ? AppConstants.userRole : 'banned',
        );
        setState(() {
          _users[index] = updatedUser;
          _filterUsers();
        });
      }

      _showSuccessSnackBar(
        isBanned ? 'Пользователь разблокирован' : 'Пользователь заблокирован'
      );
    } catch (e) {
      _showErrorSnackBar('Ошибка: $e');
    }
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

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Text('Пользователи не найдены'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final bool isBanned = user.role == 'banned';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryColor,
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null ? Text(user.name[0].toUpperCase()) : null,
            ),
            title: Text(user.name, 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isBanned ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                Text(
                  'Роль: ${user.role}',
                  style: TextStyle(
                    color: user.role == AppConstants.adminRole 
                      ? Colors.orange 
                      : isBanned ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: user.role != AppConstants.adminRole
              ? ElevatedButton(
                  onPressed: () => _toggleUserBan(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBanned ? Colors.green : Colors.red,
                  ),
                  child: Text(isBanned ? 'Unban' : 'Ban'),
                )
              : const Text('Админ', style: TextStyle(color: Colors.orange)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск пользователей',
                hintText: 'Введите имя или email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                filled: true,
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: _buildUserList(),
            ),
          ),
        ],
      ),
    );
  }
} 