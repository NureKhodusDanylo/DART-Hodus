/// Аналітика над завданнями: записи, `switch`-вирази й зіставлення
/// зі зразком.
library;

import 'constants.dart';
import 'priority.dart';
import 'task.dart';
import 'task_status.dart';

/// Підсумок виконання: кількість завершених і відкритих завдань та
/// залишок роботи в годинах — кілька значень повертаються записом.
typedef Progress = ({int done, int open, double remainingHours});

/// Обчислює підсумок виконання набору [tasks] одним проходом.
Progress progressOf(Iterable<Task> tasks) => tasks.fold(
  (done: 0, open: 0, remainingHours: 0),
  (acc, t) => t.status.isFinished
      ? (done: acc.done + 1, open: acc.open, remainingHours: acc.remainingHours)
      : (
          done: acc.done,
          open: acc.open + 1,
          remainingHours:
              acc.remainingHours + t.estimateHours * _effortLeft(t.status),
        ),
);

/// Частка трудомісткості, що лишилася, залежно від стану.
///
/// `switch`-вираз без гілки `default`: компілятор перевіряє, що
/// враховано всі підтипи запечатаного [TaskStatus].
double _effortLeft(TaskStatus status) => switch (status) {
  Todo() => 1,
  InProgress() => 0.5,
  Done() => 0,
  Blocked() => 1,
};

/// Позначка стану для виводу — ще один вичерпний `switch` по підтипах.
String statusMark(TaskStatus status) => switch (status) {
  Todo() => '○',
  InProgress() => '◐',
  Done() => '●',
  Blocked() => '⊘',
};

/// Оцінка терміновості завдання [task] на момент [now].
///
/// Зіставлення зі зразком об'єктів `Task(...)` поєднано з охоронцями
/// `when`: гілки перевіряються згори донизу, перша, що збіглася, дає
/// результат.
String urgencyOf(Task task, DateTime now) => switch (task) {
  Task(status: Done()) => 'закрито',
  Task(status: Blocked()) => 'потребує розблокування',
  Task(priority: Priority(isHigh: true)) when task.isOverdue(now) =>
    'КРИТИЧНО: прострочено',
  _ when task.isOverdue(now) => 'прострочено',
  Task(priority: Priority.critical) => 'критичний пріоритет',
  _ when task.daysLeft(now) <= dueSoonWindow.inDays => 'термін близько',
  _ => 'за планом',
};
