/// Узагальнене сховище сутностей.
library;

import 'identifiable.dart';

/// Сховище сутностей, які вміють повідомляти власний ідентифікатор.
///
/// Обмеження `T extends Identifiable` гарантує, що в кожного елемента
/// є `id`, тому сховище може індексувати елементи за ним. Без обмеження
/// компілятор знав би про `T` лише те, що це `Object?`.
class Repository<T extends Identifiable> {
  /// Створює порожнє сховище.
  Repository();

  /// Створює сховище з початковими елементами [items].
  Repository.of(Iterable<T> items) {
    items.forEach(add);
  }

  final Map<String, T> _items = {};

  /// Додає або замінює елемент [item] з тим самим ідентифікатором.
  void add(T item) => _items[item.id] = item;

  /// Повертає елемент за ідентифікатором [id] або `null`.
  T? findById(String id) => _items[id];

  /// Видаляє елемент за ідентифікатором [id]; повертає видалений елемент.
  T? remove(String id) => _items.remove(id);

  /// Елементи, що задовольняють умову [test].
  Iterable<T> where(bool Function(T item) test) => _items.values.where(test);

  /// Усі елементи в порядку додавання (лише для читання).
  List<T> get all => List.unmodifiable(_items.values);

  /// Кількість елементів.
  int get length => _items.length;

  /// Чи містить сховище елемент з ідентифікатором [id].
  bool contains(String id) => _items.containsKey(id);
}
