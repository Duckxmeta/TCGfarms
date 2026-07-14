// lib/screens/daily_tasks_screen.dart
//
// Fixed bug: checking off a task used to only update a local in-memory Map,
// so all progress was lost when you left the screen. Completion state is
// now written to Firestore via TaskRepository and streamed back, so it
// persists across navigation and app restarts, and resets naturally each
// new day.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bird.dart';
import '../models/incubation_batch.dart';
import '../repositories/bird_repository.dart';
import '../repositories/incubation_repository.dart';
import '../repositories/task_repository.dart';
import '../services/task_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class DailyTasksScreen extends StatelessWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final birdRepo = context.watch<BirdRepository>();
    final incubationRepo = context.watch<IncubationRepository>();
    final taskRepo = context.watch<TaskRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Care Checklist')),
      body: StreamBuilder<List<Bird>>(
        stream: birdRepo.watchMyBirds(),
        builder: (context, birdSnap) {
          if (birdSnap.hasError) {
            return ErrorView(message: 'Could not load your flock.\n${birdSnap.error}');
          }
          if (!birdSnap.hasData) {
            return const LoadingView(message: 'Loading today\'s tasks…');
          }
          final birds = birdSnap.data!;

          return StreamBuilder<List<IncubationBatch>>(
            stream: incubationRepo.watchMyBatches(),
            builder: (context, batchSnap) {
              if (!batchSnap.hasData) {
                return const LoadingView(message: 'Loading today\'s tasks…');
              }
              final batches = batchSnap.data!;
              final allTasks = TaskEngine.generateTasks(birds: birds, batches: batches);

              return StreamBuilder<Map<String, bool>>(
                stream: taskRepo.watchTodayCompletions(),
                builder: (context, completionSnap) {
                  final completions = completionSnap.data ?? {};
                  for (final task in allTasks) {
                    task.isCompleted = completions[task.id] ?? false;
                  }

                  if (allTasks.isEmpty) {
                    return const EmptyStateView(
                      emoji: '☀️',
                      title: 'All quiet today',
                      subtitle: 'No tasks generated. Enjoy the quiet day!',
                    );
                  }

                  final completedCount = allTasks.where((t) => t.isCompleted).length;
                  final progress = completedCount / allTasks.length;

                  final urgent = allTasks.where((t) => t.category == 'Urgent').toList();
                  final morning = allTasks.where((t) => t.category == 'Morning').toList();
                  final evening = allTasks.where((t) => t.category == 'Evening').toList();
                  final general = allTasks.where((t) => t.category == 'General').toList();

                  return Column(
                    children: [
                      Card(
                        margin: const EdgeInsets.all(AppSpacing.md),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Today's Progress", style: AppTextStyles.sectionTitle),
                                  Text('$completedCount / ${allTasks.length} Done',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 10,
                                  backgroundColor: AppColors.primarySurface,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          children: [
                            if (urgent.isNotEmpty)
                              _TaskGroup(
                                title: '🚨 Urgent Alerts',
                                tasks: urgent,
                                cardColor: AppColors.urgentSurface,
                                borderColor: AppColors.urgent,
                                onToggle: (task, val) => taskRepo.setTaskCompleted(task.id, val),
                              ),
                            if (morning.isNotEmpty)
                              _TaskGroup(
                                title: '🌅 Morning Routine',
                                tasks: morning,
                                onToggle: (task, val) => taskRepo.setTaskCompleted(task.id, val),
                              ),
                            if (evening.isNotEmpty)
                              _TaskGroup(
                                title: '🌙 Evening Lockdown',
                                tasks: evening,
                                onToggle: (task, val) => taskRepo.setTaskCompleted(task.id, val),
                              ),
                            if (general.isNotEmpty)
                              _TaskGroup(
                                title: '📅 General Care',
                                tasks: general,
                                onToggle: (task, val) => taskRepo.setTaskCompleted(task.id, val),
                              ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TaskGroup extends StatelessWidget {
  final String title;
  final List<GeneratedTask> tasks;
  final Color? cardColor;
  final Color? borderColor;
  final void Function(GeneratedTask task, bool value) onToggle;

  const _TaskGroup({
    required this.title,
    required this.tasks,
    required this.onToggle,
    this.cardColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm, left: 4.0),
          child: Text(title, style: AppTextStyles.sectionTitle),
        ),
        Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.radiusMd,
            side: borderColor != null ? BorderSide(color: borderColor!, width: 1.5) : const BorderSide(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return CheckboxListTile(
                value: task.isCompleted,
                activeColor: AppColors.primary,
                title: Row(
                  children: [
                    Text(task.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                          color: task.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 30.0, top: 4.0),
                  child: Text(
                    task.description,
                    style: TextStyle(
                      color: task.isCompleted ? AppColors.textMuted : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) onToggle(task, value);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
