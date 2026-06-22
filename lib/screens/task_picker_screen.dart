import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskPickerScreen extends StatelessWidget {
  const TaskPickerScreen({
    super.key,
    required this.tasks,
    required this.onSelected,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick task')),
      body: ListView.separated(
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return ListTile(
            title: Text(task.label),
            subtitle: Text(
              task.instructions,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelected(task),
          );
        },
      ),
    );
  }
}
