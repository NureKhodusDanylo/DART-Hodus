/// Форматування текстового звіту.
library;

import 'analytics.dart';
import 'constants.dart';
import 'extensions.dart';
import 'task.dart';
import 'text_utils.dart';

/// Формує текстовий звіт за списком [items].
///
/// До звіту потрапляють [topCount] завдань, упорядкованих за
/// терміновістю (напрям задає [ascending]; за замовчуванням — від
/// найважливіших). Колонки розділяються [separator]. Момент [now] не
/// може бути значенням за замовчуванням, бо `DateTime.now()` не є
/// константою, тому параметр nullable.
String buildReport(
  List<Task> items, {
  int topCount = defaultTopCount,
  bool ascending = false,
  String separator = defaultColumnSeparator,
  DateTime? now,
}) {
  final moment = (now ?? DateTime.now()).dateOnly;
  final ordered = items.byUrgency();
  final top = (ascending ? ordered.reversed : ordered).take(topCount);
  final (:done, :open, :remainingHours) = progressOf(items);

  final buffer = StringBuffer()
    ..writeln('ЗВІТ ПЛАНУВАЛЬНИКА на ${moment.iso}')
    ..writeln(
      'Завдань: ${items.length} (виконано $done, відкрито $open), '
      'залишок роботи: ${formatHours(remainingHours)}',
    )
    ..writeln()
    ..writeln('Топ-$topCount за терміновістю:');

  for (final t in top) {
    buffer.writeln(
      [
        '${statusMark(t.status)} ${maskTaskId(t.id)}',
        fitColumn(t.title, titleColumnWidth),
        'P${t.priority.level}',
        t.deadline.iso,
        urgencyOf(t, moment),
      ].join(separator),
    );
  }
  return buffer.toString();
}
