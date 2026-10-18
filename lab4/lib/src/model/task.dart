/// Клас-сутність «завдання».
library;

import 'constants.dart';
import 'extensions.dart';
import 'identifiable.dart';
import 'priority.dart';
import 'scheduled.dart';
import 'task_status.dart';
import 'text_utils.dart';

/// Результат розбору рядка: або завдання, або опис помилки.
typedef ParseResult = ({Task? task, String? error});

/// Завдання планувальника — незмінна сутність.
///
/// Усі поля `final`, конструктор генеративний і константний. Рівність
/// визначається за значенням усіх полів, тому [==] і [hashCode]
/// перевизначено разом.
final class const Task({
  required String id,

  /// Назва завдання.
  required final String title,

  /// Код проєкту, до якого належить завдання.
  required final String project,

  /// Пріоритет.
  required final Priority priority,

  /// Дата створення (UTC).
  required final DateTime createdAt,

  @override required final DateTime deadline,

  /// Поточний стан.
  required final TaskStatus status,

  /// Оцінка трудомісткості в годинах.
  required final double estimateHours,
}) extends Entity with Scheduled {
  /// Створює завдання з уже перевіреними значеннями полів.
  this : super(id);

  /// Розбирає рядок [line] у завдання; кидає [FormatException],
  /// якщо рядок пошкоджений.
  ///
  /// Іменований конструктор замінює функцію розбору з ЛР1 для випадків,
  /// коли некоректний рядок — помилка програміста. Для даних, які можуть
  /// бути пошкоджені, призначено [tryParse].
  Task.fromCsv(String line) : this._copyOf(_parseOrThrow(line));

  /// Повертає завдання для рядка [line] з кешу, створюючи його лише
  /// під час першого звернення.
  ///
  /// Фабричний конструктор може повернути вже наявний екземпляр,
  /// чого не вміє жоден генеративний конструктор.
  factory Task.cached(String line) =>
      _cache.putIfAbsent(line, () => Task.fromCsv(line));

  /// Відновлює завдання з JSON-об'єкта [json], збереженого [toJson].
  ///
  /// Призначено для власного файлу даних, структуру якого гарантує
  /// програма. `jsonDecode` повертає `dynamic`, тому кожне поле явно
  /// приводиться до потрібного типу: помилка структури проявиться одразу
  /// тут, а не пізніше в довільному місці коду. Неприпустимі значення
  /// пріоритету, стану чи дати дають [FormatException].
  factory Task.fromJson(Map<String, Object?> json) {
    final level = json['priority'] as int;
    final statusCode = json['status'] as String;
    final created = json['createdAt'] as String;
    final deadline = json['deadline'] as String;
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      project: json['project'] as String,
      priority:
          Priority.fromLevel(level) ??
          (throw FormatException('пріоритету рівня $level не існує')),
      createdAt:
          created.toStrictDate() ??
          (throw FormatException('некоректна дата створення', created)),
      deadline:
          deadline.toStrictDate() ??
          (throw FormatException('некоректний термін', deadline)),
      status:
          TaskStatus.tryParse(statusCode) ??
          (throw FormatException('невідомий стан', statusCode)),
      estimateHours: (json['estimateHours'] as num).toDouble(),
    );
  }

  /// Копіює поля завдання [other] — ціль переадресації для [Task.fromCsv].
  Task._copyOf(Task other)
    : this(
        id: other.id,
        title: other.title,
        project: other.project,
        priority: other.priority,
        createdAt: other.createdAt,
        deadline: other.deadline,
        status: other.status,
        estimateHours: other.estimateHours,
      );

  /// Кеш завдань, створених фабричним конструктором [Task.cached].
  static final Map<String, Task> _cache = {};

  /// Розбирає рядок [line] без винятків.
  ///
  /// Пошкоджений рядок — очікувана ситуація, тому функція повертає
  /// запис «завдання або причина відмови».
  static ParseResult tryParse(String line) {
    ParseResult fail(String error) => (task: null, error: error);

    final fields = line.split(fieldSeparator).map((f) => f.trim()).toList();
    if (fields.length != fieldCount) {
      return fail('очікувалось $fieldCount полів, отримано ${fields.length}');
    }
    final [
      id,
      title,
      project,
      rawPriority,
      rawCreated,
      rawDeadline,
      rawStatus,
      rawHours,
    ] = fields;

    final level = int.tryParse(rawPriority);
    if (level == null) return fail('пріоритет "$rawPriority" не є числом');
    final priority = Priority.fromLevel(level);
    if (priority == null) {
      return fail('пріоритету рівня $level не існує');
    }
    final createdAt = rawCreated.toStrictDate();
    if (createdAt == null) {
      return fail('некоректна дата створення "$rawCreated"');
    }
    final deadline = rawDeadline.toStrictDate();
    if (deadline == null) return fail('некоректний термін "$rawDeadline"');
    final status = TaskStatus.tryParse(rawStatus);
    if (status == null) return fail('невідомий стан "$rawStatus"');
    final hours = double.tryParse(rawHours);
    if (hours == null) return fail('трудомісткість "$rawHours" не є числом');

    return (
      task: Task(
        id: id,
        title: title,
        project: project,
        priority: priority,
        createdAt: createdAt,
        deadline: deadline,
        status: status,
        estimateHours: hours,
      ),
      error: null,
    );
  }

  /// Розбирає [line] або кидає [FormatException] з причиною відмови.
  static Task _parseOrThrow(String line) {
    final (:task, :error) = tryParse(line);
    return task ?? (throw FormatException(error ?? 'некоректний рядок', line));
  }

  @override
  String get displayName => title;

  @override
  bool get isClosed => status.isFinished;

  /// Чи має завдання високий пріоритет.
  bool get isHighPriority => priority.isHigh;

  /// Тривалість, відведена на виконання (від створення до терміну).
  Duration get plannedDuration => deadline.difference(createdAt);

  /// Вік завдання в днях на момент [now].
  int ageInDays(DateTime now) => createdAt.daysUntil(now);

  /// Порушення правил узгодженості полів; порожній список — порушень немає.
  List<String> get violations {
    final projectInId = projectFromId(id);
    return [
      if (projectInId == null) 'ідентифікатор "$id" не відповідає формату',
      if (projectInId != null && projectInId != project)
        'код проєкту в ідентифікаторі ($projectInId) не збігається з $project',
      if (estimateHours < minEstimateHours || estimateHours > maxEstimateHours)
        'трудомісткість $estimateHours год поза межами '
            '$minEstimateHours..$maxEstimateHours',
      if (deadline.isBefore(createdAt))
        'термін виконання раніше за дату створення',
    ];
  }

  /// Чи немає порушень правил узгодженості.
  bool get isValid => violations.isEmpty;

  /// Перевіряє довільне значення [json] з ненадійного джерела (тіла
  /// HTTP-запиту) і будує з нього завдання; `null` — якщо структура чи
  /// значення некоректні.
  ///
  /// На відміну від [Task.fromJson], не кидає винятків: зіставлення зі
  /// зразком мапи перевіряє наявність і тип кожного поля.
  static Task? tryFromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'title': final String title,
      'project': final String project,
      'priority': final int level,
      'createdAt': final String created,
      'deadline': final String deadline,
      'status': final String status,
      'estimateHours': final num hours,
    } =>
      switch ((
        Priority.fromLevel(level),
        created.toStrictDate(),
        deadline.toStrictDate(),
        TaskStatus.tryParse(status),
      )) {
        (
          final Priority priority,
          final DateTime createdAt,
          final DateTime due,
          final TaskStatus taskStatus,
        ) =>
          Task(
            id: id,
            title: title,
            project: project,
            priority: priority,
            createdAt: createdAt,
            deadline: due,
            status: taskStatus,
            estimateHours: hours.toDouble(),
          ),
        _ => null,
      },
    _ => null,
  };

  /// Перетворює завдання на JSON-сумісну мапу.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'project': project,
    'priority': priority.level,
    'createdAt': createdAt.iso,
    'deadline': deadline.iso,
    'status': status.code,
    'estimateHours': estimateHours,
  };

  /// Копія завдання зі зміненим станом [status].
  Task withStatus(TaskStatus status) => Task(
    id: id,
    title: title,
    project: project,
    priority: priority,
    createdAt: createdAt,
    deadline: deadline,
    status: status,
    estimateHours: estimateHours,
  );

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.title == title &&
      other.project == project &&
      other.priority == priority &&
      other.createdAt == createdAt &&
      other.deadline == deadline &&
      other.status == status &&
      other.estimateHours == estimateHours;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    project,
    priority,
    createdAt,
    deadline,
    status,
    estimateHours,
  );

  @override
  String toString() =>
      'Task($id, "$title", P${priority.level}, ${status.code}, '
      '${deadline.iso})';
}
