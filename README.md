# Monkey Messenger

Messenger application с поддержкой двухфакторной аутентификации через email.

## Настройка проекта

1. Установите зависимости:
```bash
flutter pub get
```

2. Настройте Firebase:
```bash
flutterfire configure
```

3. Запустите приложение:
```bash
flutter run
```

## Двухфакторная аутентификация через Email

Для работы 2FA требуется настроить отдельный сервер для отправки email.

### Настройка Email сервера

1. Перейдите в директорию `email-service`
2. Установите зависимости:
```bash
cd email-service
npm install
```

3. Создайте и заполните файл `.env` на основе `.env.example`:
```
PORT=3000
EMAIL_SERVICE=gmail
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
API_KEY=your-secure-api-key
```

4. Запустите сервер:
```bash
npm run dev
```

5. Обновите константы в приложении (`lib/utils/app_constants.dart`):
```dart
// Email service configuration
static const String emailServiceUrl = 'http://your-server-address:3000';
static const String emailServiceApiKey = 'your-secure-api-key';
```

### Настройка Gmail для отправки писем

1. Включите двухэтапную аутентификацию в аккаунте Google
2. Создайте пароль приложения
3. Используйте этот пароль в переменной `EMAIL_PASSWORD`

## Примечания по разработке

Во время разработки, если email-сервер недоступен, код для 2FA будет отображаться во всплывающем диалоговом окне.
