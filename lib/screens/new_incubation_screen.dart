import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/incubation_calculator.dart';
import '../models/incubation_batch.dart';

class NewIncubationScreen extends StatefulWidget {
  const NewIncubationScreen({super.key});

  @override
  State<NewIncubationScreen> createState() => _NewIncubationScreenState();
}

class _NewIncubationScreenState extends State<NewIncubationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchNameController = TextEditingController();
  
  String _selectedBreedKey = 'standard_duck';
  DateTime _setDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _batchNameController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _setDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              primary: Colors.teal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _setDate) {
      setState(() {
        _setDate = picked;
      });
    }
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to save incubation batches.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final milestones = IncubationCalculator.calculateMilestones(_setDate, _selectedBreedKey);
      final template = IncubationCalculator.speciesTemplates[_selectedBreedKey]!;

      // Create a reference with an auto-generated ID
      final docRef = FirebaseFirestore.instance.collection('incubation_batches').doc();

      final newBatch = IncubationBatch(
        id: docRef.id,
        batchName: _batchNameController.text.trim(),
        breedTemplateId: _selectedBreedKey,
        startDate: _setDate,
        projectedHatchDate: milestones['hatchDate']!,
        lockdownDate: milestones['lockdownDate']!,
        uid: user.uid,
      );

      await docRef.set(newBatch.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully started "${newBatch.batchName}"!'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save batch: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = IncubationCalculator.speciesTemplates[_selectedBreedKey]!;
    final milestones = IncubationCalculator.calculateMilestones(_setDate, _selectedBreedKey);
    final lockdownDate = milestones['lockdownDate']!;
    final hatchDate = milestones['hatchDate']!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Batch'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header description
              Card(
                color: Colors.teal.withOpacity(0.05),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.teal.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.egg_outlined, color: Colors.teal.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fill in the details below to track your hatch and view calculated milestones automatically.',
                          style: TextStyle(
                            color: Colors.teal.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Batch Name
              TextFormField(
                controller: _batchNameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name',
                  hintText: 'e.g., Spring Pekin Batch A',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.drive_file_rename_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for this batch';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Breed Selector
              DropdownButtonFormField<String>(
                value: _selectedBreedKey,
                decoration: const InputDecoration(
                  labelText: 'Species / Breed Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                items: IncubationCalculator.speciesTemplates.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value.breedName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedBreedKey = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Set Date Picker
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Set Date (Start Date)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(_setDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Milestones Preview Area
              Text(
                'Calculated Milestones',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildMilestoneRow(
                        context,
                        title: 'Lockdown Date',
                        date: _formatDate(lockdownDate),
                        subtitle: 'Move eggs to hatcher (Day ${template.lockdownDay})',
                        icon: Icons.lock_clock,
                        iconColor: Colors.orange,
                      ),
                      const Divider(height: 24),
                      _buildMilestoneRow(
                        context,
                        title: 'Projected Hatch Date',
                        date: _formatDate(hatchDate),
                        subtitle: 'Expected duckling arrival! (Day ${template.totalDays})',
                        icon: Icons.child_care,
                        iconColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
              if (template.specialInstructions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Special Instructions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.teal.withOpacity(0.02),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.teal.withOpacity(0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: template.specialInstructions.map((instruction) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Colors.teal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  instruction,
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveBatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Batch',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneRow(
    BuildContext context, {
    required String title,
    required String date,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          date,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.teal.shade800,
          ),
        ),
      ],
    );
  }
}
