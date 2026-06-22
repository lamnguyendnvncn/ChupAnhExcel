import 'package:flutter_test/flutter_test.dart';
import 'package:chup_anh_excel/services/basename_generator.dart';

void main() {
  test('generateBasename formats local timestamp', () {
    final result = generateBasename(
      now: DateTime(2025, 6, 19, 14, 30, 22),
    );
    expect(result, '20250619_143022');
  });

  test('generateBasename appends suffix on collision', () {
    final result = generateBasename(
      now: DateTime(2025, 6, 19, 14, 30, 22),
      existing: {'20250619_143022'},
    );
    expect(result, '20250619_143022_1');
  });

  test('generateBasename increments suffix until unique', () {
    final result = generateBasename(
      now: DateTime(2025, 6, 19, 14, 30, 22),
      existing: {'20250619_143022', '20250619_143022_1'},
    );
    expect(result, '20250619_143022_2');
  });
}
