import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/screens/admin/user_management_screen.dart';
import 'package:monkey_messanger/screens/admin/chat_management_screen.dart';
import 'package:monkey_messanger/screens/admin/database_management_screen.dart';
import 'package:monkey_messanger/screens/admin/statistics_screen.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/auth_state.dart' as app_auth;
import 'package:monkey_messanger/utils/app_colors.dart';
import 'package:monkey_messanger/utils/app_constants.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const UserManagementScreen(),
    const ChatManagementScreen(),
    const DatabaseManagementScreen(),
    const StatisticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Check if user is admin
    final authState = context.read<AuthBloc>().state;
    if (authState.user?.role != AppConstants.adminRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Доступ запрещен. У вас нет прав администратора.'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, app_auth.AuthState>(
      builder: (context, state) {
        // Only show admin panel for admin users
        if (state.user?.role != AppConstants.adminRole) {
          return const Scaffold(
            body: Center(
              child: Text('Доступ запрещен'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Панель администратора'),
            centerTitle: true,
          ),
          body: _screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primaryColor,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Пользователи',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat),
                label: 'Чаты',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.storage),
                label: 'База данных',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Статистика',
              ),
            ],
          ),
        );
      },
    );
  }
} 