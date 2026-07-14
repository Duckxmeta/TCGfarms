import '../models/bird.dart';
import '../models/incubation_batch.dart';

class GeneratedTask {
  final String id;
  final String title;
  final String description;
  final String category; // 'Urgent', 'Morning', 'Evening', 'General'
  final String icon;
  bool isCompleted;

  GeneratedTask({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.isCompleted = false,
  });
}

class TaskEngine {
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static List<GeneratedTask> generateTasks({
    required List<Bird> birds,
    required List<IncubationBatch> batches,
  }) {
    final List<GeneratedTask> tasks = [];
    final today = DateTime.now();

    // 1. Check Incubation Batches for Urgent Alerts & Species-Specific Chores
    for (final batch in batches) {
      if (_isSameDay(batch.lockdownDate, today)) {
        tasks.add(
          GeneratedTask(
            id: 'lockdown_${batch.id}',
            title: 'Lockdown Mode: ${batch.batchName}',
            description: 'Increase humidity to 70% and stop turning eggs. Move them to the hatching tray.',
            category: 'Urgent',
            icon: '🥚',
          ),
        );
      }
      
      if (_isSameDay(batch.projectedHatchDate, today)) {
        tasks.add(
          GeneratedTask(
            id: 'hatch_${batch.id}',
            title: 'Hatch Day Alert! 🐣',
            description: 'Batch "${batch.batchName}" is due to hatch today! Keep the incubator closed and watch for pips.',
            category: 'Urgent',
            icon: '🐣',
          ),
        );
      }

      // Goose egg misting & cooling routine: Days 4-26
      if (batch.breedTemplateId == 'goose') {
        final incubationDay = today.difference(batch.startDate).inDays + 1;
        if (incubationDay >= 4 && incubationDay <= 26) {
          tasks.add(
            GeneratedTask(
              id: 'goose_mist_${batch.id}',
              title: 'Mist & Cool Goose Eggs (Day $incubationDay)',
              description: 'Batch "${batch.batchName}": Lightly mist eggs with lukewarm water and let cool for 15 minutes daily to simulate the mother goose leaving the nest.',
              category: 'General',
              icon: '💧',
            ),
          );
        }
      }
    }

    // 2. Check Birds for Age-Specific Brooder Care (Ducklings under 6 weeks / 42 days)
    int ducklingCount = 0;
    for (final bird in birds) {
      final ageInDays = today.difference(bird.ageOrHatchDate).inDays;
      if (ageInDays >= 0 && ageInDays < 42) {
        ducklingCount++;
        tasks.add(
          GeneratedTask(
            id: 'brooder_bedding_${bird.id}',
            title: 'Clean Brooder Bedding (${bird.name})',
            description: '${bird.name} is a duckling ($ageInDays days old). Clean and dry bedding is crucial to prevent leg problems and chills.',
            category: 'Morning',
            icon: '🧹',
          ),
        );
      }
    }

    if (ducklingCount > 0) {
      tasks.add(
        GeneratedTask(
          id: 'brooder_heat',
          title: 'Check Brooder Temperature',
          description: 'Verify brooder heat source is secure and at the correct temperature for $ducklingCount duckling(s).',
          category: 'General',
          icon: '🔥',
        ),
      );
    }

    // 3. Append Standard Daily Routine Tasks
    tasks.add(
      GeneratedTask(
        id: 'morning_feed_water',
        title: 'Morning Water & Feed',
        description: 'Clean and refill waterers. Provide fresh balanced duck feed. Ducks need water to swallow feed!',
        category: 'Morning',
        icon: '🌊',
      ),
    );

    tasks.add(
      GeneratedTask(
        id: 'collect_eggs',
        title: 'Collect Fresh Eggs',
        description: 'Check nesting boxes and clean any dirty eggs. Note laying activity.',
        category: 'Morning',
        icon: '🍳',
      ),
    );

    tasks.add(
      GeneratedTask(
        id: 'evening_lockdown',
        title: 'Predator Coop Lockdown',
        description: 'Secure all coops. Count heads and verify that every duck is safely locked inside.',
        category: 'Evening',
        icon: '🔒',
      ),
    );

    return tasks;
  }
}
