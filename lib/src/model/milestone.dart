/// Віха проєкту — сутність, оголошена первинним конструктором.
library;

import 'identifiable.dart';
import 'scheduled.dart';

/// Контрольна точка проєкту з терміном (реліз, демонстрація тощо).
///
/// Оголошена первинним конструктором (Dart 3.13): параметри `final`
/// одразу стають полями, `super.id` передається в [Entity].
/// Як і [Task], підмішує [Scheduled], хоча не є завданням.
final class Milestone(
  super.id,

  /// Назва віхи.
  final String title,

  @override final DateTime deadline, {

  /// Чи досягнуто віху.
  final bool reached = false,
}) extends Entity with Scheduled {
  /// Створює віху з ідентифікатором, назвою і терміном.
  this;

  @override
  String get displayName => title;

  @override
  bool get isClosed => reached;
}
