/// Форматування текстового звіту.
library;

import 'constants.dart';
import 'dates.dart';
import 'model.dart';
import 'pipelines.dart';
import 'text_utils.dart';

/// Формує текстовий звіт за списком [items].
///
/// До звіту потрапляють [topCount] завдань, відсортованих за пріоритетом
/// (напрям задає [ascending]; за замовчуванням — від найважливіших),
/// а за рівного пріоритету — за терміном. Колонки розділяються
/// [separator]. Момент [now] не може бути значенням за замовчуванням,
/// бо `DateTime.now()` не є константою, тому параметр nullable.
String buildReport(
  List<Task> items, {
  int topCount = defaultTopCount,
  bool ascending = false,
  String separator = defaultColumnSeparator,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  final top = sortTasks(items, ascending: ascending).take(topCount);
  final buffer = StringBuffer()
    ..writeln('ЗВІТ ПЛАНУВАЛЬНИКА на ${formatDate(moment)}')
    ..writeln(
      'Усього завдань: ${items.length}, '
      'залишок роботи: ${formatHours(remainingHours(items))}',
    )
    ..writeln()
    ..writeln('Топ-$topCount за пріоритетом:');

  for (final t in top) {
    buffer.writeln(
      [
        maskTaskId(t.id),
        fitColumn(t.title, titleColumnWidth),
        'P${t.priority}',
        formatDate(t.deadline),
        t.status.padRight(statusInProgress.length),
        formatHours(t.estimateHours),
        'днів до терміну: ${daysUntilDeadline(t, moment)}',
      ].join(separator),
    );
  }
  return buffer.toString();
}
