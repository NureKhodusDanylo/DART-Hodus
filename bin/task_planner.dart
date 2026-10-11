import 'package:task_planner/task_planner.dart';

/// Точка входу: будує об'єктну модель завдань і демонструє її можливості.
///
/// Необов'язковий аргумент — дата звіту у форматі `РРРР-ММ-ДД`
/// (за замовчуванням — поточна дата).
void main(List<String> arguments) {
  final now = arguments.firstOrNull?.toStrictDate() ?? DateTime.now().dateOnly;

  // 1. Розбір рядків у об'єкти.
  _section('1. Розбір рядків: Task.tryParse');
  final parsed = [
    for (final line in rawTasks) (line: line, result: Task.tryParse(line)),
  ];
  for (final (:line, :result) in parsed) {
    if (result case (task: null, :final String error)) {
      print('  ✗ $error\n      ← $line');
    }
  }
  final candidates = [
    for (final p in parsed)
      if (p.result.task case final Task task) task,
  ];
  print('Розібрано ${candidates.length} з ${rawTasks.length}');

  // 2. Перевірка узгодженості полів.
  _section('2. Перевірка правил узгодженості');
  for (final task in candidates.where((t) => !t.isValid)) {
    print('  ${task.id}:');
    for (final v in task.violations) {
      print('      - $v');
    }
  }
  final repo = Repository<Task>.of(candidates.where((t) => t.isValid));
  print('У сховищі: ${repo.length} коректних завдань');

  // 3. Конструктори та рівність.
  _section('3. Конструктори, == і hashCode');
  final line = rawTasks.first;
  final a = Task.fromCsv(line);
  final b = Task.fromCsv(line);
  print('fromCsv двічі: identical = ${identical(a, b)}, == ${a == b}');
  print(
    'cached двічі: identical = '
    '${identical(Task.cached(line), Task.cached(line))}',
  );
  print('Set з двох однакових завдань: розмір ${{a, b}.length}');
  print(
    'Змінений стан: ${a.withStatus(const Todo()) == a ? 'рівні' : 'різні'}',
  );
  print(a);

  // 4. Узагальнене сховище.
  _section('4. Узагальнене сховище Repository<T>');
  final projects = Repository<Project>.of(knownProjects);
  print('Проєктів: ${projects.length}, MOB → ${projects.findById('MOB')}');
  print('Завдання API-305 → ${repo.findById('API-305')}');
  print('Завдання XYZ-1 → ${repo.findById('XYZ-1') ?? 'не знайдено'}');

  // 5. Запечатана ієрархія станів.
  _section('5. Запечатана ієрархія TaskStatus');
  for (final status in const [Todo(), InProgress(), Done(), Blocked()]) {
    final count = repo.where((t) => t.status == status).length;
    print(
      '  ${statusMark(status)} ${status.label.padRight(22)} '
      'прогрес ${(status.progress * 100).round()}%, завдань: $count',
    );
  }

  // 6. Домішка Scheduled у різних гілках ієрархії.
  _section('6. Домішка Scheduled: завдання і віхи');
  final milestones = [
    Milestone('M-1', 'Бета-реліз вебзастосунку', DateTime.utc(2026, 10, 30)),
    Milestone(
      'M-2',
      'Демонстрація замовнику',
      DateTime.utc(2026, 10, 10),
      reached: true,
    ),
  ];
  final scheduled = <Scheduled>[
    ...repo.where((t) => t.project == 'WEB'),
    ...milestones,
  ];
  for (final item in scheduled) {
    print('  ${item.deadlineNote(now)}');
  }

  // 7. Методи розширення.
  _section('7. Методи розширення');
  print(
    'Сьогодні: ${now.iso}, до 2026-12-31: ${now.daysUntil(DateTime.utc(2026, 12, 31))} дн.',
  );
  print(
    'Усього: ${formatHours(repo.all.totalHours)}, '
    'залишок: ${formatHours(repo.all.remainingHours)}',
  );
  for (final MapEntry(:key, :value) in repo.all.groupByProject().entries) {
    print('  $key: ${value.length} завд., ${formatHours(value.totalHours)}');
  }

  // 8. Перелічення з членами.
  _section('8. Перелічення Priority');
  for (final p in Priority.values.reversed) {
    final ids = repo.where((t) => t.priority == p).map((t) => t.id);
    print(
      '  ${p.level} ${p.label.padRight(10)} високий: ${p.isHigh ? 'так' : 'ні '}  ${ids.join(', ')}',
    );
  }

  // 9. Записи та зіставлення зі зразком.
  _section('9. Записи та зіставлення зі зразком');
  final (:done, :open, :remainingHours) = progressOf(repo.all);
  print(
    'Виконано $done, відкрито $open, залишок з урахуванням стану: '
    '${formatHours(remainingHours)}',
  );
  for (final t in repo.all.byUrgency().take(6)) {
    print('  ${t.id.padRight(8)} ${urgencyOf(t, now)}');
  }

  // 10. Звіт.
  _section('10. Звіт');
  print(buildReport(repo.all, now: now));
}

/// Друкує заголовок розділу [title].
void _section(String title) => print('\n=== $title ===');
