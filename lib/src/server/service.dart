/// HTTP-сервіс планувальника на основі `shelf`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../model/task.dart';
import '../storage/task_store.dart';

/// Заголовки відповіді з JSON у кодуванні UTF-8.
const Map<String, String> jsonHeaders = {
  HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
};

/// Відповідь з тілом [body], перетвореним на JSON, і кодом [status].
Response jsonResponse(Object? body, {int status = HttpStatus.ok}) => Response(
  status,
  body: jsonEncode(body),
  headers: jsonHeaders,
  encoding: utf8,
);

/// Відповідь-помилка з описом [message] і кодом [status].
Response jsonError(int status, String message) =>
    jsonResponse({'error': message}, status: status);

/// Будує маршрутизатор сервісу поверх сховища [store].
///
/// * `GET /tasks` — перелік з фільтрами `project`, `status`, `minPriority`;
/// * `GET /tasks/<id>` — одне завдання або 404;
/// * `POST /tasks` — створення; 400 на некоректне тіло, 409 на дублікат.
Router buildRouter(TaskStore store) => Router()
  ..get('/tasks', (Request request) async {
    final query = request.url.queryParameters;
    final rawMin = query['minPriority'];
    final minPriority = rawMin == null ? null : int.tryParse(rawMin);
    if (rawMin != null && minPriority == null) {
      return jsonError(HttpStatus.badRequest, 'minPriority має бути числом');
    }
    final tasks = await loadFiltered(
      store,
      project: query['project'],
      status: query['status'],
      minPriority: minPriority,
    );
    return jsonResponse([for (final t in tasks) t.toJson()]);
  })
  ..get('/tasks/<id>', (Request request, String id) async {
    final task = await store.findById(id);
    return task == null
        ? jsonError(HttpStatus.notFound, 'завдання $id не знайдено')
        : jsonResponse(task.toJson());
  })
  ..post('/tasks', (Request request) async {
    final Object? body;
    try {
      body = jsonDecode(await request.readAsString());
    } on FormatException {
      return jsonError(HttpStatus.badRequest, 'тіло запиту не є JSON');
    }
    final task = Task.tryFromJson(body);
    if (task == null) {
      return jsonError(
        HttpStatus.badRequest,
        'тіло має містити всі поля завдання коректних типів',
      );
    }
    if (!task.isValid) {
      return jsonError(HttpStatus.badRequest, task.violations.join('; '));
    }
    if (await store.findById(task.id) != null) {
      return jsonError(HttpStatus.conflict, 'завдання ${task.id} вже існує');
    }
    await store.put(task);
    return jsonResponse(task.toJson(), status: HttpStatus.created);
  });

/// Проміжний обробник журналювання: метод, шлях, код і тривалість
/// кожного запиту передаються у функцію [log].
Middleware requestLogger(void Function(String line) log) =>
    (Handler inner) => (Request request) async {
      final stopwatch = Stopwatch()..start();
      final response = await inner(request);
      log(
        '${request.method.padRight(4)} /${request.url} → '
        '${response.statusCode} (${stopwatch.elapsedMilliseconds} мс)',
      );
      return response;
    };

/// Повний обробник сервісу: журналювання + маршрутизатор.
Handler buildHandler(TaskStore store, {void Function(String line)? log}) =>
    const Pipeline()
        .addMiddleware(requestLogger(log ?? print))
        .addHandler(buildRouter(store).call);
