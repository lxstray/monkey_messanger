import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkey_messanger/services/auth_bloc.dart';
import 'package:monkey_messanger/services/email_service.dart';
import 'package:monkey_messanger/utils/app_logger.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  final String email;
  
  const TwoFactorAuthScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Automatically focus on the first input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
      
      // Автоматически показываем диалог с тестовым кодом
      _showTestCode();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code {
    return _controllers.map((c) => c.text).join();
  }

  void _verifyCode() async {
    if (_code.length != 6) {
      setState(() {
        _errorMessage = 'Пожалуйста, введите 6-значный код';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Use the AuthBloc to verify the code
      final authBloc = context.read<AuthBloc>();
      final isValid = await authBloc.verify2FACode(widget.email, _code);
      
      if (isValid) {
        // Code verification successful - AuthBloc will update the state
        if (mounted) {
          // Nothing to do here, AuthBloc state change will navigate to the main screen
        }
      } else {
        setState(() {
          _errorMessage = 'Неверный код. Пожалуйста, проверьте и попробуйте снова';
          _isVerifying = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error verifying 2FA code', e, stackTrace);
      setState(() {
        _errorMessage = 'Ошибка при проверке кода: ${e.toString()}';
        _isVerifying = false;
      });
    }
  }

  void _resendCode() async {
    try {
      final emailService = context.read<EmailService>();
      final sent = await emailService.sendVerificationCode(widget.email);
      
      if (sent && mounted) {
        // Показываем диалог с тестовым кодом
        _showTestCode();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Новый код отправлен на ваш email'),
            backgroundColor: Color(0xFF4A90E2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось отправить код. Пожалуйста, попробуйте позже'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error resending verification code', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Показать диалог с тестовым кодом для разработки и тестирования
  void _showTestCode() {
     AppLogger.info('Test code requested for ${widget.email}. Display mechanism needed.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Двухфакторная аутентификация',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.code, color: Colors.white, size: 22),
            onPressed: _showTestCode,
            tooltip: 'Показать тестовый код',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Подтвердите вход',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Мы отправили код подтверждения на ${widget.email}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Введите код для продолжения входа в приложение.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 40,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          // Clear error message when user starts typing
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                          
                          if (value.isNotEmpty && index < 5) {
                            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                          }
                          
                          // Auto-verify when all fields are filled
                          if (index == 5 && value.isNotEmpty) {
                            _verifyCode();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: const Color(0xFF4A90E2).withOpacity(0.5),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Подтвердить',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _resendCode,
                    child: Text(
                      'Не получили код? Отправить снова',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 