/// Розбір вхідних рядків у записи завдань.
library;

import 'constants.dart';
import 'dates.dart';
import 'model.dart';

/// Розбирає рядок [line] у завдання.
///
/// Повертає запис, у якому заповнене або поле `task`, або поле `error`
/// з описом причини відмови. Винятки не використовуються: пошкоджені дані
/// — очікувана ситуація, тому перевірка виконується через `tryParse`.
ParseResult parseLine(String line) {
  final fields = line.split(fieldSeparator).map((f) => f.trim()).toList();
  if (fields.length != fieldCount) {
    return _fail('очікувалось $fieldCount полів, отримано ${fields.length}');
  }
  if (fields.any((f) => f.isEmpty)) {
    return _fail('порожнє поле');
  }

  final [
    id,
    title,
    project,
    rawPriority,
    rawCreated,
    rawDeadline,
    status,
    rawHours,
  ] = fields;

  final priority = int.tryParse(rawPriority);
  if (priority == null) return _fail('пріоритет "$rawPriority" не є числом');

  final createdAt = parseStrictDate(rawCreated);
  if (createdAt == null) {
    return _fail('некоректна дата створення "$rawCreated"');
  }

  final deadline = parseStrictDate(rawDeadline);
  if (deadline == null) return _fail('некоректний термін "$rawDeadline"');

  final estimateHours = double.tryParse(rawHours);
  if (estimateHours == null) {
    return _fail('трудомісткість "$rawHours" не є числом');
  }

  return (
    task: (
      id: id,
      title: title,
      project: project,
      priority: priority,
      createdAt: createdAt,
      deadline: deadline,
      status: status,
      estimateHours: estimateHours,
    ),
    error: null,
  );
}

/// Формує результат розбору з помилкою [message].
ParseResult _fail(String message) => (task: null, error: message);
