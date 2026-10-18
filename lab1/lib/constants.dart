/// Іменовані константи планувальника завдань.
///
/// Усі «магічні» числа й рядки зібрано тут, щоб змінювати правила
/// перевірки в одному місці.
library;

/// Роздільник полів у вхідному CSV-подібному рядку.
const String fieldSeparator = ';';

/// Очікувана кількість полів у рядку завдання.
const int fieldCount = 8;

/// Мінімально допустимий пріоритет завдання.
const int minPriority = 1;

/// Максимально допустимий пріоритет завдання.
const int maxPriority = 5;

/// Пріоритет, починаючи з якого завдання вважається високопріоритетним.
const int highPriorityThreshold = 4;

/// Мінімальна оцінка трудомісткості в годинах.
const double minEstimateHours = 0.5;

/// Максимальна оцінка трудомісткості в годинах.
const double maxEstimateHours = 200;

/// Статус завдання, до виконання якого ще не приступили.
const String statusTodo = 'todo';

/// Статус завдання, яке виконується.
const String statusInProgress = 'in_progress';

/// Статус виконаного завдання.
const String statusDone = 'done';

/// Множина допустимих статусів завдання.
const Set<String> allowedStatuses = {statusTodo, statusInProgress, statusDone};

/// Вікно, у межах якого термін виконання вважається найближчим.
const Duration dueSoonWindow = Duration(days: 7);

/// Кількість завдань у розділі «топ» звіту за замовчуванням.
const int defaultTopCount = 5;

/// Роздільник колонок у звіті за замовчуванням.
const String defaultColumnSeparator = ' | ';

/// Символ, яким маскуються цифри ідентифікатора.
const String maskChar = '*';

/// Ширина колонки з назвою завдання у звіті.
const int titleColumnWidth = 26;

/// Кількість знаків після коми під час виведення годин.
const int hoursFractionDigits = 1;
