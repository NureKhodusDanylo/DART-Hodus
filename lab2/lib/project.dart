/// Проєкт — сутність без терміну.
library;

import 'identifiable.dart';

/// Проєкт, до якого належать завдання; ідентифікатор — код проєкту.
///
/// Проєкт не має терміну, тому не підмішує `Scheduled`.
final class Project extends Entity {
  /// Створює проєкт з кодом [code], назвою [name] і керівником [lead].
  const Project(super.code, this.name, {this.lead});

  /// Повна назва проєкту.
  final String name;

  /// Керівник проєкту, якщо призначений.
  final String? lead;

  @override
  String get displayName => name;
}

/// Довідник проєктів планувальника.
const List<Project> knownProjects = [
  Project('WEB', 'Вебзастосунок', lead: 'Іваненко'),
  Project('MOB', 'Мобільний застосунок', lead: 'Петренко'),
  Project('API', 'Серверний API'),
  Project('DOC', 'Документація'),
];
