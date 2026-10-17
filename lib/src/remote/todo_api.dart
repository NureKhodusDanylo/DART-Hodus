/// Клієнт зовнішнього REST API зі списком справ.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../model/extensions.dart';
import '../model/priority.dart';
import '../model/task.dart';
import '../model/task_status.dart';

/// Адреса відкритого API, що не потребує ключа автентифікації.
final Uri defaultTodoApi = Uri.parse('https://jsonplaceholder.typicode.com/');

/// Код проєкту, до якого зараховуються завдання із зовнішнього API.
const String externalProject = 'EXT';

/// Скільки днів відводиться на виконання імпортованого завдання.
const Duration _importedTaskWindow = Duration(days: 14);

/// Типова оцінка трудомісткості імпортованого завдання, годин.
const double _importedTaskHours = 2;

/// Відмова під час звернення до зовнішнього API.
///
/// Запечатана ієрархія відповідає трьом рівням відмов мережевої взаємодії.
sealed class ApiFailure implements Exception {
  /// Створює відмову з повідомленням [message].
  const ApiFailure(this.message);

  /// Опис причини.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Рівень 1: з'єднання не встановлено (немає мережі, DNS, відмова хосту).
final class NetworkFailure extends ApiFailure {
  /// Створює відмову мережі з повідомленням [message].
  const NetworkFailure(super.message);
}

/// Рівень 2: сервер відповів кодом, відмінним від 2xx.
final class HttpStatusFailure extends ApiFailure {
  /// Створює відмову для коду відповіді [statusCode].
  HttpStatusFailure(this.statusCode)
    : super('сервер відповів кодом $statusCode');

  /// Код відповіді HTTP.
  final int statusCode;
}

/// Рівень 3: відповідь отримано, але її тіло некоректне.
final class BadPayloadFailure extends ApiFailure {
  /// Створює відмову з описом проблеми [message].
  const BadPayloadFailure(super.message);
}

/// Клієнт API справ `GET /todos?userId=…`.
///
/// Приймає [http.Client] ззовні, тому в тестах мережа підміняється
/// `MockClient`. Клієнт закриває той, хто його створив.
class TodoApiClient {
  /// Створює клієнт поверх [client] для сервера [baseUri].
  TodoApiClient(this._client, {Uri? baseUri})
    : baseUri = baseUri ?? defaultTodoApi;

  final http.Client _client;

  /// Базова адреса API.
  final Uri baseUri;

  /// Завантажує справи користувача [userId] і перетворює їх на завдання.
  ///
  /// Успішне завершення `await` не означає успішного запиту, тому код
  /// відповіді перевіряється явно. Кидає [ApiFailure] одного з трьох рівнів.
  Future<List<Task>> fetchTasks({int userId = 1, DateTime? now}) async {
    final uri = baseUri
        .resolve('todos')
        .replace(queryParameters: {'userId': '$userId'});
    final http.Response response;
    try {
      response = await _client.get(uri);
    } on SocketException catch (e) {
      throw NetworkFailure(e.message);
    } on http.ClientException catch (e) {
      throw NetworkFailure(e.message);
    }

    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      throw HttpStatusFailure(response.statusCode);
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw BadPayloadFailure('тіло відповіді не є JSON: ${e.message}');
    }
    if (body is! List<Object?>) {
      throw const BadPayloadFailure('очікувався масив справ');
    }
    final today = (now ?? DateTime.now()).dateOnly;
    return [for (final item in body) _toTask(item, today)];
  }

  /// Перетворює один елемент відповіді на завдання.
  Task _toTask(Object? item, DateTime today) => switch (item) {
    {
      'id': final int id,
      'title': final String title,
      'completed': final bool completed,
    } =>
      Task(
        id: '$externalProject-$id',
        title: title,
        project: externalProject,
        priority: Priority.medium,
        createdAt: today,
        deadline: today.add(_importedTaskWindow),
        status: completed ? const Done() : const Todo(),
        estimateHours: _importedTaskHours,
      ),
    _ => throw BadPayloadFailure('некоректний елемент: $item'),
  };
}
