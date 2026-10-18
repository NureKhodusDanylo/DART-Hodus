/// Сховища завдань: у пам'яті та у файлі JSON.
library;

import 'dart:convert';
import 'dart:io';

import '../model/task.dart';

/// Контракт сховища завдань, спільний для CLI, HTTP-сервісу й тестів.
///
/// Обробники HTTP і команди CLI залежать від цього інтерфейсу, а не від
/// конкретного класу, тому в тестах файлове сховище підміняється
/// [InMemoryTaskStore].
abstract interface class TaskStore {
  /// Усі завдання в порядку додавання.
  Future<List<Task>> loadAll();

  /// Завдання за ідентифікатором [id] або `null`.
  Future<Task?> findById(String id);

  /// Додає завдання [task] або замінює наявне з тим самим `id`.
  Future<void> put(Task task);

  /// Додає всі завдання [tasks] однією операцією.
  Future<void> putAll(Iterable<Task> tasks);
}

/// Сховище в пам'яті — для тестів і короткочасних запусків.
class InMemoryTaskStore implements TaskStore {
  /// Створює сховище з початковими завданнями [initial].
  InMemoryTaskStore([Iterable<Task> initial = const []]) {
    for (final task in initial) {
      _tasks[task.id] = task;
    }
  }

  final Map<String, Task> _tasks = {};

  @override
  Future<List<Task>> loadAll() async => List.unmodifiable(_tasks.values);

  @override
  Future<Task?> findById(String id) async => _tasks[id];

  @override
  Future<void> put(Task task) async => _tasks[task.id] = task;

  @override
  Future<void> putAll(Iterable<Task> tasks) async {
    for (final task in tasks) {
      _tasks[task.id] = task;
    }
  }
}

/// Сховище у файлі формату JSON.
///
/// Файл невеликий і потрібен цілком, тому читається `readAsString`;
/// записується з відступами, щоб його було зручно переглядати.
class JsonFileTaskStore implements TaskStore {
  /// Створює сховище, що працює з файлом [path].
  JsonFileTaskStore(this.path);

  /// Шлях до файлу даних.
  final String path;

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  File get _file => File(path);

  /// Чи існує файл даних.
  Future<bool> exists() => _file.exists();

  @override
  Future<List<Task>> loadAll() async {
    if (!await _file.exists()) return const [];
    final decoded = jsonDecode(await _file.readAsString()) as List<Object?>;
    return [
      for (final item in decoded) Task.fromJson(item as Map<String, Object?>),
    ];
  }

  @override
  Future<Task?> findById(String id) async =>
      (await loadAll()).where((t) => t.id == id).firstOrNull;

  @override
  Future<void> put(Task task) => putAll([task]);

  @override
  Future<void> putAll(Iterable<Task> tasks) async {
    final byId = {for (final t in await loadAll()) t.id: t};
    for (final task in tasks) {
      byId[task.id] = task;
    }
    await save(byId.values);
  }

  /// Повністю перезаписує файл завданнями [tasks].
  Future<void> save(Iterable<Task> tasks) async {
    await _file.parent.create(recursive: true);
    final json = _encoder.convert([for (final t in tasks) t.toJson()]);
    await _file.writeAsString('$json\n');
  }
}

/// Завантажує завдання зі сховища [store] з фільтрами за проєктом
/// [project], кодом стану [status] і мінімальним пріоритетом
/// [minPriority] (`null` — без фільтра).
Future<List<Task>> loadFiltered(
  TaskStore store, {
  String? project,
  String? status,
  int? minPriority,
}) async => [
  for (final t in await store.loadAll())
    if ((project == null || t.project == project) &&
        (status == null || t.status.code == status) &&
        (minPriority == null || t.priority.level >= minPriority))
      t,
];
