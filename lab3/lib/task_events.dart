/// Події предметної області та їх джерело на основі `StreamController`.
library;

import 'dart:async';

import 'task.dart';
import 'task_status.dart';

/// Подія зміни в планувальнику.
sealed class TaskEvent {
  /// Конструктор для підтипів.
  const TaskEvent(this.taskId);

  /// Ідентифікатор завдання, якого стосується подія.
  final String taskId;
}

/// Завдання створено.
final class TaskCreated extends TaskEvent {
  /// Створює подію для завдання [task].
  TaskCreated(this.task) : super(task.id);

  /// Створене завдання.
  final Task task;

  @override
  String toString() => 'створено $taskId';
}

/// Змінився стан завдання.
final class StatusChanged extends TaskEvent {
  /// Створює подію зміни стану завдання [taskId] з [from] на [to].
  const StatusChanged(super.taskId, this.from, this.to);

  /// Попередній стан.
  final TaskStatus from;

  /// Новий стан.
  final TaskStatus to;

  @override
  String toString() => '$taskId: ${from.code} → ${to.code}';
}

/// Завдання видалено.
final class TaskDeleted extends TaskEvent {
  /// Створює подію видалення завдання [taskId].
  const TaskDeleted(super.taskId);

  @override
  String toString() => 'видалено $taskId';
}

/// Джерело подій планувальника.
///
/// Обгортає [StreamController]. Контролер одноразової підписки
/// буферизує події, додані до підписки, і віддає їх першому слухачеві;
/// широкомовний — передає подію лише тим, хто вже підписаний.
/// Контролер треба закрити [close], інакше слухачі ніколи не отримають
/// подію завершення, а ресурси не звільняться.
class TaskEventSource {
  /// Створює джерело; [broadcast] вмикає широкомовний режим.
  TaskEventSource({bool broadcast = false})
    : _controller = broadcast
          ? StreamController<TaskEvent>.broadcast()
          : StreamController<TaskEvent>();

  final StreamController<TaskEvent> _controller;

  /// Потік подій.
  Stream<TaskEvent> get stream => _controller.stream;

  /// Чи закрито джерело.
  bool get isClosed => _controller.isClosed;

  /// Публікує подію [event].
  void emit(TaskEvent event) => _controller.add(event);

  /// Публікує помилку [error] у потік.
  void fail(Object error) => _controller.addError(error);

  /// Закриває джерело; потік отримує подію завершення.
  Future<void> close() => _controller.close();
}
