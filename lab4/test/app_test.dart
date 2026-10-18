import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:task_planner/task_planner.dart';
import 'package:test/test.dart';

/// Коректні завдання з вбудованого набору.
final List<Task> _seed = [
  for (final line in rawTasks)
    if (Task.tryParse(line).task case final Task t when t.isValid) t,
];

/// Тіло, яке повертає `GET /todos` у JSONPlaceholder.
const String _todosJson = '''
[
  {"userId": 1, "id": 1, "title": "delectus aut autem", "completed": false},
  {"userId": 1, "id": 2, "title": "quis ut nam facilis", "completed": true}
]''';

void main() {
  group('серіалізація JSON', () {
    test('toJson → fromJson повертає рівне завдання', () {
      for (final task in _seed) {
        final json = jsonDecode(jsonEncode(task.toJson()));
        expect(Task.fromJson(json as Map<String, Object?>), task);
      }
    });

    test('fromJson кидає FormatException на неіснуючий пріоритет', () {
      final json = _seed.first.toJson()..['priority'] = 9;
      expect(() => Task.fromJson(json), throwsFormatException);
    });

    test('tryFromJson повертає null для неповного об’єкта', () {
      expect(Task.tryFromJson({'id': 'X-1'}), isNull);
      expect(Task.tryFromJson('рядок'), isNull);
      expect(Task.tryFromJson(_seed.first.toJson()), _seed.first);
    });
  });

  group('файлові операції', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('tp_'));
    tearDown(() => dir.delete(recursive: true));

    test('JsonFileTaskStore зберігає і завантажує завдання', () async {
      final store = JsonFileTaskStore(p.join(dir.path, 'nested', 'tasks.json'));
      expect(await store.loadAll(), isEmpty);
      await store.save(_seed);
      await store.put(_seed.first.withStatus(const Blocked()));
      final loaded = await store.loadAll();
      expect(loaded, hasLength(_seed.length));
      expect((await store.findById(_seed.first.id))?.status, const Blocked());
    });

    test('importCsv читає файл потоком і рахує помилки', () async {
      final path = p.join(dir.path, 'big.csv');
      await writeSampleCsv(path, 400);
      final (:lines, :tasks, :errors) = await importCsv(path, keep: 10);
      expect(lines, 400);
      expect(errors, 20);
      expect(tasks, hasLength(10));
    });
  });

  group('командний рядок', () {
    late Directory dir;
    late String file;
    late StringBuffer out;
    late StringBuffer err;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tp_cli_');
      file = p.join(dir.path, 'tasks.json');
      out = StringBuffer();
      err = StringBuffer();
    });
    tearDown(() => dir.delete(recursive: true));

    Future<int> run(List<String> args, {http.Client? client}) => runCli(
      ['--file', file, ...args],
      out: out,
      err: err,
      httpClient: client,
      now: DateTime.utc(2026, 10, 15),
    );

    test('розбір аргументів: опції команди list', () {
      final args = buildArgParser().parse([
        '-f',
        'x.json',
        'list',
        '-p',
        'WEB',
        '--status',
        'todo',
        '-n',
        '3',
      ]);
      expect(args.option('file'), 'x.json');
      expect(args.command?.name, 'list');
      expect(args.command?.option('project'), 'WEB');
      expect(args.command?.option('limit'), '3');
    });

    test('невідома команда — код 64 і повідомлення в stderr', () async {
      expect(await run(['fly']), exitUsage);
      expect(err.toString(), contains('Невідома команда: fly'));
      expect(out.toString(), isEmpty);
    });

    test('init і list з фільтром за проєктом', () async {
      expect(await run(['init']), exitOk);
      expect(await run(['list', '--project', 'DOC']), exitOk);
      expect(
        out.toString(),
        allOf(contains('DOC-401'), isNot(contains('WEB-'))),
      );
    });

    test('add відхиляє пошкоджений рядок кодом 65', () async {
      expect(
        await run(['add', '--csv', 'A-1;x;A;x;2026-01-01;2026-02-01;todo;1']),
        exitDataError,
      );
      expect(err.toString(), contains('не є числом'));
    });

    test('import-api зберігає завдання з підміненої мережі', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/todos');
        expect(request.url.queryParameters['userId'], '1');
        return http.Response(_todosJson, 200);
      });
      expect(await run(['import-api'], client: client), exitOk);
      final stored = await JsonFileTaskStore(file).loadAll();
      expect(stored.map((t) => t.id), ['EXT-1', 'EXT-2']);
      expect(stored.last.status, const Done());
    });
  });

  group('TodoApiClient: три рівні відмов', () {
    Future<List<Task>> fetchWith(MockClient client) =>
        TodoApiClient(client).fetchTasks();

    test('відсутність з’єднання → NetworkFailure', () {
      final client = MockClient(
        (_) => throw http.ClientException('немає мережі'),
      );
      expect(fetchWith(client), throwsA(isA<NetworkFailure>()));
    });

    test('код 503 → HttpStatusFailure', () {
      final client = MockClient((_) async => http.Response('', 503));
      expect(
        fetchWith(client),
        throwsA(
          isA<HttpStatusFailure>().having((f) => f.statusCode, 'код', 503),
        ),
      );
    });

    test('некоректне тіло → BadPayloadFailure', () {
      final client = MockClient((_) async => http.Response('<html>', 200));
      expect(fetchWith(client), throwsA(isA<BadPayloadFailure>()));
    });
  });

  group('HTTP-сервіс', () {
    late Handler handler;
    late List<String> log;

    setUp(() {
      log = [];
      handler = buildHandler(InMemoryTaskStore(_seed), log: log.add);
    });

    Future<Response> send(String method, String path, [String? body]) async =>
        await handler(
          Request(method, Uri.parse('http://localhost$path'), body: body),
        );

    test('GET /tasks фільтрує за параметрами запиту', () async {
      final response = await send('GET', '/tasks?project=WEB&minPriority=4');
      expect(response.statusCode, 200);
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );
      final ids = (jsonDecode(await response.readAsString()) as List<Object?>)
          .map((e) => (e as Map<String, Object?>)['id']);
      expect(ids, ['WEB-102', 'WEB-103']);
      expect(
        log.single,
        contains('GET  /tasks?project=WEB&minPriority=4 → 200'),
      );
    });

    test('GET /tasks/<id> повертає 404 для відсутнього завдання', () async {
      expect((await send('GET', '/tasks/API-305')).statusCode, 200);
      expect((await send('GET', '/tasks/NOPE-1')).statusCode, 404);
    });

    test(
      'POST /tasks: 201 для коректного, 400 для некоректного тіла',
      () async {
        final fresh = Task.fromCsv(
          'DOC-404;Довідка CLI;DOC;2;2026-10-18;2026-10-30;todo;3',
        );
        expect(
          (await send('POST', '/tasks', jsonEncode(fresh.toJson()))).statusCode,
          201,
        );
        expect((await send('GET', '/tasks/DOC-404')).statusCode, 200);
        expect((await send('POST', '/tasks', 'не json')).statusCode, 400);
        expect((await send('POST', '/tasks', '{"id": "X"}')).statusCode, 400);
        expect(
          (await send('POST', '/tasks', jsonEncode(fresh.toJson()))).statusCode,
          409,
        );
      },
    );
  });
}
