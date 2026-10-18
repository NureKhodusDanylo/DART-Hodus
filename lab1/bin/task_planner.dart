import 'package:task_planner/task_planner.dart';

/// Точка входу: розбирає, перевіряє та агрегує вхідні завдання.
///
/// Необов'язковий аргумент — дата звіту у форматі `РРРР-ММ-ДД`
/// (за замовчуванням — поточна дата).
void main(List<String> arguments) {
  final argDate = arguments.firstOrNull;
  final now =
      (argDate == null ? null : parseStrictDate(argDate)) ??
      dateOnly(DateTime.now());

  // 1. Розбір із лічильником-замиканням.
  final counter = makeCounter();
  final parsed = rawTasks.map((line) {
    counter.increment();
    return (line: line, result: parseLine(line));
  }).toList();

  _section('1. Розбір вхідних рядків');
  print('Оброблено рядків: ${counter.value()}');
  for (final (:line, :result) in parsed) {
    if (result case (task: null, :final String error)) {
      print('  ✗ $error\n      ← $line');
    }
  }

  // 2. Перевірка діапазонів.
  final candidates = [
    for (final p in parsed)
      if (p.result.task case final Task task) task,
  ];
  _section('2. Перевірка діапазонів');
  for (final task in candidates) {
    final violations = validateTask(task);
    if (violations.isNotEmpty) {
      print('  ${task.id}:');
      for (final v in violations) {
        print('      - $v');
      }
    }
  }
  final tasks = candidates.where(isValidTask).toList();
  print('Коректних завдань: ${tasks.length} з ${rawTasks.length}');

  // 3. Конвеєри: фільтрація, перетворення, згортання.
  _section('3. Конвеєри обробки');
  print('Незавершені високопріоритетні (P≥$highPriorityThreshold):');
  toShortLines(highPriorityOpen(tasks)).forEach(_bullet);
  print('Прострочені на ${formatDate(now)}:');
  toShortLines(overdueTasks(tasks, now)).forEach(_bullet);
  print(
    'Залишок роботи (where → map → fold): '
    '${formatHours(remainingHours(tasks))}',
  );
  final stats = estimateStats(tasks);
  if (stats != null) {
    print(
      'Трудомісткість: усього ${formatHours(stats.total)}, '
      'середня ${formatHours(stats.average)}, '
      'мін ${formatHours(stats.min)}, макс ${formatHours(stats.max)}',
    );
  }
  print('За статусами: ${countByStatus(tasks)}');

  // 4. Групування за проєктом.
  _section('4. Групування за проєктом');
  final groups = groupByProject(tasks);
  final hours = hoursPerGroup(groups);
  for (final MapEntry(key: project, value: items) in groups.entries) {
    _bullet(describeGroup(project, items, hours[project] ?? 0));
  }

  // 5. Сортування за двома критеріями.
  _section('5. Сортування');
  print('За терміном ↑, далі за пріоритетом:');
  toShortLines(
    sortTasks(tasks, by: compareByDeadline, thenBy: compareByPriority),
  ).forEach(_bullet);
  print('За трудомісткістю ↓, далі за терміном:');
  toShortLines(sortTasks(tasks, by: compareByEstimate, ascending: false))
      .forEach(_bullet);

  // 6. Фабрика предикатів (замикання).
  _section('6. Фабрика предикатів');
  final webUrgent = allOf([makeProjectFilter('WEB'), makePriorityFilter(4)]);
  toShortLines(tasks.where(webUrgent)).forEach(_bullet);

  // 7. Регулярні вирази та маскування.
  _section('7. Регулярні вирази');
  for (final id in ['WEB-101', 'mob_205', 'API-30001']) {
    _bullet(
      '$id → ${isValidTaskId(id) ? 'коректний' : 'некоректний'}, '
      'маска: ${maskTaskId(id)}',
    );
  }

  // 8. Арифметика дат.
  _section('8. Арифметика дат');
  for (final t in sortTasks(
    tasks.where((t) => t.status != statusDone),
    by: compareByDeadline,
  ).take(4)) {
    _bullet(
      '${t.id}: вік ${ageInDays(t, now)} дн., '
      'до терміну ${daysUntilDeadline(t, now)} дн., '
      'заплановано ${plannedDuration(t).inDays} дн.'
      '${isDueSoon(t, now) ? ' — термін найближчим часом' : ''}',
    );
  }
  final missing = findById(tasks, 'WEB-999');
  print('Пошук WEB-999: ${missing?.title ?? 'не знайдено'}');

  // 9. Звіт.
  _section('9. Звіт');
  print(buildReport(tasks, now: now));
}

/// Друкує заголовок розділу [title].
void _section(String title) => print('\n=== $title ===');

/// Друкує елемент списку [text].
void _bullet(String text) => print('  • $text');
