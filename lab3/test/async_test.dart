import 'dart:async';
import 'dart:isolate';

import 'package:task_planner/task_planner.dart';
import 'package:test/test.dart';

void main() {
  final tasks = [
    for (final line in rawTasks)
      if (Task.tryParse(line).task case final Task t when t.isValid) t,
  ];

  group('AsyncRepository', () {
    late AsyncRepository<Task> repo;

    setUp(() async {
      repo = AsyncRepository<Task>(latency: Duration.zero);
      await repo.saveAll(tasks.take(3));
    });

    test('load повертає збережене завдання', () async {
      expect(await repo.load('WEB-101'), tasks.first);
    });

    test('load повертає null для відсутнього id', () {
      expect(repo.load('NOPE-1'), completion(isNull));
    });

    test('delete видаляє і повідомляє про результат', () async {
      expect(await repo.delete('WEB-102'), isTrue);
      expect(await repo.delete('WEB-102'), isFalse);
      expect(await repo.loadAll(), hasLength(2));
    });

    test('loadOrThrow завершується помилкою EntityNotFound', () async {
      await expectLater(
        repo.loadOrThrow('NOPE-1'),
        throwsA(isA<EntityNotFound>().having((e) => e.id, 'id', 'NOPE-1')),
      );
    });

    test('watchAll видає сутності в порядку додавання', () async {
      await expectLater(
        repo.watchAll(interval: Duration.zero).map((t) => t.id),
        emitsInOrder(['WEB-101', 'WEB-102', 'WEB-103', emitsDone]),
      );
    });

    test('watchAll лінивий: тіло не виконується до підписки', () async {
      var started = false;
      final stream = repo.watchAll(
        interval: Duration.zero,
        onStart: () => started = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(started, isFalse);
      await stream.first;
      expect(started, isTrue);
    });
  });

  group('TaskEventSource', () {
    late TaskEventSource source;

    setUp(() => source = TaskEventSource());

    tearDown(() async {
      if (!source.isClosed) await source.close();
    });

    test(
      'події, додані до підписки, не губляться і йдуть по порядку',
      () async {
        source
          ..emit(const TaskDeleted('A'))
          ..emit(const TaskDeleted('B'));
        unawaited(source.close());
        await expectLater(
          source.stream.map((e) => e.taskId),
          emitsInOrder(['A', 'B', emitsDone]),
        );
      },
    );

    test('помилка посередині потоку передається слухачу', () async {
      source
        ..emit(const TaskDeleted('A'))
        ..fail(StateError('збій'));
      unawaited(source.close());
      await expectLater(
        source.stream,
        emitsInOrder([isA<TaskDeleted>(), emitsError(isStateError), emitsDone]),
      );
    });

    test('другий слухач одноразового потоку отримує StateError', () async {
      final sub = source.stream.listen((_) {});
      expect(() => source.stream.listen((_) {}), throwsStateError);
      await sub.cancel();
    });
  });

  group('паралелізм', () {
    test('.wait збирає значення й помилки за позиціями', () async {
      await expectLater(
        [
          slowOperation('A', delay: Duration.zero),
          slowOperation('B', delay: Duration.zero, fail: true),
        ].wait,
        throwsA(
          isA<ParallelWaitError<List<String?>, List<AsyncError?>>>().having(
            (e) => e.values,
            'values',
            ['A', null],
          ),
        ),
      );
    });

    test(
      'Isolate.run дає той самий результат, що й синхронний виклик',
      () async {
        final expected = simulateWorkload(1000);
        expect(await Isolate.run(() => simulateWorkload(1000)), expected);
      },
    );
  });

  group('конвеєри потоків', () {
    test('where → map → take відбирає перші дві зміни стану', () async {
      final events = Stream<TaskEvent>.fromIterable(const [
        TaskDeleted('DOC-402'),
        StatusChanged('WEB-102', InProgress(), Done()),
        TaskDeleted('API-302'),
        StatusChanged('API-305', Blocked(), InProgress()),
        StatusChanged('MOB-202', Todo(), InProgress()),
      ]);
      await expectLater(
        events.where((e) => e is StatusChanged).map((e) => e.taskId).take(2),
        emitsInOrder(['WEB-102', 'API-305', emitsDone]),
      );
    });

    test(
      'широкомовне джерело: два слухачі, подія до підписки губиться',
      () async {
        final source = TaskEventSource(broadcast: true)
          ..emit(const TaskDeleted('ДО-ПІДПИСКИ'));
        final a = <String>[];
        final b = <String>[];
        final subA = source.stream.listen((e) => a.add(e.taskId));
        final subB = source.stream.listen((e) => b.add(e.taskId));
        source.emit(const TaskDeleted('API-302'));
        await Future<void>.delayed(Duration.zero);
        expect(a, ['API-302']);
        expect(b, ['API-302']);
        await subA.cancel();
        await subB.cancel();
        await source.close();
      },
    );
  });
}
