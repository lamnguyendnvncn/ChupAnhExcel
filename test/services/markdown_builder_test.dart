import 'package:flutter_test/flutter_test.dart';
import 'package:chup_anh_excel/models/task.dart';
import 'package:chup_anh_excel/services/markdown_builder.dart';

void main() {
  test('buildMarkdown creates heading and body', () {
    const task = Task(
      id: 'extract-excel',
      label: 'Extract table to Excel',
      instructions: 'Read the attached image.\nPreserve column headers.',
    );

    final md = buildMarkdown(task);

    expect(md, '''# Extract table to Excel

Read the attached image.
Preserve column headers.''');
  });
}
