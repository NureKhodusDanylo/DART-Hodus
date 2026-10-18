/// Асинхронне сховище сутностей.
library;

import 'identifiable.dart';

/// Помилка: сутності з указаним ідентифікатором немає у сховищі.
final class EntityNotFound implements Exception {
  /// Створює помилку для ідентифікатора [id].
  const EntityNotFound(this.id);

  /// Ідентифікатор, який не знайдено.
  final String id;

  @override
  String toString() => 'EntityNotFound: немає сутності з id "$id"';
}

/// Асинхронне сховище сутностей предметної області.
///
/// Кожна операція повертає [Future]; затримка [latency] імітує
/// звернення до диска чи мережі (справжні файли й мережа — у ЛР4).
/// У тестах затримку можна задати нульовою.
class AsyncRepository<T extends Identifiable> {
  /// Створює порожнє сховище з затримкою операцій [latency].
  AsyncRepository({this.latency = const Duration(milliseconds: 300)});

  /// Затримка кожної операції.
  final Duration latency;

  final Map<String, T> _items = {};

  /// Імітує очікування на зовнішнє джерело даних.
  Future<void> _wait([Duration? delay]) =>
      Future<void>.delayed(delay ?? latency);

  /// Повертає сутність за ідентифікатором [id] або `null`.
  Future<T?> load(String id, {Duration? delay}) async {
    await _wait(delay);
    return _items[id];
  }

  /// Повертає сутність за ідентифікатором [id]; завершується помилкою
  /// [EntityNotFound], якщо її немає.
  Future<T> loadOrThrow(String id, {Duration? delay}) async {
    await _wait(delay);
    return _items[id] ?? (throw EntityNotFound(id));
  }

  /// Повертає всі сутності в порядку додавання.
  Future<List<T>> loadAll() async {
    await _wait();
    return List.unmodifiable(_items.values);
  }

  /// Зберігає сутність [item], замінюючи наявну з тим самим `id`.
  Future<void> save(T item) async {
    await _wait();
    _items[item.id] = item;
  }

  /// Зберігає всі сутності [items] однією операцією.
  Future<void> saveAll(Iterable<T> items) async {
    await _wait();
    for (final item in items) {
      _items[item.id] = item;
    }
  }

  /// Видаляє сутність за ідентифікатором [id]; повертає `true`,
  /// якщо вона була у сховищі.
  Future<bool> delete(String id) async {
    await _wait();
    return _items.remove(id) != null;
  }

  /// Видає сутності по одній у міру «надходження» з інтервалом [interval].
  ///
  /// Генератор `async*` лінивий: тіло починає виконуватися лише після
  /// підписки на потік. Функція [onStart], якщо задана, викликається
  /// першим рядком тіла — так це можна побачити у виводі.
  Stream<T> watchAll({
    Duration interval = const Duration(milliseconds: 100),
    void Function()? onStart,
  }) async* {
    onStart?.call();
    for (final item in _items.values.toList()) {
      await Future<void>.delayed(interval);
      yield item;
    }
  }
}
