# Monkey Messenger Email Service

Сервис для отправки электронных писем для двухфакторной аутентификации в приложении Monkey Messenger.

## Установка

1. Клонируйте репозиторий
2. Установите зависимости:
   ```
   npm install
   ```
3. Создайте файл `.env` на основе `.env.example` и заполните нужными значениями

## Настройка переменных окружения

Для работы сервиса нужно указать следующие переменные в файле `.env`:

- `PORT` - порт на котором будет запущен сервер (по умолчанию 3000)
- `EMAIL_SERVICE` - сервис отправки почты (например, 'gmail')
- `EMAIL_USER` - адрес электронной почты для отправки писем
- `EMAIL_PASSWORD` - пароль или app-password для почтового сервиса
- `API_KEY` - ключ API для защиты от несанкционированного доступа

### Настройка Gmail

Если вы используете Gmail, вам необходимо включить двухэтапную аутентификацию и создать пароль приложения:

1. Войдите в свой аккаунт Google
2. Перейдите в "Безопасность" → "Двухэтапная аутентификация"
3. Включите двухэтапную аутентификацию
4. Затем перейдите в "Пароли приложений"
5. Создайте новый пароль для приложения
6. Используйте этот пароль в переменной `EMAIL_PASSWORD`

## Запуск сервера

Для запуска в режиме разработки:
```
npm run dev
```

Для запуска в обычном режиме:
```
npm start
```

## API Endpoints

### GET /
Проверка состояния сервера.

### POST /api/send-verification-code
Отправляет код верификации на указанный email.

Заголовки:
- `x-api-key`: API ключ для авторизации

Тело запроса:
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

Ответ:
```json
{
  "success": true,
  "message": "Verification code sent successfully"
}
```

## Интеграция с клиентским приложением

1. Добавьте переменную `EMAIL_SERVICE_URL` в клиентском приложении
2. Выполняйте HTTP-запрос к `/api/send-verification-code` с соответствующими параметрами

### Пример интеграции с Flutter:

```dart
Future<bool> sendVerificationEmail(String email, String code) async {
  try {
    final response = await http.post(
      Uri.parse('${Constants.EMAIL_SERVICE_URL}/api/send-verification-code'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': Constants.EMAIL_SERVICE_API_KEY,
      },
      body: jsonEncode({
        'email': email,
        'code': code,
      }),
    );
    
    final data = json.decode(response.body);
    return data['success'] == true;
  } catch (e) {
    print('Error sending verification email: $e');
    return false;
  }
}
``` 