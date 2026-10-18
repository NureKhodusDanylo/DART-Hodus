/// Потокове читання та запис великих CSV-файлів.
library;

import 'dart:convert';
import 'dart:io';

import '../model/priority.dart';
import '../model/task.dart';

/// Підсумок імпорту: прочитані рядки, коректні завдання й кількість помилок.
typedef CsvImport = ({int lines, List<Task> tasks, int errors});

/// Кількість різних проєктів у згенерованому файлі.
const List<String> _sampleProjects = ['WEB', 'MOB', 'API', 'DOC'];

/// Кількість різних станів у згенерованому файлі.
const List<String> _sampleStatuses = ['todo', 'in_progress', 'done', 'blocked'];

/// Найбільша трудомісткість у згенерованому файлі, годин.
const int _sampleMaxHours = 40;

/// Найбільший номер завдання в межах одного проєкту.
const int _sampleIdRange = 10000;

/// Кожен який рядок згенерованого файлу навмисно пошкоджується.
const int _sampleBrokenEvery = 20;

/// Скільки коректних завдань імпорт тримає в пам'яті за замовчуванням.
const int defaultImportKeep = 1000;

/// Розбирає CSV-файл [path] рядок за рядком.
///
/// Файл читається через `openRead()` з конвеєром декодерів
/// `utf8.decoder → LineSplitter`, тому в пам'яті одночасно лише невеликий
/// фрагмент файлу, незалежно від його розміру. Порожні рядки пропускаються.
Stream<ParseResult> readCsv(String path) =>
    File(path)
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map(Task.tryParse);

/// Імпортує коректні завдання з CSV-файлу [path].
///
/// До результату потрапляють лише завдання без порушень правил; щоб не
/// тримати весь файл у пам'яті, зберігаються не більше [keep] завдань,
/// решта лише підраховуються.
Future<CsvImport> importCsv(String path, {int keep = defaultImportKeep}) async {
  var lines = 0;
  var errors = 0;
  final tasks = <Task>[];
  await for (final (:task, error: _) in readCsv(path)) {
    lines++;
    if (task == null || !task.isValid) {
      errors++;
    } else if (tasks.length < keep) {
      tasks.add(task);
    }
  }
  return (lines: lines, tasks: tasks, errors: errors);
}

/// Записує у файл [path] згенерований CSV з [count] рядків.
///
/// Запис іде потоком через `openWrite()`, тому великий файл не
/// формується в пам'яті. Кожен двадцятий рядок навмисно пошкоджено.
Future<void> writeSampleCsv(String path, int count) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final sink = file.openWrite();
  try {
    for (var i = 0; i < count; i++) {
      final project = _sampleProjects[i % _sampleProjects.length];
      final status = _sampleStatuses[i % _sampleStatuses.length];
      final number = i % _sampleIdRange;
      final hours = 1 + i % _sampleMaxHours;
      final priority = Priority.values[i % Priority.values.length].level;
      final broken = i % _sampleBrokenEvery == _sampleBrokenEvery - 1;
      sink.writeln(
        '$project-$number;Завдання $i;$project;'
        '${broken ? 'x' : priority};2026-09-01;2026-12-01;$status;$hours',
      );
    }
  } finally {
    await sink.close();
  }
}
