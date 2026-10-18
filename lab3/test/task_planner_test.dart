import 'package:task_planner/task_planner.dart';
import 'package:test/test.dart';

void main() {
  group('Task', () {
    test('tryParse розбирає коректний рядок', () {
      final (:task, :error) = Task.tryParse(rawTasks.first);
      expect(error, isNull);
      expect(task?.priority, Priority.medium);
      expect(task?.status, const Done());
    });

    test('пріоритет поза 1..5 і невідомий стан не розбираються', () {
      expect(
        Task.tryParse('WEB-1;x;WEB;9;2026-01-01;2026-02-01;todo;1').error,
        contains('пріоритету'),
      );
      expect(
        Task.tryParse('WEB-1;x;WEB;1;2026-01-01;2026-02-01;review;1').error,
        contains('стан'),
      );
    });

    test('fromCsv кидає FormatException на пошкоджений рядок', () {
      expect(() => Task.fromCsv('a;b'), throwsFormatException);
    });

    test('рівність за значенням і робота в Set', () {
      final a = Task.fromCsv(rawTasks.first);
      final b = Task.fromCsv(rawTasks.first);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect({a, b}, hasLength(1));
    });

    test('фабричний конструктор повертає кешований екземпляр', () {
      expect(
        identical(Task.cached(rawTasks[1]), Task.cached(rawTasks[1])),
        isTrue,
      );
    });

    test('порушення узгодженості', () {
      final task = Task.fromCsv(rawTasks.last);
      expect(task.violations, hasLength(2));
    });
  });

  group('модель', () {
    final now = DateTime.utc(2026, 10, 15);
    final tasks = [
      for (final line in rawTasks)
        if (Task.tryParse(line).task case final Task t when t.isValid) t,
    ];

    test('13 коректних завдань', () => expect(tasks, hasLength(13)));

    test('Repository знаходить за id', () {
      final repo = Repository<Task>.of(tasks);
      expect(repo.findById('API-305')?.status, const Blocked());
      expect(repo.findById('NOPE-1'), isNull);
    });

    test('домішка Scheduled однаково працює для віхи', () {
      final m = Milestone('M-1', 'Реліз', DateTime.utc(2026, 10, 20));
      expect(m.daysLeft(now), 5);
      expect(m.isOverdue(now), isFalse);
    });

    test('охоронець when у зіставленні зі зразком', () {
      final overdueCritical = tasks.firstWhere((t) => t.id == 'WEB-103');
      expect(urgencyOf(overdueCritical, now), 'КРИТИЧНО: прострочено');
    });

    test('записи: progressOf', () {
      final (:done, :open, remainingHours: _) = progressOf(tasks);
      expect((done, open), (3, 10));
    });
  });
}
