@echo off
REM Запускаем все тесты с генерацией файла покрытия
flutter test --coverage

REM Для Windows требуется lcov для генерации HTML-отчетов
REM Его можно установить через Chocolatey: choco install lcov
REM Или использовать встроенные инструменты для просмотра lcov.info

REM Если lcov установлен, генерируем HTML-отчет
where genhtml > nul 2>&1
if %ERRORLEVEL% equ 0 (
    genhtml coverage\lcov.info -o coverage\html
    start coverage\html\index.html
    echo HTML coverage report generated at coverage\html\index.html
) else (
    echo LCOV not found. Install it with 'choco install lcov' or use a different tool to view coverage\lcov.info
)

echo Test coverage info saved to coverage\lcov.info 