/// Розбір дат і арифметика дат.
library;

import 'constants.dart';
import 'model.dart';
import 'text_utils.dart';

/// Строго розбирає дату у форматі `РРРР-ММ-ДД`.
///
/// `DateTime.tryParse` нормалізує неіснуючі дати (`2026-09-31` перетворюється
/// на 1 жовтня), тому після розбору компоненти звіряються з іменованими
/// групами регулярного виразу. Дата повертається в UTC, щоб перехід на
/// літній/зимовий час не спотворював різницю в днях. Повертає `null`,
/// якщо дата некоректна.
DateTime? parseStrictDate(String raw) {
  final match = isoDatePattern.firstMatch(raw);
  final parsed = DateTime.tryParse(raw);
  if (match == null || parsed == null) return null;

  final month = int.tryParse(match.namedGroup('month') ?? '');
  final day = int.tryParse(match.namedGroup('day') ?? '');
  final isSameDate = parsed.month == month && parsed.day == day;
  return isSameDate ? dateOnly(parsed) : null;
}

/// Відкидає час доби, залишаючи лише календарну дату [moment] в UTC.
DateTime dateOnly(DateTime moment) =>
    DateTime.utc(moment.year, moment.month, moment.day);

/// Обчислює вік завдання в днях від дати створення до [now].
int ageInDays(Task task, DateTime now) =>
    dateOnly(now).difference(task.createdAt).inDays;

/// Обчислює кількість днів до терміну виконання (від'ємна — прострочено).
int daysUntilDeadline(Task task, DateTime now) =>
    task.deadline.difference(dateOnly(now)).inDays;

/// Тривалість, відведена на виконання завдання (від створення до терміну).
Duration plannedDuration(Task task) => task.deadline.difference(task.createdAt);

/// Перевіряє, чи прострочене незавершене завдання на момент [now].
bool isOverdue(Task task, DateTime now) =>
    task.status != statusDone && task.deadline.isBefore(dateOnly(now));

/// Перевіряє, чи настає термін незавершеного завдання протягом
/// [dueSoonWindow] від [now].
bool isDueSoon(Task task, DateTime now) {
  final left = task.deadline.difference(dateOnly(now));
  return task.status != statusDone && !left.isNegative && left <= dueSoonWindow;
}

/// Форматує дату [date] як `РРРР-ММ-ДД`.
String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
