String generateBasename({DateTime? now, Set<String>? existing}) {
  final dt = now ?? DateTime.now();
  final base = '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}_'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}';

  final taken = existing ?? {};
  if (!taken.contains(base)) {
    return base;
  }

  var suffix = 1;
  while (taken.contains('${base}_$suffix')) {
    suffix++;
  }
  return '${base}_$suffix';
}
