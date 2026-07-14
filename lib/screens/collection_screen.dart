// lib/screens/collection_screen.dart
//
// Replaces both the old home_screen's card grid AND flock_directory_screen,
// which were two separate, drifting implementations of "browse my birds"
// (one even navigated to the Lineage Tree on tap instead of the profile).
// There is now exactly one browsing screen, and tapping a bird always goes
// to its profile.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bird.dart';
import '../repositories/bird_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/bird_trading_card.dart';
import '../widgets/state_views.dart';
import 'add_bird_screen.dart';
import 'animal_profile_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name';
  String _selectedCategory = 'All';
  String? _selectedSex;

  static const _categories = ['All', 'Avian', 'Pets', 'Livestock', 'Aquatic'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<BirdRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collection'),
        actions: [
          if (_selectedSex != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear extra filters',
              onPressed: () => setState(() => _selectedSex = null),
            ),
        ],
      ),
      body: StreamBuilder<List<Bird>>(
        stream: repo.watchMyBirds(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: 'Could not load your flock.\n${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LoadingView(message: 'Loading your flock…');
          }

          final allBirds = snapshot.data!;

          if (allBirds.isEmpty) {
            return EmptyStateView(
              title: 'No birds yet',
              subtitle: 'Add your first bird to start building your collection.',
              actionLabel: 'Add a bird',
              onAction: () => _openAddBird(context),
            );
          }

          var birds = List<Bird>.from(allBirds);

          if (_searchQuery.isNotEmpty) {
            birds = birds
                .where((b) =>
                    b.name.toLowerCase().contains(_searchQuery) ||
                    b.breed.toLowerCase().contains(_searchQuery))
                .toList();
          }

          if (_selectedCategory != 'All') {
            // Uses the actual `category` field on the model instead of
            // guessing from breed-name substrings.
            birds = birds.where((b) => b.category == _selectedCategory).toList();
          }

          if (_selectedSex != null) {
            birds = birds.where((b) => b.sex == _selectedSex).toList();
          }

          birds.sort((a, b) => _sortBy == 'name'
              ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
              : b.ageOrHatchDate.compareTo(a.ageOrHatchDate));

          return Column(
            children: [
              _buildFilterBar(allBirds),
              Expanded(
                child: birds.isEmpty
                    ? EmptyStateView(
                        emoji: '🔍',
                        title: 'No matches',
                        subtitle: 'Try a different search or filter.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: birds.length,
                        itemBuilder: (context, index) {
                          final bird = birds[index];
                          return BirdTradingCard(
                            bird: bird,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => AnimalProfileScreen(animal: bird)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddBird(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openAddBird(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddBirdScreen()));
  }

  Widget _buildFilterBar(List<Bird> allBirds) {
    final sexes = allBirds.map((b) => b.sex).where((s) => s.isNotEmpty).toSet().toList()..sort();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by name or breed…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._categories.map((cat) => _chip(
                      label: cat,
                      selected: _selectedCategory == cat,
                      onSelected: () => setState(() => _selectedCategory = cat),
                    )),
                if (sexes.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(width: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(vertical: 4)),
                  const SizedBox(width: AppSpacing.sm),
                  ...sexes.map((sex) => _chip(
                        label: sex,
                        selected: _selectedSex == sex,
                        onSelected: () => setState(() => _selectedSex = _selectedSex == sex ? null : sex),
                      )),
                ],
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: _sortBy == 'name' ? 'Sorted by name' : 'Sorted by newest',
                  icon: Icon(_sortBy == 'name' ? Icons.sort_by_alpha : Icons.schedule, size: 20),
                  onPressed: () => setState(() => _sortBy = _sortBy == 'name' ? 'age' : 'name'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onSelected}) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        selectedColor: AppColors.primarySurface,
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
