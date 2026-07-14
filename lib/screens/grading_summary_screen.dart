// lib/screens/grading_summary_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/bird.dart';
import '../services/grading_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/storage_image.dart';

class GradingSummaryScreen extends StatelessWidget {
  final Bird bird;
  final double latitude;
  final double longitude;
  final Uint8List? imageBytes;

  const GradingSummaryScreen({
    super.key,
    required this.bird,
    required this.latitude,
    required this.longitude,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    final String tierLabel = GradingEngine.getTierLabel(bird.flockGrade);
    final Color rarityColor = AppColors.rarityColor(bird.rarityTier);
    final double value = GradingEngine.calculateValue(bird.rarityTier, bird.flockGrade);

    return Scaffold(
      backgroundColor: Colors.grey[900], // Premium dark mode grading summary
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Header
              Text(
                'NEW CARD MINTED!',
                textAlign: TextAlign.center,
                style: AppTextStyles.brand.copyWith(
                  color: AppColors.primaryLight,
                  fontSize: 28,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Husbandry AI Appraised & PSA Graded',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Visual TCG Card Frame Render
              Center(
                child: Container(
                  width: 250,
                  height: 360,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rarityColor, width: 4.5),
                    boxShadow: [
                      BoxShadow(
                        color: rarityColor.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Area
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (imageBytes != null)
                              Image.memory(imageBytes!, fit: BoxFit.cover)
                            else if (bird.photoUrl != null && bird.photoUrl!.isNotEmpty)
                              StorageImage(
                                photoUrl: bird.photoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: const Center(
                                  child: Icon(Icons.pets, color: AppColors.primaryLight, size: 48),
                                ),
                              )
                            else
                              Container(
                                color: Colors.grey[850],
                                child: const Center(
                                  child: Text('🐣', style: TextStyle(fontSize: 64)),
                                ),
                              ),
                            
                            // PSA Grade Badge
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber, width: 1.5),
                                ),
                                child: Text(
                                  'PSA ${bird.flockGrade.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),

                            // Rarity Tier Badge
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: rarityColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  bird.rarityTier?.toUpperCase() ?? 'COMMON',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Metadata Info Bar
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    bird.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Lvl ${bird.level}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bird.breed,
                              style: TextStyle(
                                color: rarityColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Specifications Table
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _buildSpecRow('Rarity Tier', bird.rarityTier ?? 'Common', valueColor: rarityColor),
                    const Divider(color: Colors.white10),
                    _buildSpecRow('PSA Condition', '$tierLabel (${bird.flockGrade.toStringAsFixed(1)}/10)'),
                    const Divider(color: Colors.white10),
                    _buildSpecRow('Est. Market Value', '\$${value.toStringAsFixed(2)}', valueColor: Colors.greenAccent),
                    const Divider(color: Colors.white10),
                    _buildSpecRow('Discovery Mode', bird.discoveryType),
                    const Divider(color: Colors.white10),
                    _buildSpecRow('Hatch Trait Markers', bird.geneticTraits.join(', ')),
                    const Divider(color: Colors.white10),
                    _buildSpecRow('Coordinates', 'Lat: ${latitude.toStringAsFixed(5)}, Lon: ${longitude.toStringAsFixed(5)}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Care/Husbandry Appraisal Notes
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.description_outlined, color: AppColors.primaryLight, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'AI Appraisal & Husbandry Notes',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bird.gradeNotes ?? 'No appraisal notes available for this encounter.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Claim Card Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Navigate back to the home/binder screen (pop back to root)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  'CLAIM & ADD TO BINDER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
