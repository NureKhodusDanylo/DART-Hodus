## 4.0.0

- ЛР4: канонічна структура пакета (`lib/src/`, фасад `lib/task_planner.dart`).
- CLI на `args`: команди `init`, `list`, `add`, `stats`, `import-api`, `import-csv`,
  `generate-csv`; помилки в stderr, коди завершення 0/64/65/69/74.
- Збереження у JSON (`JsonFileTaskStore`), потокове читання CSV через `openRead()`.
- Клієнт JSONPlaceholder на `http.Client` з трьома рівнями відмов.
- HTTP-сервіс на `shelf`/`shelf_router`: `GET /tasks`, `GET /tasks/<id>`, `POST /tasks`,
  журналювання запитів.
- Демонстрацію асинхронності з ЛР3 перенесено в `example/async_demo.dart`.
- 38 тестів, мережа в тестах підмінена `MockClient`.

## 3.0.0

- ЛР3: асинхронне сховище AsyncRepository, події на StreamController,
  генератор async*, Isolate.run для важкого обчислення, 11 асинхронних тестів.

## 2.0.0

- ЛР2: обʼєктно-орієнтована модель — клас Task, sealed TaskStatus, enum Priority,
  домішка Scheduled, узагальнене сховище Repository, методи розширення.

## 1.0.0

- ЛР1: розбір, перевірка та агрегація завдань на функціях і записах.
