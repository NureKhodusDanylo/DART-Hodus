# task_planner — Планувальник завдань (ЛР4)

Лабораторна робота 4 з дисципліни «Програмування мовою Dart». Варіант 10 — «Планувальник
завдань». Завершальний етап наскрізного проєкту: консольний застосунок, що зберігає завдання
у JSON-файлі, імпортує дані із зовнішнього REST API та великих CSV-файлів, і HTTP-сервіс на
`shelf`, що надає доступ до тих самих даних. Попередні етапи — теги `lab1`…`lab3`.

## Встановлення та запуск

```bash
dart pub get
dart run bin/task_planner.dart init        # створити data/tasks.json з вбудованих даних
dart run bin/task_planner.dart --help      # довідка
dart run bin/server.dart                   # HTTP-сервіс на http://127.0.0.1:8080
dart test                                  # 38 тестів
dart compile exe bin/task_planner.dart -o build/task_planner.exe
```

> Якщо шлях до проєкту містить кириличні символи, `dart test` у Dart 3.13 завершується
> повідомленням `package_config.json did not contain its own root package`. У каталозі
> з латинським шляхом усі тести проходять.

### Команди CLI

| Команда | Опції | Що робить |
|---|---|---|
| `init` | — | Створює файл даних із вбудованого набору (13 завдань) |
| `list` | `-p/--project`, `-s/--status`, `-n/--limit` | Перелік із фільтрами |
| `add` | `--csv` | Додає завдання з рядка `id;назва;проєкт;пріоритет;створено;термін;стан;години` |
| `stats` | — | Звіт: топ за терміновістю, години за проєктами |
| `import-api` | `-u/--user`, `--api` | Імпортує справи з JSONPlaceholder у проєкт `EXT` |
| `import-csv` | `-i/--input` | Потоково читає великий CSV, рахує помилки |
| `generate-csv` | `-o/--output`, `-c/--count` | Генерує великий CSV для перевірки імпорту |

Глобальні опції: `-f/--file` (файл даних, за замовчуванням `data/tasks.json`), `-h/--help`.
Помилки виводяться в stderr; коди завершення: `0` успіх, `64` некоректні аргументи,
`65` некоректні дані, `69` зовнішній сервіс недоступний, `74` помилка файлової системи.

### HTTP-сервіс

Порт — змінна середовища `PORT` (8080), файл даних — `TASKS_FILE` (`data/tasks.json`).

| Маршрут | Відповіді |
|---|---|
| `GET /tasks?project=&status=&minPriority=` | `200` перелік; `400`, якщо `minPriority` не число |
| `GET /tasks/<id>` | `200` завдання; `404`, якщо його немає |
| `POST /tasks` | `201` створено; `400` некоректне тіло чи правила; `409` дублікат `id` |

Усі відповіді — `application/json; charset=utf-8`. Проміжний обробник `requestLogger`
пише в журнал метод, шлях, код і тривалість кожного запиту.

## Структура

```
bin/task_planner.dart     точка входу CLI (лише runCli)
bin/server.dart           точка входу сервісу (лише io.serve)
lib/task_planner.dart     фасад пакета: export з lib/src/
lib/src/model/            Task, TaskStatus, Priority, Project, Milestone, розширення
lib/src/storage/          TaskStore: InMemoryTaskStore, JsonFileTaskStore; CSV; Repository
lib/src/remote/           TodoApiClient і запечатана ієрархія ApiFailure
lib/src/cli/              buildArgParser, runCli, коди завершення
lib/src/server/           buildRouter, requestLogger, buildHandler
lib/src/async/, report/   код ЛР3 і звіти
example/async_demo.dart   демонстрація асинхронності з ЛР3
test/                     38 тестів
```

**Чому так.** Код у `bin/` неможливо імпортувати, отже й протестувати, тому там лише
виклики. Реалізація в `lib/src/` прихована: інші пакети бачать тільки те, що експортує
фасад. CLI і сервіс залежать від інтерфейсу `TaskStore`, а не від файлу, тому в тестах
сховище підміняється `InMemoryTaskStore`. `TodoApiClient` приймає `http.Client` ззовні —
у тестах це `MockClient`.

**Дві функції для JSON.** `Task.fromJson` з явними `as` — для власного файлу, структуру
якого гарантує програма: порушення структури — помилка, і вона має проявитися одразу.
`Task.tryFromJson` перевіряє тіло POST-запиту зіставленням зі зразком мапи і повертає
`null`, бо некоректне тіло від клієнта — очікувана ситуація, що дає `400`, а не виняток.

## Залежності

| Пакет | Розділ | Навіщо | Альтернатива |
|---|---|---|---|
| `path` | dependencies | `p.join` для шляхів на будь-якій ОС | конкатенація з `/` — ламається на Windows |
| `args` | dependencies | Команди, опції, `allowed`, `mandatory`, довідка | ручний розбір `arguments` — без довідки й перевірок |
| `http` | dependencies | `http.Client` і `MockClient` для тестів | `dart:io HttpClient` — нижчий рівень, без готової підміни |
| `shelf` | dependencies | Обробники, `Pipeline`, `Middleware`, сервер | `dart:io HttpServer` — усе вручну |
| `shelf_router` | dependencies | Маршрути з параметрами `/tasks/<id>` | розбір `request.url` вручну |
| `test` | dev_dependencies | Модульні тести | — |
| `lints` | dev_dependencies | Правила `dart analyze` | `very_good_analysis` |

`test` і `lints` лежать у `dev_dependencies`: вони потрібні лише розробнику й не потрапляють
у залежності застосунку. `pubspec.lock` закомічено, бо це застосунок, а не бібліотека:
усі збирають ті самі версії. `dart pub deps`: 53 пакети, з них 7 прямих і 46 транзитивних.
`dart pub outdated`: прямі залежності актуальні; застарілий лише транзитивний
`shelf_static 1.1.3` (1.2.0) — його тягне `test`, у застосунок він не потрапляє, тому
окремо не оновлювався.

## Оператор `!`, `late`, `dynamic`

- **`dynamic`** — неминучий результат `jsonDecode`. Його одразу перетворюють: у
  `JsonFileTaskStore.loadAll` через `as List<Object?>` і `Task.fromJson`, у сервісі й
  клієнті API — через присвоєння в `Object?` і зіставлення зі зразком. Далі в коді
  `dynamic` не з'являється (лінт `avoid_dynamic_calls` увімкнено).
- **`late`** — лише в тестах для змінних, що ініціалізуються в `setUp`.
- **`!`** не використовується.

## Секрети

API JSONPlaceholder не потребує ключа. `.gitignore` містить `.dart_tool/`, `build/`, `.env`
і `data/` (згенеровані файли даних).
