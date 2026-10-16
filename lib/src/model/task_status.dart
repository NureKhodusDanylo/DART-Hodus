/// Стан завдання як запечатана ієрархія.
library;

/// Стан завдання.
///
/// Клас запечатаний (`sealed`): усі підтипи оголошено в цьому файлі,
/// тому компілятор перевіряє вичерпність `switch` без гілки `default`.
/// Додавання нового підтипу спричиняє помилку компіляції в кожному
/// `switch`, де його не враховано.
sealed class TaskStatus {
  /// Конструктор для підтипів.
  const TaskStatus();

  /// Код стану у вхідних даних.
  String get code;

  /// Назва стану українською.
  String get label;

  /// Частка виконаної роботи від 0 до 1 — поліморфний метод.
  double get progress;

  /// Чи завершено роботу над завданням.
  bool get isFinished => false;

  /// Розбирає код стану [code]; повертає `null` для невідомого коду.
  static TaskStatus? tryParse(String code) => switch (code) {
    'todo' => const Todo(),
    'in_progress' => const InProgress(),
    'done' => const Done(),
    'blocked' => const Blocked(),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is TaskStatus && other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => code;
}

/// Завдання ще не розпочато.
final class Todo extends TaskStatus {
  /// Створює стан «до виконання».
  const Todo();

  @override
  String get code => 'todo';

  @override
  String get label => 'до виконання';

  @override
  double get progress => 0;
}

/// Завдання виконується.
final class InProgress extends TaskStatus {
  /// Створює стан «виконується».
  const InProgress();

  @override
  String get code => 'in_progress';

  @override
  String get label => 'виконується';

  @override
  double get progress => 0.5;
}

/// Завдання виконано.
final class Done extends TaskStatus {
  /// Створює стан «виконано».
  const Done();

  @override
  String get code => 'done';

  @override
  String get label => 'виконано';

  @override
  double get progress => 1;

  @override
  bool get isFinished => true;
}

/// Роботу над завданням заблоковано (четвертий підтип, доданий пізніше).
final class Blocked extends TaskStatus {
  /// Створює стан «заблоковано».
  const Blocked();

  @override
  String get code => 'blocked';

  @override
  String get label => 'заблоковано';

  @override
  double get progress => 0;
}
