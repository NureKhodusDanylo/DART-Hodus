import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:task_planner/task_planner.dart';

/// Порт сервісу за замовчуванням.
const int _defaultPort = 8080;

/// Точка входу HTTP-сервісу: лише запуск сервера.
///
/// Порт задається змінною середовища `PORT`, файл даних — `TASKS_FILE`.
Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? _defaultPort;
  final store = JsonFileTaskStore(
    Platform.environment['TASKS_FILE'] ?? defaultDataFile,
  );
  final server = await io.serve(
    buildHandler(store),
    InternetAddress.loopbackIPv4,
    port,
  );
  print('Сервіс слухає http://${server.address.host}:${server.port}');
}
