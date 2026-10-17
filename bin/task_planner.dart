import 'dart:io';

import 'package:task_planner/task_planner.dart';

/// Точка входу консольного застосунку: уся логіка — у `runCli`.
Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}
