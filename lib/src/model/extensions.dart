/// Методи розширення вбудованих типів, корисні для предметної області.
library;

import 'task.dart';
import 'text_utils.dart';

/// Календарні операції над [DateTime].
extension CalendarDate on DateTime {
  /// Календарна дата без часу доби, в UTC.
  ///
  /// UTC обрано, щоб перехід на літній/зимовий час не робив добу
  /// коротшою чи довшою і `inDays` не помилявся на день.
  DateTime get dateOnly => DateTime.utc(year, month, day);

  /// Кількість календарних днів від цієї дати до [other].
  int daysUntil(DateTime other) => other.dateOnly.difference(dateOnly).inDays;

  /// Дата у форматі `РРРР-ММ-ДД`.
  String get iso => toIso8601String().substring(0, 10);
}

/// Строгий розбір дати з рядка.
extension StrictDateParsing on String {
  /// Розбирає рядок `РРРР-ММ-ДД` у дату UTC; `null` — якщо формат
  /// хибний або такого дня не існує (`2026-09-31`).
  ///
  /// `DateTime.tryParse` нормалізує неіснуючі дати, тому місяць і день
  /// після розбору звіряються з іменованими групами регулярного виразу.
  DateTime? toStrictDate() {
    final match = isoDatePattern.firstMatch(this);
    final parsed = DateTime.tryParse(this);
    if (match == null || parsed == null) return null;
    final month = int.tryParse(match.namedGroup('month') ?? '');
    final day = int.tryParse(match.namedGroup('day') ?? '');
    return parsed.month == month && parsed.day == day ? parsed.dateOnly : null;
  }
}

/// Агрегування колекції завдань.
extension TaskCollection on Iterable<Task> {
  /// Сумарна трудомісткість усіх завдань у годинах.
  double get totalHours => map((t) => t.estimateHours).fold(0, (a, b) => a + b);

  /// Трудомісткість незавершених завдань (`where → map → fold`).
  double get remainingHours =>
      where((t) => !t.status.isFinished)
          .map((t) => t.estimateHours)
          .fold(0, (a, b) => a + b);

  /// Завдання, згруповані за кодом проєкту.
  Map<String, List<Task>> groupByProject() => fold(
    <String, List<Task>>{},
    (groups, t) => groups..putIfAbsent(t.project, () => []).add(t),
  );

  /// Нова відсортована копія за пріоритетом (від найвищого),
  /// за рівності — за терміном.
  List<Task> byUrgency() => toList()
    ..sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      return byPriority != 0 ? byPriority : a.deadline.compareTo(b.deadline);
    });
}
