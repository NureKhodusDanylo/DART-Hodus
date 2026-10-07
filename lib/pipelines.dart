/// Конвеєри обробки колекцій завдань: фільтрація, перетворення,
/// згортання, групування та сортування.
library;

import 'constants.dart';
import 'dates.dart';
import 'model.dart';
import 'text_utils.dart';

// ---------------------------------------------------------------------------
// Фільтрація
// ---------------------------------------------------------------------------

/// Відбирає незавершені завдання з пріоритетом не нижче
/// [highPriorityThreshold].
Iterable<Task> highPriorityOpen(Iterable<Task> tasks) => tasks.where(
  (t) => t.status != statusDone && t.priority >= highPriorityThreshold,
);

/// Відбирає прострочені на момент [now] завдання.
Iterable<Task> overdueTasks(Iterable<Task> tasks, DateTime now) =>
    tasks.where((t) => isOverdue(t, now));

/// Шукає завдання за ідентифікатором [id]; повертає `null`, якщо немає.
Task? findById(Iterable<Task> tasks, String id) =>
    tasks.where((t) => t.id == id).firstOrNull;

// ---------------------------------------------------------------------------
// Перетворення
// ---------------------------------------------------------------------------

/// Перетворює завдання на короткі рядки виду `WEB-101 [P3] Назва`.
List<String> toShortLines(Iterable<Task> tasks) =>
    tasks.map((t) => '${t.id} [P${t.priority}] ${t.title}').toList();

/// Перетворює завдання на пари «назва → днів до терміну» на момент [now].
Map<String, int> deadlinesInDays(Iterable<Task> tasks, DateTime now) => {
  for (final t in tasks) t.title: daysUntilDeadline(t, now),
};

// ---------------------------------------------------------------------------
// Згортання
// ---------------------------------------------------------------------------

/// Обчислює сумарну трудомісткість незавершених завдань
/// конвеєром `where → map → fold`.
double remainingHours(Iterable<Task> tasks) => tasks
    .where((t) => t.status != statusDone)
    .map((t) => t.estimateHours)
    .fold(0.0, (sum, hours) => sum + hours);

/// Обчислює кількість, суму, середнє, мінімум і максимум трудомісткості.
///
/// Повертає `null` для порожнього набору: середнє й екстремуми в цьому
/// випадку не визначені.
EstimateStats? estimateStats(Iterable<Task> tasks) {
  if (tasks.isEmpty) return null;
  final hours = tasks.map((t) => t.estimateHours);
  final total = hours.fold(0.0, (sum, h) => sum + h);
  final min = hours.fold(double.infinity, (m, h) => h < m ? h : m);
  final max = hours.fold(double.negativeInfinity, (m, h) => h > m ? h : m);
  final count = hours.length;
  return (
    count: count,
    total: total,
    average: total / count,
    min: min,
    max: max,
  );
}

/// Підраховує кількість завдань у кожному статусі.
Map<String, int> countByStatus(Iterable<Task> tasks) => tasks.fold(
  <String, int>{},
  (counts, t) => counts..update(t.status, (n) => n + 1, ifAbsent: () => 1),
);

// ---------------------------------------------------------------------------
// Групування
// ---------------------------------------------------------------------------

/// Групує завдання за кодом проєкту.
Map<String, List<Task>> groupByProject(Iterable<Task> tasks) => tasks.fold(
  <String, List<Task>>{},
  (groups, t) => groups..putIfAbsent(t.project, () => []).add(t),
);

/// Обчислює сумарну трудомісткість для кожної групи [groups].
Map<String, double> hoursPerGroup(Map<String, List<Task>> groups) => groups.map(
  (key, tasks) => MapEntry(
    key,
    tasks.map((t) => t.estimateHours).fold(0.0, (s, h) => s + h),
  ),
);

// ---------------------------------------------------------------------------
// Сортування
// ---------------------------------------------------------------------------

/// Порівнює завдання за пріоритетом.
int compareByPriority(Task a, Task b) => a.priority.compareTo(b.priority);

/// Порівнює завдання за терміном виконання.
int compareByDeadline(Task a, Task b) => a.deadline.compareTo(b.deadline);

/// Порівнює завдання за трудомісткістю.
int compareByEstimate(Task a, Task b) =>
    a.estimateHours.compareTo(b.estimateHours);

/// Повертає нову відсортовану копію [tasks].
///
/// Основний критерій — [by], додатковий (за рівності основного) —
/// [thenBy]. Напрям основного критерію задає [ascending]; додатковий
/// критерій завжди за зростанням.
List<Task> sortTasks(
  Iterable<Task> tasks, {
  TaskComparator by = compareByPriority,
  TaskComparator thenBy = compareByDeadline,
  bool ascending = true,
}) {
  final direction = ascending ? 1 : -1;
  return List.of(tasks)..sort((a, b) {
    final primary = by(a, b) * direction;
    return primary != 0 ? primary : thenBy(a, b);
  });
}

/// Форматує рядок групи для виводу: код, кількість і сума годин.
String describeGroup(String project, List<Task> tasks, double hours) =>
    '$project: ${tasks.length} завд., ${formatHours(hours)}';
