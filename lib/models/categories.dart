import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// A fixed set of task categories: what KIND of task it is (a group is
/// who shares it). Stored on the task by key; the name comes from the
/// language tables, the icon and colour from here.
class TaskCategory {
  const TaskCategory(this.key, this.icon, this.color);
  final String key;
  final IconData icon;
  final Color color;
}

const List<TaskCategory> taskCategories = [
  TaskCategory('health', Icons.favorite_rounded, Color(0xFFE5484D)),
  TaskCategory('work', Icons.work_rounded, Color(0xFF3E63DD)),
  TaskCategory('home', Icons.home_rounded, Color(0xFF12A594)),
  TaskCategory('shopping', Icons.shopping_bag_rounded, Color(0xFFE5A100)),
  TaskCategory('family', Icons.family_restroom_rounded, Color(0xFFD6409F)),
  TaskCategory('money', Icons.payments_rounded, Color(0xFF30A46C)),
  TaskCategory('study', Icons.school_rounded, Color(0xFF8E4EC6)),
  TaskCategory('errands', Icons.directions_car_rounded, Color(0xFFF76B15)),
  TaskCategory('fitness', Icons.fitness_center_rounded, Color(0xFF0091FF)),
];

TaskCategory? categoryByKey(String? key) => key == null ? null : taskCategories.where((c) => c.key == key).firstOrNull;

String categoryName(L10n l, String key) => switch (key) {
      'health' => l.categoryHealth,
      'work' => l.categoryWork,
      'home' => l.categoryHome,
      'shopping' => l.categoryShopping,
      'family' => l.categoryFamily,
      'money' => l.categoryMoney,
      'study' => l.categoryStudy,
      'errands' => l.categoryErrands,
      'fitness' => l.categoryFitness,
      _ => key,
    };
