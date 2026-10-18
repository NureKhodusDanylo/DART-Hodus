/// Іменовані константи планувальника завдань.
///
/// Усі «магічні» числа й рядки зібрано тут, щоб змінювати правила
/// перевірки в одному місці.
library;

/// Роздільник полів у вхідному CSV-подібному рядку.
const String fieldSeparator = ';';

/// Очікувана кількість полів у рядку завдання.
const int fieldCount = 8;

/// Мінімальна оцінка трудомісткості в годинах.
const double minEstimateHours = 0.5;

/// Максимальна оцінка трудомісткості в годинах.
const double maxEstimateHours = 200;

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
