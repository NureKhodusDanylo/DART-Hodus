/// Перевірка діапазонів і узгодженості полів завдання.
library;

import 'constants.dart';
import 'model.dart';
import 'text_utils.dart';

/// Перевіряє завдання [task] і повертає перелік виявлених порушень.
///
/// Порожній список означає, що завдання коректне.
List<String> validateTask(Task task) {
  final projectInId = projectFromId(task.id);
  return [
    if (projectInId == null) 'ідентифікатор "${task.id}" не відповідає формату',
    if (projectInId != null && projectInId != task.project)
      'код проєкту в ідентифікаторі ($projectInId) не збігається з ${task.project}',
    if (task.priority < minPriority || task.priority > maxPriority)
      'пріоритет ${task.priority} поза межами $minPriority..$maxPriority',
    if (task.estimateHours < minEstimateHours ||
        task.estimateHours > maxEstimateHours)
      'трудомісткість ${task.estimateHours} год поза межами '
          '$minEstimateHours..$maxEstimateHours',
    if (!allowedStatuses.contains(task.status))
      'невідомий статус "${task.status}"',
    if (task.deadline.isBefore(task.createdAt))
      'термін виконання раніше за дату створення',
  ];
}

/// Перевіряє, чи завдання [task] не має жодного порушення.
bool isValidTask(Task task) => validateTask(task).isEmpty;
