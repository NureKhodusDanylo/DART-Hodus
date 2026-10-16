/// Базові абстракції сутностей предметної області.
library;

/// Сутність, яка вміє повідомляти власний ідентифікатор.
///
/// Інтерфейс (`interface class`) задає лише контракт: класи його
/// реалізують через `implements`, але не успадковують реалізацію.
abstract interface class Identifiable {
  /// Унікальний ідентифікатор сутності.
  String get id;
}

/// Базовий клас усіх сутностей планувальника: завдань, проєктів і віх.
///
/// Зберігає ідентифікатор і визначає рівність за ним. Абстрактний, бо
/// сутність «взагалі» не має змісту без конкретного підтипу.
abstract class Entity implements Identifiable {
  /// Створює сутність з ідентифікатором [id].
  const Entity(this.id);

  @override
  final String id;

  /// Коротка назва сутності для виводу.
  String get displayName;

  @override
  String toString() => '$runtimeType($id: $displayName)';
}
