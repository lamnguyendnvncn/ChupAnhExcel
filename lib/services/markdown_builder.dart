import '../models/task.dart';

String buildMarkdown(Task task) {
  return '# ${task.label}\n\n${task.instructions}';
}
