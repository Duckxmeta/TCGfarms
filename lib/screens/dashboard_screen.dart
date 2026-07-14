// lib/screens/dashboard_screen.dart
//
// New home tab. The old home_screen crammed portfolio stats, navigation
// shortcuts, and the entire bird grid into one 850-line scrolling widget.
// That grid now lives in CollectionScreen; this screen is a proper
// dashboard: today's snapshot + quick actions + anything that needs
// attention (urgent tasks, upcoming hatches).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bird.dart';
import '../models/incubation_batch.dart';
import '../repositories/bird_repository.dart';
import '../repositories/incubation_repository.dart';
import '../services/grading_engine.dart';
import '../services/task_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/storage_image.dart';
import 'add_bird_screen.dart';
import 'new_incubation_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onViewCollection;
  final VoidCallback onViewTasks;

  const DashboardScreen({
    super.key,
    required this.onViewCollection,
    required this.onViewTasks,
  });

  @override
  Widget build(BuildContext context) {
    final birdRepo = context.watch<BirdRepository>();
    final incubationRepo = context.watch<IncubationRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TCG Farms', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<List<Bird>>(
        stream: birdRepo.watchMyBirds(),
        builder: (context, birdSnap) {
          if (birdSnap.hasError) {
            return ErrorView(message: 'Could not load your dashboard.\n${birdSnap.error}');
          }
          if (!birdSnap.hasData) {
            return const LoadingView(message: 'Loading dashboard…');
          }
          final birds = birdSnap.data!;

          return StreamBuilder<List<IncubationBatch>>(
            stream: incubationRepo.watchMyBatches(),
            builder: (context, batchSnap) {
              final batches = batchSnap.data ?? [];
              final tasks = TaskEngine.generateTasks(birds: birds, batches: batches);
              final urgentTasks = tasks.where((t) => t.category == 'Urgent').toList();

              final totalBirds = birds.length;
              final avgGrade = totalBirds > 0
                  ? birds.map(GradingEngine.calculateGrade).reduce((a, b) => a + b) / totalBirds
                  : 0.0;
              final estimatedValue = birds.fold<double>(
                0.0,
                (sum, b) => sum + GradingEngine.calculateValue(b.rarityTier, GradingEngine.calculateGrade(b)),
              );

              final recentBirds = List<Bird>.from(birds)
                ..sort((a, b) => b.ageOrHatchDate.compareTo(a.ageOrHatchDate));

              return RefreshIndicator(
                onRefresh: () async {},
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _PortfolioCard(totalBirds: totalBirds, avgGrade: avgGrade, estimatedValue: estimatedValue),
                    const SizedBox(height: AppSpacing.md),
                    if (urgentTasks.isNotEmpty) ...[
                      _UrgentBanner(count: urgentTasks.length, onTap: onViewTasks),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text('Quick actions', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.add_circle,
                            label: 'Add Bird',
                            color: AppColors.primary,
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const AddBirdScreen())),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.egg,
                            label: 'New Batch',
                            color: Colors.deepOrange,
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const NewIncubationScreen())),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.checklist,
                            label: 'Tasks',
                            color: AppColors.success,
                            onTap: onViewTasks,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recently added', style: AppTextStyles.sectionTitle),
                        TextButton(onPressed: onViewCollection, child: const Text('View all')),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (recentBirds.isEmpty)
                      EmptyStateView(
                        title: 'No birds yet',
                        subtitle: 'Add your first bird to get started.',
                        actionLabel: 'Add a bird',
                        onAction: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const AddBirdScreen())),
                      )
                    else
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recentBirds.take(10).length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (context, i) => _RecentBirdChip(bird: recentBirds[i]),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final int totalBirds;
  final double avgGrade;
  final double estimatedValue;

  const _PortfolioCard({required this.totalBirds, required this.avgGrade, required this.estimatedValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.radiusLg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Birds', '$totalBirds', Icons.pets),
          _stat('Avg. Grade', avgGrade.toStringAsFixed(1), Icons.star),
          _stat('Est. Value', '\$${estimatedValue.toStringAsFixed(0)}', Icons.savings),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _UrgentBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.radiusMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.urgentSurface,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(color: AppColors.urgent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Text('🚨', style: TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$count urgent task${count == 1 ? '' : 's'} need attention today',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.urgent),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.urgent),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.radiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RecentBirdChip extends StatelessWidget {
  final Bird bird;
  const _RecentBirdChip({required this.bird});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: (bird.photoUrl != null && bird.photoUrl!.isNotEmpty)
                  ? StorageImage(
                      photoUrl: bird.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: AppColors.primarySurface,
                        child: const Center(child: Text('🐣', style: TextStyle(fontSize: 18))),
                      ),
                    )
                  : Container(
                      color: AppColors.primarySurface,
                      child: const Center(child: Text('🐣', style: TextStyle(fontSize: 18))),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bird.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
