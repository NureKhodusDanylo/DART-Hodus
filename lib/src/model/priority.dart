/// Пріоритет завдання як перелічення з членами.
library;

/// Пріоритет завдання — категорійна ознака із закритим набором значень.
///
/// Кожне значення має числовий рівень (як у вхідних даних) і назву.
/// Рівень поза 1–5 неможливо представити цим типом, тому перевірка
/// діапазону переходить з валідатора в розбір.
enum Priority implements Comparable<Priority> {
  /// Найнижчий пріоритет.
  lowest(1, 'найнижчий'),

  /// Низький пріоритет.
  low(2, 'низький'),

  /// Середній пріоритет.
  medium(3, 'середній'),

  /// Високий пріоритет.
  high(4, 'високий'),

  /// Критичний пріоритет.
  critical(5, 'критичний');

  /// Створює значення перелічення з рівнем [level] і назвою [label].
  const Priority(this.level, this.label);

  /// Числовий рівень пріоритету (1–5).
  final int level;

  /// Назва пріоритету українською.
  final String label;

  /// Чи є пріоритет високим (рівень 4 і вище).
  bool get isHigh => level >= Priority.high.level;

  /// Повертає пріоритет за рівнем [level] або `null`, якщо такого немає.
  static Priority? fromLevel(int level) =>
      values.where((p) => p.level == level).firstOrNull;

  @override
  int compareTo(Priority other) => level.compareTo(other.level);
}
