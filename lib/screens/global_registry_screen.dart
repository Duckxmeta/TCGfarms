// lib/screens/global_registry_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bird.dart';
import '../repositories/bird_repository.dart';
import '../services/grading_engine.dart';
import '../widgets/storage_image.dart';
import '../utils/trait_styles.dart';
import 'animal_profile_screen.dart';

class GlobalRegistryScreen extends StatefulWidget {
  const GlobalRegistryScreen({super.key});

  @override
  State<GlobalRegistryScreen> createState() => _GlobalRegistryScreenState();
}

class _GlobalRegistryScreenState extends State<GlobalRegistryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDeck = 'All';
  final List<String> _decks = ['All', 'Avian', 'Pets', 'Livestock', 'Aquatic'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Top branding & Search banner
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public, color: Colors.teal.shade800, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'GLOBAL REGISTRY',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 1.2,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Discover and inspect custom animal cards minted by collectors worldwide',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search card collections by name...',
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _decks.length,
                      itemBuilder: (context, index) {
                        final deck = _decks[index];
                        final isSelected = _selectedDeck == deck;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(
                              deck == 'All' ? 'All Decks' : '$deck Deck',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.teal.shade800,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.teal,
                            backgroundColor: Colors.teal.shade50,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? Colors.teal : Colors.teal.shade100,
                              ),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedDeck = deck;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Registry Stream grid
            Expanded(
              child: StreamBuilder<List<Bird>>(
                stream: context.watch<BirdRepository>().watchRegistry(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Error loading global registry feed: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.teal));
                  }

                  final allAnimals = snapshot.data!;

                  // Client side filter matching search queries. Deck matching
                  // now uses the bird's actual `category` field instead of
                  // guessing from breed-name substrings.
                  final filteredAnimals = allAnimals.where((animal) {
                    final matchesSearch = _searchQuery.isEmpty ||
                        animal.name.toLowerCase().contains(_searchQuery) ||
                        animal.breed.toLowerCase().contains(_searchQuery);

                    final matchesDeck = _selectedDeck == 'All' || animal.category == _selectedDeck;

                    return matchesSearch && matchesDeck;
                  }).toList();

                  if (filteredAnimals.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_outlined, size: 64, color: Colors.teal.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'No registry cards found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try altering your search text or deck category filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400.0,
                      mainAxisSpacing: 12.0,
                      crossAxisSpacing: 12.0,
                      childAspectRatio: 2.7,
                    ),
                    itemCount: filteredAnimals.length,
                    itemBuilder: (context, index) {
                      final animal = filteredAnimals[index];
                      return _buildGlobalRegistryCard(context, animal);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalRegistryCard(BuildContext context, Bird animal) {
    final int hash = animal.breed.hashCode;
    final double hue = (hash.abs() % 360).toDouble();
    final Color tagBgColor = HSLColor.fromAHSL(0.08, hue, 0.70, 0.40).toColor();
    final Color tagTextColor = HSLColor.fromAHSL(1.0, hue, 0.85, 0.30).toColor();

    final sexColor = animal.sex == 'Male'
        ? Colors.blue.shade600
        : animal.sex == 'Female'
            ? Colors.pink.shade600
            : Colors.grey.shade600;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AnimalProfileScreen(animal: animal),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              // Photo Frame
              Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: animal.photoUrl != null && animal.photoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: StorageImage(
                              photoUrl: animal.photoUrl!,
                              fit: BoxFit.cover,
                              errorWidget: const Center(
                                child: Icon(Icons.pets, color: Colors.teal, size: 28),
                              ),
                            ),
                          )
                        : const Center(
                            child: Text(
                              '🐣',
                              style: TextStyle(fontSize: 28),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black87, width: 1.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        GradingEngine.calculateGrade(animal).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Animal Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      animal.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Breed Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        animal.geneticTraits.isNotEmpty ? animal.geneticTraits[0] : animal.breed,
                        style: TextStyle(
                          color: tagTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Age / Sex
                    Row(
                      children: [
                        Text(
                          'Age: ${_calculateAgeText(animal.ageOrHatchDate)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          animal.sex == 'Male'
                              ? Icons.male
                              : animal.sex == 'Female'
                                  ? Icons.female
                                  : Icons.question_mark,
                          size: 11,
                          color: sexColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          animal.sex,
                          style: TextStyle(color: sexColor, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // Arrow forward chevron
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateAgeText(DateTime birthDate) {
    final difference = DateTime.now().difference(birthDate);
    final days = difference.inDays;
    final months = (days / 30.4).floor();
    if (months < 1) {
      return '$days d';
    }
    if (months < 12) {
      return '$months m';
    }
    final years = (months / 12).floor();
    final remainingMonths = months % 12;
    if (remainingMonths == 0) {
      return '$years y';
    }
    return '$years y $remainingMonths m';
  }
}
