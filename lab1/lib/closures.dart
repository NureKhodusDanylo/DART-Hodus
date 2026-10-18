/// Замикання: лічильник і фабрики предикатів.
library;

import 'model.dart';

/// Створює лічильник оброблених записів.
///
/// Повертає запис із двох функцій, які захоплюють одну й ту саму локальну
/// змінну `count`. Змінна живе, доки існує хоча б одна з цих функцій,
/// хоча сам виклик `makeCounter` уже завершився.
({void Function() increment, int Function() value}) makeCounter() {
  var count = 0;
  return (increment: () => count++, value: () => count);
}

/// Фабрика предикатів: створює фільтр завдань із пріоритетом
/// не нижче [threshold].
///
/// Повернена функція захоплює параметр [threshold].
TaskPredicate makePriorityFilter(int threshold) =>
    (task) => task.priority >= threshold;

/// Фабрика предикатів: створює фільтр завдань проєкту [project].
TaskPredicate makeProjectFilter(String project) =>
    (task) => task.project == project;

/// Поєднує кілька предикатів [predicates] логічним «І».
TaskPredicate allOf(List<TaskPredicate> predicates) =>
    (task) => predicates.every((p) => p(task));
