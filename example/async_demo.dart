/// Демонстрація асинхронності з ЛР3: сховище, потоки, ізолят.
///
/// Запуск: `dart run example/async_demo.dart`.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:task_planner/task_planner.dart';

/// Кількість синтетичних завдань для важкого обчислення.
const int _workloadSize = 3000000;

/// Період таймера, яким перевіряється, чи вільний цикл подій.
const Duration _tick = Duration(milliseconds: 10);

/// Точка входу: демонструє асинхронний шар, потоки та ізоляти.
Future<void> main() async {
  final tasks = [
    for (final line in rawTasks)
      if (Task.tryParse(line).task case final Task t when t.isValid) t,
  ];

  // 1. Асинхронне сховище.
  _section('1. Асинхронне сховище');
  final repo = AsyncRepository<Task>();
  await repo.saveAll(tasks);
  print('Збережено: ${(await repo.loadAll()).length} завдань');
  print('load(API-305) → ${await repo.load('API-305')}');
  print('delete(DOC-402) → ${await repo.delete('DOC-402')}');
  print('load(DOC-402) → ${await repo.load('DOC-402')}');

  // 2. Забутий await.
  _section('2. Забутий await');
  final pending = repo.load('WEB-101');
  print('Без await: ${pending.toString()}');
  print('З await:   ${await pending}');
  final draft = Task.fromCsv(
    'WEB-108;Сторінка помилки 404;WEB;2;2026-10-15;2026-11-05;todo;3',
  );
  // Навмисно «забутий» await: unawaited лише робить намір явним для лінтера.
  unawaited(repo.save(draft));
  print(
    'Одразу після save без await: '
    '${await repo.load(draft.id, delay: Duration.zero)}',
  );
  await Future<void>.delayed(repo.latency);
  print(
    'Через ${repo.latency.inMilliseconds} мс: ${await repo.load(draft.id)}',
  );

  // 3. Послідовно чи одночасно.
  _section('3. Послідовне й одночасне виконання');
  final sequential = await measure(() async {
    await slowOperation('A');
    await slowOperation('B');
    await slowOperation('C');
  });
  final concurrent = await measure(
    () => Future.wait([
      slowOperation('A'),
      slowOperation('B'),
      slowOperation('C'),
    ]),
  );
  print('Послідовно (3 × await):  ${sequential.elapsed.inMilliseconds} мс');
  print('Одночасно (Future.wait): ${concurrent.elapsed.inMilliseconds} мс');

  // 4. Помилка в групі операцій.
  _section('4. Помилка в групі: Future.wait і .wait');
  try {
    await Future.wait([
      slowOperation('A'),
      slowOperation('B', fail: true),
      slowOperation('C'),
    ]);
  } on StateError catch (e) {
    print('Future.wait: $e');
    print('  результати A і C недоступні');
  }
  try {
    await [
      slowOperation('A'),
      slowOperation('B', fail: true),
      slowOperation('C'),
    ].wait;
  } on ParallelWaitError<List<String?>, List<AsyncError?>> catch (e) {
    print('.wait: ParallelWaitError');
    print('  values = ${e.values}');
    print('  errors = ${e.errors.map((err) => err?.error)}');
  }

  // 5. Неспіймана асинхронна помилка.
  _section('5. try/catch навколо виклику без await');
  final zoneDone = Completer<void>();
  runZonedGuarded(
    () {
      try {
        unawaited(slowOperation('D', delay: _tick, fail: true));
        print('try завершився без винятку');
      } on StateError catch (e) {
        print('catch спіймав: $e');
      }
    },
    (error, stack) {
      print('Помилку спіймала лише зона: $error');
      zoneDone.complete();
    },
  );
  await zoneDone.future;

  // 6. Лінивий генератор async*.
  _section('6. Генератор async* і await for');
  final stream = repo.watchAll(
    onStart: () => print('  [генератор] почав виконувати тіло'),
  );
  print('Потік створено, підписки ще немає');
  await Future<void>.delayed(const Duration(milliseconds: 300));
  print('Підписуємось через await for');
  await for (final t in stream.take(3)) {
    print('  отримано ${t.id}');
  }

  // 7. StreamController: події до підписки та явне скасування.
  _section('7. StreamController і StreamSubscription');
  final source = TaskEventSource();
  source
    ..emit(TaskCreated(draft))
    ..emit(const StatusChanged('WEB-108', Todo(), InProgress()))
    ..emit(const StatusChanged('WEB-108', InProgress(), Done()));
  print('Три події додано до підписки');
  final received = <TaskEvent>[];
  final subscription = source.stream.listen(received.add);
  source.emit(const TaskDeleted('WEB-108'));
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  print('Отримано після підписки: $received');
  await source.close();

  // 8. Помилка посередині потоку.
  _section('8. Помилка в потоці: await for і listen(cancelOnError: false)');
  try {
    await for (final e in _streamWithError()) {
      print('  await for: $e');
    }
  } on StateError catch (e) {
    print('  await for зупинився: $e');
  }
  final listenDone = Completer<void>();
  final tolerant = _streamWithError().listen(
    (e) => print('  listen: $e'),
    onError: (Object e) => print('  listen onError: $e'),
    onDone: listenDone.complete,
    cancelOnError: false,
  );
  await listenDone.future;
  await tolerant.cancel();

  // 9. Одноразова і широкомовна підписка.
  _section('9. Одноразовий і широкомовний потоки');
  final single = TaskEventSource();
  final first = single.stream.listen((_) {});
  try {
    single.stream.listen((_) {});
  } on StateError catch (e) {
    print('Друга підписка на одноразовий потік: $e');
  }
  await first.cancel();
  await single.close();

  final broadcast = TaskEventSource(broadcast: true);
  broadcast.emit(const TaskDeleted('ДО-ПІДПИСКИ'));
  final heardA = <TaskEvent>[];
  final heardB = <TaskEvent>[];
  final subA = broadcast.stream.listen(heardA.add);
  final subB = broadcast.stream.listen(heardB.add);
  broadcast.emit(const TaskDeleted('API-302'));
  await Future<void>.delayed(Duration.zero);
  print('Широкомовний: слухач A $heardA, слухач B $heardB');
  await subA.cancel();
  await subB.cancel();
  await broadcast.close();

  // 10. Конвеєр трансформації потоку.
  _section('10. Конвеєр where → map → take');
  final changes = await _eventsFeed()
      .where((e) => e is StatusChanged)
      .map((e) => 'зміна стану: $e')
      .take(2)
      .toList();
  changes.forEach(print);

  // 11. Ізолят.
  _section('11. Важке обчислення: головний ізолят та Isolate.run');
  final syncRun = await _measureTicks(
    () async => simulateWorkload(_workloadSize),
  );
  print(
    'У головному ізоляті: ${syncRun.elapsed.inMilliseconds} мс, '
    'тиків таймера за цей час: ${syncRun.ticks}',
  );
  final isolateRun = await _measureTicks(
    () => Isolate.run(() => simulateWorkload(_workloadSize)),
  );
  print(
    'В Isolate.run:       ${isolateRun.elapsed.inMilliseconds} мс, '
    'тиків таймера за цей час: ${isolateRun.ticks}',
  );
  print('Результати збігаються: ${syncRun.value == isolateRun.value}');
  print('  ${syncRun.value}');
  print(
    'simulateWorkload запускалась двічі, а simulationRuns у головному '
    'ізоляті = $simulationRuns: інкремент в Isolate.run змінив копію змінної',
  );
}

