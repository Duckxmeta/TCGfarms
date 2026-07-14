// lib/services/incubation_calculator.dart

class BreedTemplate {
  final String breedName;
  final int totalDays;
  final int lockdownDay;
  final double standardHumidity;
  final double lockdownHumidity;
  final List<String> specialInstructions;

  const BreedTemplate({
    required this.breedName,
    required this.totalDays,
    required this.lockdownDay,
    required this.standardHumidity,
    required this.lockdownHumidity,
    this.specialInstructions = const [],
  });
}

class IncubationCalculator {
  // Pre-loaded templates for rookie bird owners
  static const Map<String, BreedTemplate> speciesTemplates = {
    'standard_duck': BreedTemplate(
      breedName: 'Standard Duck (Pekin, Khaki Campbell, Runner, etc.)',
      totalDays: 28,
      lockdownDay: 25,
      standardHumidity: 45.0,
      lockdownHumidity: 70.0,
      specialInstructions: [
        'Days 1-25: Maintain incubator temperature at 99.5°F (37.5°C).',
        'Turn eggs at least 3-5 times daily until lockdown (Day 25).'
      ],
    ),
    'muscovy_duck': BreedTemplate(
      breedName: 'Muscovy Duck',
      totalDays: 35,
      lockdownDay: 31,
      standardHumidity: 45.0,
      lockdownHumidity: 70.0,
      specialInstructions: [
        'Note: Muscovy ducks have a longer incubation period of 35 days.',
        'Turn eggs daily until lockdown on Day 31.'
      ],
    ),
    'chicken': BreedTemplate(
      breedName: 'Chicken',
      totalDays: 21,
      lockdownDay: 18,
      standardHumidity: 45.0,
      lockdownHumidity: 65.0,
      specialInstructions: [
        'Days 1-18: Maintain incubator temperature at 99.5°F (37.5°C).',
        'Stop turning and initiate lockdown on Day 18.'
      ],
    ),
    'turkey': BreedTemplate(
      breedName: 'Turkey',
      totalDays: 28,
      lockdownDay: 25,
      standardHumidity: 50.0,
      lockdownHumidity: 70.0,
      specialInstructions: [
        'Days 1-25: Maintain incubator temperature at 99.5°F (37.5°C).',
        'Lockdown on Day 25. Ensure adequate ventilation.'
      ],
    ),
    'goose': BreedTemplate(
      breedName: 'Goose',
      totalDays: 30,
      lockdownDay: 27,
      standardHumidity: 50.0,
      lockdownHumidity: 75.0,
      specialInstructions: [
        'Days 4-26: Lightly mist eggs with lukewarm water and let cool for 15 minutes daily to simulate the mother goose leaving the nest.',
        'Lockdown on Day 27. Goose eggs require high humidity (75%) during hatch.'
      ],
    ),
  };

  /// Calculates the milestone dates for a new incubation batch based on start date and breed type
  static Map<String, DateTime> calculateMilestones(DateTime startDate, String breedKey) {
    final template = speciesTemplates[breedKey] ?? speciesTemplates['standard_duck']!;
    
    final lockdownDate = startDate.add(Duration(days: template.lockdownDay));
    final hatchDate = startDate.add(Duration(days: template.totalDays));

    return {
      'lockdownDate': lockdownDate,
      'hatchDate': hatchDate,
    };
  }
}
