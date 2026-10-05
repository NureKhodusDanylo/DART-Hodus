/// Типи даних предметної області «Планувальник завдань».
///
/// У лабораторній роботі 1 класи свідомо не використовуються: завдання
/// подається іменованим записом (record), а для зручності читання коду
/// оголошено псевдоніми типів.
library;

/// Завдання планувальника.
///
/// Поля: ідентифікатор `id` (наприклад, `WEB-101`), назва, код проєкту,
/// пріоритет (1–5), дата створення, термін виконання, статус і оцінка
/// трудомісткості в годинах.
typedef Task = ({
  String id,
  String title,
  String project,
  int priority,
  DateTime createdAt,
  DateTime deadline,
  String status,
  double estimateHours,
});

/// Результат розбору одного рядка: або завдання, або опис помилки.
///
/// Рівно одне з полів має значення, інше дорівнює `null`.
typedef ParseResult = ({Task? task, String? error});

/// Порівнювач двох завдань для сортування.
typedef TaskComparator = int Function(Task a, Task b);

/// Предикат для фільтрації завдань.
typedef TaskPredicate = bool Function(Task task);

/// Агреговані показники трудомісткості для набору завдань.
typedef EstimateStats = ({
  int count,
  double total,
  double average,
  double min,
  double max,
});
