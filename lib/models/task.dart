class Task {
  const Task({
    required this.id,
    required this.label,
    required this.instructions,
  });

  final String id;
  final String label;
  final String instructions;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      label: json['label'] as String,
      instructions: json['instructions'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'instructions': instructions,
      };
}
