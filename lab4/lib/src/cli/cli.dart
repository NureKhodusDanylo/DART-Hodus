/// Консольний інтерфейс планувальника.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../model/constants.dart';
import '../model/data.dart';
import '../model/extensions.dart';
import '../model/task.dart';
import '../model/task_status.dart';
import '../model/text_utils.dart';
import '../remote/todo_api.dart';
import '../report/analytics.dart';
import '../report/report.dart';
import '../storage/csv_import.dart';
import '../storage/task_store.dart';

/// Код завершення: успіх.
const int exitOk = 0;

/// Код завершення: некоректне використання (аргументи командного рядка).
const int exitUsage = 64;

/// Код завершення: некоректні вхідні дані.
const int exitDataError = 65;

/// Код завершення: зовнішній сервіс недоступний.
const int exitUnavailable = 69;

/// Код завершення: помилка вводу-виводу.
const int exitIoError = 74;

/// Шлях до файлу даних за замовчуванням.
final String defaultDataFile = p.join('data', 'tasks.json');

/// Будує розбирач аргументів командного рядка.
///
/// Глобальні опції: `--file`, `--help`. Команди: `init`, `list`, `add`,
/// `stats`, `import-api`, `import-csv`, `generate-csv`.
ArgParser buildArgParser() {
  final parser = ArgParser()
    ..addOption(
      'file',
      abbr: 'f',
      help: 'Файл даних у форматі JSON.',
      valueHelp: 'шлях',
      defaultsTo: defaultDataFile,
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Показати довідку.');

  parser
    ..addCommand('init')
    ..addCommand(
      'list',
      ArgParser()
        ..addOption('project', abbr: 'p', help: 'Лише завдання проєкту.')
        ..addOption(
          'status',
          abbr: 's',
          help: 'Лише завдання в цьому стані.',
          allowed: ['todo', 'in_progress', 'done', 'blocked'],
        )
        ..addOption(
          'limit',
          abbr: 'n',
          help: 'Найбільша кількість рядків.',
          defaultsTo: '20',
        ),
    )
    ..addCommand(
      'add',
      ArgParser()..addOption(
        'csv',
        help: 'Завдання одним рядком у форматі вхідних даних.',
        mandatory: true,
      ),
    )
    ..addCommand('stats')
    ..addCommand(
      'import-api',
      ArgParser()
        ..addOption(
          'user',
          abbr: 'u',
          help: 'Ідентифікатор користувача в API.',
          defaultsTo: '1',
        )
        ..addOption(
          'api',
          help: 'Базова адреса API.',
          defaultsTo: defaultTodoApi.toString(),
        ),
    )
    ..addCommand(
      'import-csv',
      ArgParser()..addOption(
        'input',
        abbr: 'i',
        help: 'Великий CSV-файл для потокового імпорту.',
        mandatory: true,
      ),
    )
    ..addCommand(
      'generate-csv',
      ArgParser()
        ..addOption(
          'output',
          abbr: 'o',
          help: 'Куди записати.',
          mandatory: true,
        )
        ..addOption(
          'count',
          abbr: 'c',
          help: 'Кількість рядків.',
          defaultsTo: '100000',
        ),
    );
  return parser;
}

/// Текст довідки.
String usage(ArgParser parser) {
  final commands = parser.commands.entries
      .map((e) {
        final options = e.value.usage;
        return '  ${e.key}${options.isEmpty ? '' : '\n${_indent(options)}'}';
      })
      .join('\n');
  return 'Використання: task_planner [опції] <команда> [опції команди]\n\n'
      'Опції:\n${_indent(parser.usage)}\n\nКоманди:\n$commands';
}

String _indent(String text) => text.split('\n').map((l) => '    $l').join('\n');

/// Виконує команду з аргументів [arguments] і повертає код завершення.
///
/// Звичайний вивід іде в [out], помилки — в [err]. Мережевий клієнт
/// [httpClient] і момент [now] можна передати ззовні — для тестів.
/// Якщо клієнт не передано, команда створює його сама й закриває у
/// `finally`.
Future<int> runCli(
  List<String> arguments, {
  StringSink? out,
  StringSink? err,
  http.Client? httpClient,
  DateTime? now,
}) async {
  final stdOut = out ?? stdout;
  final stdErr = err ?? stderr;
  final parser = buildArgParser();

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on ArgParserException catch (e) {
    stdErr
      ..writeln('Помилка: ${e.message}')
      ..writeln(usage(parser));
    return exitUsage;
  }

  final command = args.command;
  if (args.flag('help')) {
    stdOut.writeln(usage(parser));
    return exitOk;
  }
  if (command == null) {
    stdErr
      ..writeln(
        args.rest.isEmpty
            ? 'Не вказано команду'
            : 'Невідома команда: ${args.rest.first}',
      )
      ..writeln(usage(parser));
    return exitUsage;
  }

  final store = JsonFileTaskStore(args.option('file') ?? defaultDataFile);
  final moment = (now ?? DateTime.now()).dateOnly;
  try {
    return switch (command.name) {
      'init' => await _init(store, stdOut),
      'list' => await _list(store, command, stdOut, stdErr),
      'add' => await _add(store, command, stdOut, stdErr),
      'stats' => await _stats(store, moment, stdOut),
      'import-api' => await _importApi(
        store,
        command,
        httpClient,
        moment,
        stdOut,
        stdErr,
      ),
      'import-csv' => await _importCsv(store, command, stdOut),
      'generate-csv' => await _generateCsv(command, stdOut, stdErr),
      final name => _unknown(name, stdErr),
    };
  } on FileSystemException catch (e) {
    stdErr.writeln('Помилка файлової системи: ${e.message} (${e.path})');
    return exitIoError;
  } on FormatException catch (e) {
    stdErr.writeln('Некоректні дані: ${e.message}');
    return exitDataError;
  }
}

int _unknown(String? name, StringSink err) {
  err.writeln('Невідома команда: $name');
  return exitUsage;
}

Future<int> _init(JsonFileTaskStore store, StringSink out) async {
  final tasks = [
    for (final line in rawTasks)
      if (Task.tryParse(line).task case final Task t when t.isValid) t,
  ];
  await store.save(tasks);
  out.writeln('Створено ${store.path}: ${tasks.length} завдань');
  return exitOk;
}

Future<int> _list(
  TaskStore store,
  ArgResults command,
  StringSink out,
  StringSink err,
) async {
  final limit = int.tryParse(command.option('limit') ?? '');
  if (limit == null || limit < 1) {
    err.writeln('Опція --limit має бути додатним цілим числом');
    return exitUsage;
  }
  final project = command.option('project');
  final status = command.option('status');
  final tasks = (await loadFiltered(
    store,
    project: project,
    status: status,
  )).take(limit);
  for (final t in tasks) {
    out.writeln(
      '${statusMark(t.status)} ${t.id.padRight(8)} '
      '${fitColumn(t.title, titleColumnWidth)} P${t.priority.level} '
      '${t.deadline.iso}',
    );
  }
  if (tasks.isEmpty) out.writeln('Завдань не знайдено');
  return exitOk;
}

Future<int> _add(
  TaskStore store,
  ArgResults command,
  StringSink out,
  StringSink err,
) async {
  final (:task, :error) = Task.tryParse(command.option('csv') ?? '');
  if (task == null) {
    err.writeln('Некоректний рядок: $error');
    return exitDataError;
  }
  if (!task.isValid) {
    err.writeln('Завдання порушує правила: ${task.violations.join('; ')}');
    return exitDataError;
  }
  await store.put(task);
  out.writeln('Додано $task');
  return exitOk;
}

Future<int> _stats(TaskStore store, DateTime now, StringSink out) async {
  final tasks = await store.loadAll();
  out.write(buildReport(tasks, now: now));
  for (final MapEntry(:key, :value) in tasks.groupByProject().entries) {
    out.writeln(
      '  $key: ${value.length} завд., ${formatHours(value.totalHours)}',
    );
  }
  return exitOk;
}

Future<int> _importApi(
  TaskStore store,
  ArgResults command,
  http.Client? injected,
  DateTime now,
  StringSink out,
  StringSink err,
) async {
  final userId = int.tryParse(command.option('user') ?? '');
  if (userId == null) {
    err.writeln('Опція --user має бути цілим числом');
    return exitUsage;
  }
  final client = injected ?? http.Client();
  try {
    final baseUri = Uri.tryParse(command.option('api') ?? '');
    final tasks = await TodoApiClient(
      client,
      baseUri: baseUri,
    ).fetchTasks(userId: userId, now: now);
    await store.putAll(tasks);
    final done = tasks.where((t) => t.status is Done).length;
    out.writeln(
      'Імпортовано ${tasks.length} завдань з API (виконано $done) '
      'у проєкт $externalProject',
    );
    return exitOk;
  } on ApiFailure catch (e) {
    err.writeln('Не вдалося отримати дані з API: $e');
    return switch (e) {
      NetworkFailure() || HttpStatusFailure() => exitUnavailable,
      BadPayloadFailure() => exitDataError,
    };
  } finally {
    if (injected == null) client.close();
  }
}

Future<int> _importCsv(
  TaskStore store,
  ArgResults command,
  StringSink out,
) async {
  final path = command.option('input') ?? '';
  final stopwatch = Stopwatch()..start();
  final (:lines, :tasks, :errors) = await importCsv(path);
  stopwatch.stop();
  out.writeln(
    'Прочитано $lines рядків за ${stopwatch.elapsedMilliseconds} мс: '
    'коректних ${lines - errors}, з помилками $errors',
  );
  await store.putAll(tasks);
  out.writeln('До сховища додано перші ${tasks.length} коректних завдань');
  return exitOk;
}

Future<int> _generateCsv(
  ArgResults command,
  StringSink out,
  StringSink err,
) async {
  final count = int.tryParse(command.option('count') ?? '');
  if (count == null || count < 1) {
    err.writeln('Опція --count має бути додатним цілим числом');
    return exitUsage;
  }
  final path = command.option('output') ?? '';
  await writeSampleCsv(path, count);
  out.writeln(
    'Записано $count рядків у $path (${await File(path).length()} байт)',
  );
  return exitOk;
}
