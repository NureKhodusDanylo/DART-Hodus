/// Допоміжні засоби для вимірювання часу асинхронних операцій.
library;

/// Результат вимірювання: значення та витрачений час.
typedef Timed<T> = ({T value, Duration elapsed});

/// Виконує [action] і вимірює його тривалість через [Stopwatch].
Future<Timed<T>> measure<T>(Future<T> Function() action) async {
  final stopwatch = Stopwatch()..start();
  final value = await action();
  stopwatch.stop();
  return (value: value, elapsed: stopwatch.elapsed);
}

/// Імітує повільну операцію з назвою [name] тривалістю [delay];
/// якщо [fail] — завершується помилкою [StateError].
Future<String> slowOperation(
  String name, {
  Duration delay = const Duration(milliseconds: 500),
  bool fail = false,
}) async {
  await Future<void>.delayed(delay);
  if (fail) throw StateError('операція «$name» завершилась помилкою');
  return name;
}
