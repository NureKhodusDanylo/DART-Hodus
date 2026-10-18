/// Робота з рядками та регулярними виразами.
library;

import 'constants.dart';

/// Шаблон ідентифікатора завдання: код проєкту з 2–5 великих латинських
/// літер, дефіс і номер з 1–4 цифр, наприклад `WEB-101`.
final RegExp taskIdPattern = RegExp(
  r'^(?<project>[A-Z]{2,5})-(?<number>\d{1,4})$',
);

/// Шаблон дати у форматі `РРРР-ММ-ДД`.
final RegExp isoDatePattern = RegExp(
  r'^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})$',
);

/// Шаблон цифри, за якою йде ще хоча б одна цифра (усі, крім останньої).
final RegExp _maskableDigit = RegExp(r'\d(?=\d)');

/// Перевіряє, чи відповідає [id] формату ідентифікатора завдання.
bool isValidTaskId(String id) => taskIdPattern.hasMatch(id);

/// Повертає код проєкту з ідентифікатора [id] або `null`,
/// якщо формат некоректний.
String? projectFromId(String id) =>
    taskIdPattern.firstMatch(id)?.namedGroup('project');

/// Маскує всі цифри номера в [id], крім останньої: `WEB-101` → `WEB-**1`.
String maskTaskId(String id) =>
    id.replaceAllMapped(_maskableDigit, (_) => maskChar);

/// Обрізає [text] до [width] символів із трикрапкою та доповнює пробілами.
String fitColumn(String text, int width) {
  final fitted = text.length <= width
      ? text
      : '${text.substring(0, width - 1)}…';
  return fitted.padRight(width);
}

/// Форматує кількість годин [hours] з фіксованою кількістю знаків.
String formatHours(double hours) =>
    '${hours.toStringAsFixed(hoursFractionDigits)} год';