/// Потік із трьох подій, друга з яких — помилка.
Stream<TaskEvent> _streamWithError() {
  final source = TaskEventSource()
    ..emit(const TaskDeleted('A-1'))
    ..fail(StateError('збій джерела подій'))
    ..emit(const TaskDeleted('A-2'));
  // close() завершиться, коли слухач дочитає потік, тому тут не чекаємо.
  unawaited(source.close());
  return source.stream;
}

/// Потік подій планувальника різних типів.
Stream<TaskEvent> _eventsFeed() async* {
  yield const TaskDeleted('DOC-402');
  yield const StatusChanged('WEB-102', InProgress(), Done());
  yield const TaskDeleted('API-302');
  yield const StatusChanged('API-305', Blocked(), InProgress());
  yield const StatusChanged('MOB-202', Todo(), InProgress());
}

/// Виконує [action], вимірюючи час і кількість спрацювань періодичного
/// таймера — показник того, чи був вільний цикл подій.
Future<({WorkloadSummary value, Duration elapsed, int ticks})> _measureTicks(
  Future<WorkloadSummary> Function() action,
) async {
  var ticks = 0;
  final timer = Timer.periodic(_tick, (_) => ticks++);
  final (:value, :elapsed) = await measure(action);
  await Future<void>.delayed(Duration.zero);
  timer.cancel();
  return (value: value, elapsed: elapsed, ticks: ticks);
}

/// Друкує заголовок розділу [title].
void _section(String title) => print('\n=== $title ===');
