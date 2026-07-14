// lib/screens/animal_profile_screen.dart

import 'package:flutter/material.dart';
import '../models/bird.dart';
import '../services/grading_engine.dart';
import '../services/card_canvas_service.dart';
import '../utils/trait_styles.dart';
import 'lineage_tree_screen.dart';
import '../widgets/storage_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

class AnimalProfileScreen extends StatefulWidget {
  final Bird animal;

  const AnimalProfileScreen({super.key, required this.animal});

  @override
  State<AnimalProfileScreen> createState() => _AnimalProfileScreenState();
}

class _AnimalProfileScreenState extends State<AnimalProfileScreen> {
  bool _isSharing = false;

  String _calculateAgeText(DateTime birthDate) {
    final difference = DateTime.now().difference(birthDate);
    final days = difference.inDays;
    if (days < 30) {
      return '$days days';
    }
    final months = (days / 30).floor();
    if (months < 12) {
      return '$months mos';
    }
    final years = (months / 12).floor();
    final remainingMonths = months % 12;
    if (remainingMonths == 0) {
      return '$years yrs';
    }
    return '$years y $remainingMonths m';
  }

  @override
  Widget build(BuildContext context) {
    final animal = widget.animal;
    final int hash = animal.breed.hashCode;
    final double hue = (hash.abs() % 360).toDouble();
    final Color cardAccentColor = HSLColor.fromAHSL(1.0, hue, 0.75, 0.35).toColor();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(animal.name),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (animal.ownerId == FirebaseAuth.instance.currentUser?.uid)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Card',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Card'),
                    content: Text('Are you sure you want to permanently delete ${animal.name}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await DatabaseService.deleteAnimalCard(animal.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Permanently removed ${animal.name} from collection.'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete card: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSharing
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Export Trading Card',
                    onPressed: () async {
                      setState(() {
                        _isSharing = true;
                      });
                      try {
                        await CardCanvasService.exportAndShareCard(animal);
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSharing = false;
                          });
                        }
                      }
                    },
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Premium Trading Card Header Box
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: animal.photoUrl != null && animal.photoUrl!.isNotEmpty
                              ? StorageImage(
                                  photoUrl: animal.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: const Center(child: Text('🐾', style: TextStyle(fontSize: 42))),
                                )
                              : const Center(child: Text('🐾', style: TextStyle(fontSize: 42))),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black87, width: 1.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              GradingEngine.calculateGrade(animal).toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            animal.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              fontFamily: 'Outfit',
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // XP Progress Bar
                          Row(
                            children: [
                              Text(
                                'LVL ${animal.level}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: (animal.xp % 100) / 100.0,
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.teal,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${animal.xp % 100}/100 XP',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cardAccentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  animal.geneticTraits.isNotEmpty ? animal.geneticTraits[0] : animal.breed,
                                  style: TextStyle(
                                    color: cardAccentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  animal.cardVariant,
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: animal.discoveryType == 'Resident'
                                      ? Colors.blue.withValues(alpha: 0.08)
                                      : Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      animal.discoveryType == 'Resident'
                                          ? Icons.home_outlined
                                          : Icons.explore_outlined,
                                      size: 12,
                                      color: animal.discoveryType == 'Resident'
                                          ? Colors.blue
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      animal.discoveryType,
                                      style: TextStyle(
                                        color: animal.discoveryType == 'Resident'
                                            ? Colors.blue
                                            : Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Serial: ${animal.serialNumber}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Age: ${_calculateAgeText(animal.ageOrHatchDate)}  |  Sex: ${animal.sex}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Details List
            Text(
              'Binder Collection Details',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.grey[800],
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.style, color: Colors.teal),
                    title: const Text('Card Rarity Variant'),
                    subtitle: Text(animal.cardVariant),
                    trailing: Text(
                      animal.rarityTier ?? 'Common',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getRarityColor(animal.rarityTier),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.qr_code, color: Colors.teal),
                    title: const Text('Serial Production ID'),
                    subtitle: Text(animal.serialNumber),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user, color: Colors.teal),
                    title: const Text('Dynamic Quality Grade'),
                    subtitle: const Text('Calculated dynamically from production history metrics'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${GradingEngine.calculateGrade(animal)} / 10.0 (${GradingEngine.getTierLabel(GradingEngine.calculateGrade(animal))})',
                        style: TextStyle(
                          color: Colors.teal.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Genetics Trait Pool Section
            Text(
              'Genetic Trait Pool',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.grey[800],
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: animal.geneticTraits.isEmpty
                    ? const Text(
                        'No genetic traits documented for this card yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: animal.geneticTraits.map((trait) {
                          final style = TraitStyles.getStyle(trait);
                          return Chip(
                            avatar: Icon(style.icon, size: 14, color: style.textColor),
                            label: Text(
                              trait,
                              style: TextStyle(
                                fontSize: 12,
                                color: style.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: style.backgroundColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          );
                        }).toList(),
                      ),
              ),
            ),
            if (animal.hardiness != null || animal.eggProduction != null || animal.rarityTier != null || animal.gradeNotes != null) ...[
              const SizedBox(height: 24),
              Text(
                'AI Appraisal Statistics',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.grey[800],
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (animal.rarityTier != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.star, color: Colors.amber),
                          title: const Text('Rarity Classification'),
                          subtitle: Text(animal.rarityTier!),
                        ),
                      if (animal.hardiness != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Hardiness Rating: ${animal.hardiness}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: animal.hardiness! / 100.0,
                          backgroundColor: Colors.grey[200],
                          color: Colors.orange,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                      if (animal.eggProduction != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Egg Production Rating: ${animal.eggProduction}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: animal.eggProduction! / 100.0,
                          backgroundColor: Colors.grey[200],
                          color: Colors.blue,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                      if (animal.gradeNotes != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Appraisal Remarks:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          animal.gradeNotes!,
                          style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Bottom Navigation/Action Buttons
            ElevatedButton.icon(
              onPressed: _isSharing
                  ? null
                  : () async {
                      setState(() {
                        _isSharing = true;
                      });
                      try {
                        await CardCanvasService.exportAndShareCard(animal);
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSharing = false;
                          });
                        }
                      }
                    },
              icon: const Icon(Icons.share),
              label: const Text('Share Graphic Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LineageTreeScreen(startBirdId: animal.id),
                  ),
                );
              },
              icon: const Icon(Icons.account_tree),
              label: const Text('View Lineage Pedigree Tree'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(String? rarity) {
    switch (rarity) {
      case 'Legendary':
        return Colors.deepOrange;
      case 'Epic':
        return Colors.purple;
      case 'Rare':
        return Colors.teal;
      case 'Uncommon':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
