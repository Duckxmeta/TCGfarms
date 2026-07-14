// lib/services/ai_appraiser_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIAppraiserService {
  final GenerativeModel _model;

  AIAppraiserService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
        );

  /// Analyzes an animal image and returns structured husbandry appraisal metadata.
  Future<Map<String, dynamic>> analyzeAnimalImage(List<int> imageBytes) async {
    try {
      const prompt = 'You are a world-class animal husbandry expert. Analyze this image of an animal (typically a duck, chicken, goose, or turkey) and return a clean, structured JSON format containing exactly the following keys: \n'
          '- "detectedBreed": The exact breed or species name (e.g., "Pekin Duck", "Muscovy Duck", "Swedish Blue", "Runner Duck", "Khaki Campbell", "Chicken", "Goose", "Turkey")\n'
          '- "suggestedArchetype": A creative trading card archetype name matching their visual style (e.g., "Aqua Commander", "Brooder Elite", "Emerald Champion", "Feathered Guardian")\n'
          '- "estimatedAge": An estimated age in months as an integer number (e.g., 3)\n'
          '- "notableTraits": An array of strings representing notable physical or genetic traits. Choose only from this exact list: ["Crested", "Silver Appleyard", "Swedish Blue", "High Production", "Show Quality"]\n'
          '- "husbandryInstructionTemplate": A short paragraph recommending care instructions based on the breed and estimated age.\n\n'
          'Return ONLY the raw JSON string. Do not include markdown code block formatting (such as ```json) or any explanation text.';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', Uint8List.fromList(imageBytes)),
        ]),
      ];

      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null) {
        throw Exception('AI returned an empty response.');
      }

      // Stripping potential markdown wrapping
      String cleanJson = responseText.trim();
      if (cleanJson.startsWith('```')) {
        final lines = cleanJson.split('\n');
        if (lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.startsWith('```')) {
          lines.removeLast();
        }
        cleanJson = lines.join('\n').trim();
      }

      final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
      
      return {
        'detectedBreed': parsed['detectedBreed']?.toString() ?? 'Other',
        'suggestedArchetype': parsed['suggestedArchetype']?.toString() ?? 'Genesis',
        'estimatedAge': int.tryParse(parsed['estimatedAge']?.toString() ?? '3') ?? 3,
        'notableTraits': List<String>.from(parsed['notableTraits'] as List<dynamic>? ?? []),
        'husbandryInstructionTemplate': parsed['husbandryInstructionTemplate']?.toString() ?? '',
      };
    } catch (e) {
      // Graceful fallback structure
      return {
        'detectedBreed': 'Other',
        'suggestedArchetype': 'Genesis',
        'estimatedAge': 3,
        'notableTraits': <String>[],
        'husbandryInstructionTemplate': 'Detailed instructions could not be generated at this time.',
        'error': e.toString(),
      };
    }
  }
}
