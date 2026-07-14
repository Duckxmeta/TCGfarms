// lib/services/grading_engine.dart

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/bird.dart';

class GradingEngine {
  /// Asynchronously appraises animal traits using Gemini 1.5 Flash against standard APA standards.
  static Future<Map<String, dynamic>> gradeAnimal({
    required String breed,
    required String crossBreedDetails,
    required DateTime birthDate,
    required bool isCrested,
    required bool isShowQuality,
    required bool isHighProduction,
    required String originType,
  }) async {
    const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
    
    final fallbackData = {
      'hardiness': 80,
      'egg_production': isHighProduction ? 95 : 75,
      'rarity_tier': isShowQuality ? 'Epic' : 'Rare',
      'psa_grade': isShowQuality ? 9.2 : 8.5,
      'grade_notes': 'Graded using default offline matrix logic.',
    };

    if (apiKey.isEmpty) {
      return fallbackData;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );

      final prompt = '''
You are a world-class animal appraiser and poultry expert specializing in the American Poultry Association (APA) standards.
Evaluate the following animal traits and calculate its TCG Farms collectible grade:
- Category/Breed: $breed
- Cross Breed Details: $crossBreedDetails
- Birth/Hatch Date: ${birthDate.toIso8601String()}
- Has Crested Trait: $isCrested
- Is Show Quality: $isShowQuality
- Is High Production: $isHighProduction
- Origin Type: $originType

Calculate the PSA grade (1.0 to 10.0) based on lineage purity and traits:
- Show Quality traits and highly pure heritage lines should push the score toward a 9.0+.
- Standard barnyard cross-breeds should maximize hybrid vigor hardiness, but their PSA score must settle into the Uncommon/Rare tiers.
- Deduct points for cross-breed genetic variance unless compensated by show quality traits.
- High hardiness and production yield improve the collectible value.

You MUST strictly enforce this classification matrix mapping the calculated "psa_grade" to the "rarity_tier":
- If "psa_grade" is >= 9.0, "rarity_tier" MUST be "Legendary" or "Epic".
- If "psa_grade" is between 7.0 and 8.9, "rarity_tier" MUST be "Rare".
- If "psa_grade" is between 4.0 and 6.9, "rarity_tier" MUST be "Uncommon".
- If "psa_grade" is < 4.0, "rarity_tier" MUST be "Common".

Return a JSON map containing EXACTLY the following keys:
- "hardiness": integer (1 to 100)
- "egg_production": integer (1 to 100)
- "rarity_tier": string (one of "Common", "Uncommon", "Rare", "Epic", "Legendary")
- "psa_grade": double (1.0 to 10.0)
- "grade_notes": string (brief 1-sentence analysis explaining the score)
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final String? jsonText = response.text;
      if (jsonText != null && jsonText.isNotEmpty) {
        final decoded = json.decode(jsonText) as Map<String, dynamic>;
        double psaGrade = (decoded['psa_grade'] as num?)?.toDouble() ?? 8.5;
        psaGrade = psaGrade.clamp(1.0, 10.0);

        String rarityTier = decoded['rarity_tier'] as String? ?? 'Common';
        if (psaGrade >= 9.0) {
          if (rarityTier != 'Legendary' && rarityTier != 'Epic') {
            rarityTier = 'Epic';
          }
        } else if (psaGrade >= 7.0) {
          rarityTier = 'Rare';
        } else if (psaGrade >= 4.0) {
          rarityTier = 'Uncommon';
        } else {
          rarityTier = 'Common';
        }

        return {
          'hardiness': decoded['hardiness'] as int? ?? 80,
          'egg_production': decoded['egg_production'] as int? ?? (isHighProduction ? 95 : 75),
          'rarity_tier': rarityTier,
          'psa_grade': psaGrade,
          'grade_notes': decoded['grade_notes'] as String? ?? 'Graded successfully.',
        };
      }
    } catch (e) {
      print('AI Grading Engine Error: $e');
    }

    return fallbackData;
  }

  /// Calculates a dynamic collector grade between 1.0 and 10.0 based on data metrics.
  static double calculateGrade(Bird bird) {
    if (bird.flockGrade > 0 && bird.flockGrade != 8.5) {
      return bird.flockGrade;
    }

    // 1. Production Consistency (35% -> max 3.5 points)
    double prodScore = 2.0; // Baseline
    
    // Standard layers/productive breeds get a bonus
    final breedLower = bird.breed.toLowerCase();
    if (breedLower.contains('pekin') || 
        breedLower.contains('chicken') || 
        breedLower.contains('campbell') || 
        breedLower.contains('standard')) {
      prodScore += 1.0;
    }
    
    // Mature age implies stable records/production history
    final ageInDays = DateTime.now().difference(bird.ageOrHatchDate).inDays;
    if (ageInDays > 180) {
      prodScore += 0.5; // Mature layer/breeder
    } else if (ageInDays > 60) {
      prodScore += 0.2; // Intermediate
    }
    prodScore = prodScore.clamp(0.0, 3.5);

    // 2. Proof of Work / Data Depth (25% -> max 2.5 points)
    double depthScore = 0.5; // Baseline
    
    if (bird.photoUrl != null && bird.photoUrl!.isNotEmpty) {
      depthScore += 1.0; // Physical photo verification
    }
    if (bird.geneticTraits.isNotEmpty) {
      depthScore += 0.5; // Genetic records present
    }
    if (bird.serialNumber != 'N/A') {
      depthScore += 0.5; // Validated registry tag
    }
    depthScore = depthScore.clamp(0.0, 2.5);

    // 3. Lineage Depth (20% -> max 2.0 points)
    double lineageScore = 0.0;
    if (bird.sireId != null && bird.sireId!.isNotEmpty) {
      lineageScore += 1.0; // Father tracked
    }
    if (bird.damId != null && bird.damId!.isNotEmpty) {
      lineageScore += 1.0; // Mother tracked
    }
    lineageScore = lineageScore.clamp(0.0, 2.0);

    // 4. Health Stability (20% -> max 2.0 points)
    double healthScore = 2.0; // Default pristine health
    
    if (bird.originType == 'Rehomed') {
      healthScore -= 0.5; // Historical recovery penalty
    }
    final nameLower = bird.name.toLowerCase();
    if (nameLower.contains('rescue') || nameLower.contains('sick') || nameLower.contains('injured')) {
      healthScore -= 1.0; // Active medical notes
    }
    healthScore = healthScore.clamp(0.0, 2.0);

    // Combine parameters
    final double rawTotal = prodScore + depthScore + lineageScore + healthScore;
    
    // Round cleanly to 1 decimal place (clamp between 1.0 and 10.0)
    return (rawTotal.clamp(1.0, 10.0) * 10).round() / 10;
  }

  /// Maps the double grade value back to the corresponding TCG grade tier label.
  static String getTierLabel(double grade) {
    if (grade >= 9.0) {
      return 'Pristine Mint';
    } else if (grade >= 8.0) {
      return 'Near Mint';
    } else if (grade >= 7.0) {
      return 'Excellent';
    } else {
      return 'Good';
    }
  }

  /// Calculates realistic collectible pricing value based on rarity tier and PSA grade.
  static double calculateValue(String? rarityTier, double psaGrade) {
    double baseValue;
    switch (rarityTier) {
      case 'Legendary':
      case 'Epic':
        baseValue = 50.0;
        break;
      case 'Rare':
        baseValue = 30.0;
        break;
      case 'Uncommon':
        baseValue = 20.0;
        break;
      case 'Common':
      default:
        baseValue = 15.0;
        break;
    }
    return baseValue * (psaGrade / 10.0);
  }
}
