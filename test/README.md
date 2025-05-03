# Flutter Widget Tests for Monkey Messenger

This directory contains automated tests for the Monkey Messenger application. The tests verify the functionality of various widgets and screens in the application.

## Test Categories

1. **Chat Creation Tests** - Verify that users can create new group chats
2. **Voice Message Tests** - Test voice message recording and sending functionality
3. **Profile Editing Tests** - Test user profile editing features including avatar upload and 2FA settings

## Running Tests

### Running All Tests

To run all tests:

```bash
flutter test
```

### Running Specific Test Files

To run a specific test file:

```bash
flutter test test/widgets/create_group_chat_test.dart
flutter test test/widgets/chat_screen_voice_message_test.dart
flutter test test/widgets/profile_screen_test.dart
```

### Running Tests with Coverage

To run tests with coverage and generate a coverage report:

```bash
./test/run_coverage.bat
```

This will:
1. Run all tests with coverage enabled
2. Generate an HTML coverage report
3. Open the report in your default browser

## Test Structure

Each test file follows this structure:

1. **Mock Classes** - Mocks for dependencies like repositories, blocs, and services
2. **Setup** - Preparation code that runs before each test
3. **Widget Tests** - Individual test cases for widget behavior

## Test Best Practices

- Each test should focus on a single aspect of functionality
- Tests should be independent of each other
- Use mock objects to isolate the widget being tested
- Verify both UI elements and behavior

## Troubleshooting

If tests are failing, check:

1. Whether the widget structure has changed
2. If mock objects need to be updated
3. If data models have been modified 