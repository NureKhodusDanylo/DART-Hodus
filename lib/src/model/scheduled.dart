/// Домішка для сутностей, що мають термін.
library;

import 'extensions.dart';
import 'identifiable.dart';

/// Поведінка сутностей з терміном виконання.
///
/// Термін мають завдання й віхи, які стоять у різних гілках моделі,
/// а проєкти — ні. Тому поведінку не винесено в спільний надклас
/// [Entity]: інакше проєкт отримав би безглуздий термін.
///
/// Обмеження `on Entity` робить дві речі: домішку можна підмішати лише
/// до сутностей, і всередині неї доступні члени [Entity] — `id` та
/// `displayName`.
mixin Scheduled on Entity {
  /// Термін виконання (календарна дата в UTC).
  DateTime get deadline;

  /// Чи вважається сутність завершеною — тоді термін не відстежується.
  bool get isClosed => false;

  /// Кількість днів до терміну на момент [now]; від'ємна — прострочено.
  int daysLeft(DateTime now) => now.dateOnly.daysUntil(deadline);

  /// Чи прострочено незавершену сутність на момент [now].
  bool isOverdue(DateTime now) => !isClosed && daysLeft(now) < 0;

  /// Короткий опис терміну для виводу.
  String deadlineNote(DateTime now) {
    final left = daysLeft(now);
    final when = left < 0 ? 'прострочено на ${-left} дн.' : 'через $left дн.';
    return '$id «$displayName»: термін ${deadline.iso} — '
        '${isClosed ? 'закрито' : when}';
  }
}
