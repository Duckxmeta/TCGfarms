import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bird.dart';
import '../utils/trait_styles.dart';
import '../services/ai_appraiser_service.dart';
import '../services/grading_engine.dart';

class AddBirdScreen extends StatefulWidget {
  const AddBirdScreen({super.key});

  @override
  State<AddBirdScreen> createState() => _AddBirdScreenState();
}

class _AddBirdScreenState extends State<AddBirdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _crossBreedController = TextEditingController();
  
  String _selectedBreed = 'Avian';
  String _selectedPrimaryBreed = 'Pekin';
  String _selectedSex = 'Unknown';
  String _selectedOrigin = 'Hatched';
  DateTime _hatchDate = DateTime.now();
  final List<String> _selectedTraits = [];
  
  XFile? _pickedFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isScanning = false;
  String detectedBreed = '';

  final List<String> _breeds = ['Avian', 'Pets', 'Livestock', 'Aquatic'];
  final List<String> _primaryBreeds = [
    'Silver Appleyard',
    'Swedish Blue',
    'Pekin',
    'Khaki Campbell',
    'Cayuga',
    'Indian Runner',
    'Muscovy',
    'Call Duck',
    'Cross-Breed / Barnyard Mix'
  ];

  final List<String> _sexes = ['Male', 'Female', 'Unknown'];
  final List<String> _origins = ['Purchased', 'Rehomed', 'Hatched'];

  @override
  void dispose() {
    _nameController.dispose();
    _crossBreedController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _hatchDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 15)), // Birds can live up to 15 years
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _hatchDate) {
      setState(() {
        _hatchDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 75,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedFile = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _smartScanImage() async {
    if (_imageBytes == null) return;
    setState(() {
      _isScanning = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final appraiser = AIAppraiserService();
      final result = await appraiser.analyzeAnimalImage(_imageBytes!);

      if (result.containsKey('error') && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Smart Scan warning/info: ${result['error']}'),
            backgroundColor: Colors.amber.shade900,
          ),
        );
      }

      if (mounted) {
        setState(() {
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = result['suggestedArchetype'] ?? '';
          }
          
          detectedBreed = (result['detectedBreed'] ?? '').toLowerCase();
          if (detectedBreed.contains('duck') || 
              detectedBreed.contains('chicken') || 
              detectedBreed.contains('goose') || 
              detectedBreed.contains('geese') || 
              detectedBreed.contains('turkey') || 
              detectedBreed.contains('quail') ||
              detectedBreed.contains('avian')) {
            _selectedBreed = 'Avian';
          } else if (detectedBreed.contains('dog') || 
                     detectedBreed.contains('cat') || 
                     detectedBreed.contains('rabbit') || 
                     detectedBreed.contains('reptile') ||
                     detectedBreed.contains('pet')) {
            _selectedBreed = 'Pets';
          } else if (detectedBreed.contains('pig') || 
                     detectedBreed.contains('goat') || 
                     detectedBreed.contains('cow') || 
                     detectedBreed.contains('sheep') || 
                     detectedBreed.contains('donkey') ||
                     detectedBreed.contains('livestock')) {
            _selectedBreed = 'Livestock';
          } else if (detectedBreed.contains('fish') || 
                     detectedBreed.contains('shrimp') || 
                     detectedBreed.contains('aquaponic') ||
                     detectedBreed.contains('aquatic')) {
            _selectedBreed = 'Aquatic';
          } else {
            _selectedBreed = 'Avian';
          }

          // Match primary breed dropdown options
          String matched = '';
          for (final b in _primaryBreeds) {
            if (detectedBreed.contains(b.toLowerCase()) || b.toLowerCase().contains(detectedBreed)) {
              matched = b;
              break;
            }
          }
          if (matched.isNotEmpty) {
            _selectedPrimaryBreed = matched;
          } else {
            _selectedPrimaryBreed = 'Cross-Breed / Barnyard Mix';
            _crossBreedController.text = result['detectedBreed'] ?? '';
          }

          final List<String> traitsList = List<String>.from(result['notableTraits'] ?? []);
          _selectedTraits.clear();
          for (final trait in traitsList) {
            if (TraitStyles.traitsMap.keys.contains(trait)) {
              _selectedTraits.add(trait);
            }
          }

          final int ageInMonths = result['estimatedAge'] ?? 3;
          _hatchDate = DateTime.now().subtract(Duration(days: ageInMonths * 30));
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Smart Scan complete! Form fields pre-populated.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to analyze image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveBird() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to add animals to your collection.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final birdDocRef = FirebaseFirestore.instance.collection('animals').doc();
      final birdId = birdDocRef.id;
      String? photoUrl;

      // Upload image if selected
      if (_imageBytes != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/birds/$birdId.jpg');
        
        final uploadTask = storageRef.putData(
          _imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
        photoUrl = 'gs://${storageRef.bucket}/${storageRef.fullPath}';
      }

      final isCrested = _selectedTraits.contains('Crested');
      final isShowQuality = _selectedTraits.contains('Show Quality');
      final isHighProduction = _selectedTraits.contains('High Production');

      final aiMetrics = await GradingEngine.gradeAnimal(
        breed: _selectedPrimaryBreed,
        crossBreedDetails: _selectedPrimaryBreed == 'Cross-Breed / Barnyard Mix'
            ? _crossBreedController.text.trim()
            : '',
        birthDate: _hatchDate,
        isCrested: isCrested,
        isShowQuality: isShowQuality,
        isHighProduction: isHighProduction,
        originType: _selectedOrigin,
      );

      final newBird = Bird(
        id: birdId,
        name: _nameController.text.trim(),
        breed: _selectedPrimaryBreed,
        category: _selectedBreed,
        ageOrHatchDate: _hatchDate,
        sex: _selectedSex,
        originType: _selectedOrigin,
        photoUrl: photoUrl,
        uid: user.uid,
        ownerId: user.uid,
        serialNumber: 'Batch #${(DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}',
        flockGrade: (aiMetrics['psa_grade'] as num).toDouble(),
        geneticTraits: _selectedTraits.isEmpty ? const ['Flock Pioneer'] : List<String>.from(_selectedTraits),
        cardVariant: photoUrl != null ? 'Holo' : 'Standard',
        hardiness: aiMetrics['hardiness'] as int?,
        eggProduction: aiMetrics['egg_production'] as int?,
        rarityTier: aiMetrics['rarity_tier'] as String?,
        gradeNotes: aiMetrics['grade_notes'] as String?,
      );

      await birdDocRef.set(newBird.toFirestore());

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${newBird.name} to your collection!'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final isTimeout = e.toString().toLowerCase().contains('timeout');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTimeout ? 'Upload failed. Please check connection.' : 'Error saving card: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Collection Item'),
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
              // Image Picker UI
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceBottomSheet,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: Colors.teal.shade50,
                        backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                        child: _imageBytes == null
                            ? Icon(Icons.add_a_photo, size: 36, color: Colors.teal.shade700)
                            : null,
                      ),
                      if (_imageBytes != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.teal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _imageBytes == null ? 'Upload Profile Photo' : 'Change Profile Photo',
                  style: TextStyle(
                    color: Colors.teal.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_imageBytes != null) ...[
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _isScanning ? null : _smartScanImage,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                          )
                        : const Icon(Icons.psychology_outlined),
                    label: Text(_isScanning ? 'Analyzing Image...' : 'Smart Scan Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Animal Name',
                  hintText: 'e.g. Barnaby',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.drive_file_rename_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for this animal';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Deck Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBreed,
                decoration: const InputDecoration(
                  labelText: 'Category Deck',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                items: _breeds.map((breed) {
                  return DropdownMenuItem(
                    value: breed,
                    child: Text(breed),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedBreed = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Primary Breed Dropdown
              DropdownButtonFormField<String>(
                value: _selectedPrimaryBreed,
                decoration: const InputDecoration(
                  labelText: 'Primary Breed',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _primaryBreeds.map((breed) {
                  return DropdownMenuItem(
                    value: breed,
                    child: Text(breed),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPrimaryBreed = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Cross Breed Lineage Details (Visible only when Cross-Breed / Barnyard Mix is selected)
              if (_selectedPrimaryBreed == 'Cross-Breed / Barnyard Mix') ...[
                TextFormField(
                  controller: _crossBreedController,
                  decoration: const InputDecoration(
                    labelText: 'Cross-Breed Lineage Details (e.g., Khaki x Buff)',
                    hintText: 'e.g. Khaki x Buff',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.merge_type),
                  ),
                  validator: (value) {
                    if (_selectedPrimaryBreed == 'Cross-Breed / Barnyard Mix' && (value == null || value.trim().isEmpty)) {
                      return 'Please specify cross-breed lineage details';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Sex Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSex,
                decoration: const InputDecoration(
                  labelText: 'Sex',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wc),
                ),
                items: _sexes.map((sex) {
                  return DropdownMenuItem(
                    value: sex,
                    child: Text(sex),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSex = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Hatch Date / Age Picker
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Hatch Date / Birth Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(_hatchDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_month, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Origin Dropdown
              DropdownButtonFormField<String>(
                value: _selectedOrigin,
                decoration: const InputDecoration(
                  labelText: 'Origin Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.source),
                ),
                items: _origins.map((origin) {
                  return DropdownMenuItem(
                    value: origin,
                    child: Text(origin),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedOrigin = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Trait Badges Selector
              Text(
                'Genetic & Physical Traits',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TraitStyles.traitsMap.keys.map((trait) {
                  final isSelected = _selectedTraits.contains(trait);
                  final style = TraitStyles.getStyle(trait);
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          style.icon,
                          size: 14,
                          color: isSelected ? style.textColor : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trait,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? style.textColor : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: style.backgroundColor,
                    checkmarkColor: style.textColor,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTraits.add(trait);
                        } else {
                          _selectedTraits.remove(trait);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveBird,
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
                        'Save Animal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
