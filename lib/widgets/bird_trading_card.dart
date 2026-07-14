// lib/widgets/bird_trading_card.dart
//
// Extracted from the old home_screen._buildVerticalTradingCard, which was
// duplicated (with drift) between the home feed and the flock directory.
// Now there's exactly one card widget every "browse birds" screen uses.

import 'package:flutter/material.dart';
import '../models/bird.dart';
import '../services/grading_engine.dart';
import '../theme/app_theme.dart';
import 'storage_image.dart';

String formatAge(DateTime birthDate) {
  final days = DateTime.now().difference(birthDate).inDays;
  if (days < 0) return 'Not hatched';
  if (days < 30) return '$days d';
  final months = (days / 30).floor();
  if (months < 12) return '$months mo';
  final years = (months / 12).floor();
  final remainingMonths = months % 12;
  return remainingMonths == 0 ? '$years yr' : '$years y $remainingMonths m';
}

class BirdTradingCard extends StatelessWidget {
  final Bird bird;
  final VoidCallback onTap;

  const BirdTradingCard({super.key, required this.bird, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final int hash = bird.breed.hashCode;
    final double hue = (hash.abs() % 360).toDouble();
    final Color tagBgColor = HSLColor.fromAHSL(0.08, hue, 0.70, 0.40).toColor();
    final Color tagTextColor = HSLColor.fromAHSL(1.0, hue, 0.85, 0.30).toColor();

    final sexColor = bird.sex == 'Male'
        ? Colors.blue.shade600
        : bird.sex == 'Female'
            ? Colors.pink.shade600
            : Colors.grey.shade600;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: (bird.photoUrl != null && bird.photoUrl!.isNotEmpty)
                        ? StorageImage(
                            photoUrl: bird.photoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: const Center(
                              child: Icon(Icons.pets, color: AppColors.primary, size: 36),
                            ),
                          )
                        : Container(
                            color: AppColors.primarySurface,
                            child: const Center(
                              child: Text('🐣', style: TextStyle(fontSize: 48)),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _Badge(
                      text: GradingEngine.calculateGrade(bird).toStringAsFixed(1),
                      background: Colors.white,
                      textColor: Colors.black87,
                      bordered: true,
                    ),
                  ),
                  if (bird.cardVariant != 'Standard')
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(
                        text: bird.cardVariant.toUpperCase(),
                        background: Colors.deepOrange,
                        textColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bird.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        bird.sex == 'Male'
                            ? Icons.male
                            : bird.sex == 'Female'
                                ? Icons.female
                                : Icons.question_mark,
                        size: 12,
                        color: sexColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagBgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bird.geneticTraits.isNotEmpty ? bird.geneticTraits[0] : bird.breed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tagTextColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Age: ${formatAge(bird.ageOrHatchDate)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color background;
  final Color textColor;
  final bool bordered;

  const _Badge({
    required this.text,
    required this.background,
    required this.textColor,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        border: bordered ? Border.all(color: Colors.black87, width: 1.2) : null,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(1, 1))],
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textColor),
      ),
    );
  }
}
