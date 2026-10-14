/// Важке синхронне обчислення для винесення в ізолят.
library;

/// Підсумок моделювання навантаження.
typedef WorkloadSummary = ({
  int tasks,
  double totalHours,
  int overdue,
  double p90Hours,
});

/// Скільки разів [simulateWorkload] запускалося в поточному ізоляті.
///
/// Глобальна змінна, яку змінює [simulateWorkload]. В ізоляті, запущеному
/// через `Isolate.run`, зміна відбувається в його власній копії пам'яті,
/// тому головний ізолят її не бачить.
int simulationRuns = 0;

/// Множник лінійного конгруентного генератора (параметри Numerical Recipes).
const int _lcgMultiplier = 1664525;

/// Приріст лінійного конгруентного генератора.
const int _lcgIncrement = 1013904223;

/// Модуль лінійного конгруентного генератора (2^32).
const int _lcgModulus = 0x100000000;

/// Найбільша трудомісткість синтетичного завдання в годинах.
const int _maxSyntheticHours = 120;

/// Горизонт термінів синтетичних завдань у днях.
const int _deadlineHorizonDays = 90;

/// Частка завдань, що вважаються простроченими (поріг для 90-го перцентиля).
const double _percentile = 0.9;

/// Моделює навантаження з [count] синтетичних завдань.
///
/// Генерує трудомісткість і термін кожного завдання детермінованим
/// генератором псевдовипадкових чисел із зерном [seed], рахує суму годин,
/// кількість прострочених і 90-й перцентиль трудомісткості (для чого
/// сортує весь масив). Обчислення суто синхронне й навмисно важке.
WorkloadSummary simulateWorkload(int count, {int seed = 42}) {
  simulationRuns++;
  var state = seed;
  int next() => state = (state * _lcgMultiplier + _lcgIncrement) % _lcgModulus;

  final hours = List<double>.filled(count, 0);
  var total = 0.0;
  var overdue = 0;
  for (var i = 0; i < count; i++) {
    final h = 1 + next() % _maxSyntheticHours + (next() % 10) / 10;
    hours[i] = h;
    total += h;
    final deadlineInDays = next() % _deadlineHorizonDays - 30;
    if (deadlineInDays < 0) overdue++;
  }
  hours.sort();
  final p90 = hours.isEmpty ? 0.0 : hours[((count - 1) * _percentile).floor()];
  return (tasks: count, totalHours: total, overdue: overdue, p90Hours: p90);
}
