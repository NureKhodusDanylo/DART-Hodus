import 'package:task_planner/task_planner.dart';
import 'package:test/test.dart';

void main() {
  group('parseLine', () {
    test('розбирає коректний рядок', () {
      final result = parseLine(rawTasks.first);
      expect(result.error, isNull);
      expect(result.task?.id, 'WEB-101');
      expect(result.task?.estimateHours, 12);
    });

    test('відхиляє рядок із відсутнім полем', () {
      expect(parseLine('A-1;x;A;1;2026-01-01;todo;1').error, isNotNull);
    });

    test('відхиляє неіснуючу дату', () {
      expect(
        parseLine('API-1;x;API;1;2026-09-31;2026-10-01;todo;1').error,
        contains('дата'),
      );
    });

    test('рівно 4 пошкоджені рядки у вхідних даних', () {
      expect(
        rawTasks.map(parseLine).where((r) => r.task == null),
        hasLength(4),
      );
    });
  });

  group('validateTask', () {
    test('знаходить усі порушення', () {
      final task = parseLine(rawTasks.last).task;
      expect(task, isNotNull);
      if (task != null) expect(validateTask(task), hasLength(4));
    });
  });

  group('конвеєри', () {
    final tasks = rawTasks
        .map(parseLine)
        .map((r) => r.task)
        .nonNulls
        .where(isValidTask)
        .toList();

    test('групування за проєктом', () {
      expect(groupByProject(tasks).keys, containsAll(['WEB', 'MOB', 'API']));
    });

    test('сортування за спаданням пріоритету', () {
      final sorted = sortTasks(tasks, ascending: false);
      expect(sorted.first.priority, maxPriority);
    });

    test('маскування ідентифікатора', () {
      expect(maskTaskId('WEB-101'), 'WEB-**1');
    });
  });
}
