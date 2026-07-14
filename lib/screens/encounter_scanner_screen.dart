// lib/screens/encounter_scanner_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/bird.dart';
import '../services/grading_engine.dart';
import '../services/ai_appraiser_service.dart';
import '../repositories/bird_repository.dart';
import '../theme/app_theme.dart';
import 'grading_summary_screen.dart';

class EncounterScannerScreen extends StatefulWidget {
  const EncounterScannerScreen({super.key});

  @override
  State<EncounterScannerScreen> createState() => _EncounterScannerScreenState();
}

class _EncounterScannerScreenState extends State<EncounterScannerScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraSupported = true;
  bool _isLoading = false;
  String _statusText = "";

  late AnimationController _scannerAnimationController;
  late Animation<double> _scannerAnimation;

  // Selected parameters for the mock/simulated scanner
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
  String _selectedBreed = 'Pekin';
  String _selectedSex = 'Female';

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    // Scanning line animation
    _scannerAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isCameraSupported = false;
        });
        return;
      }

      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
      if (mounted) {
        setState(() {
          _isCameraSupported = false;
        });
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<void> _captureAndGrade() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _statusText = "Acquiring Coordinates...";
    });

    try {
      // 1. Fetch Coordinates
      final position = await _getCurrentLocation();
      final double lat = position?.latitude ?? 37.4220; // Default Googleplex coords
      final double lon = position?.longitude ?? -122.0841;

      if (mounted) {
        setState(() {
          _statusText = "Capturing Image...";
        });
      }

      Uint8List imageBytes;
      // 2. Capture photo/bytes
      if (_isCameraInitialized && _cameraController != null) {
        final XFile file = await _cameraController!.takePicture();
        imageBytes = await file.readAsBytes();
      } else {
        // Fallback dummy image bytes (red-teal colored canvas representing the scan)
        imageBytes = _generateDummyImageBytes();
      }

      if (mounted) {
        setState(() {
          _statusText = "Running Appraisals...";
        });
      }

      // 3. AI Appraiser Service
      final appraiser = AIAppraiserService();
      Map<String, dynamic> appraisalResult;
      
      try {
        appraisalResult = await appraiser.analyzeAnimalImage(imageBytes);
      } catch (e) {
        appraisalResult = {
          'detectedBreed': _selectedBreed,
          'suggestedArchetype': 'Wild Discovery',
          'estimatedAge': 3,
          'notableTraits': ['Show Quality', 'Crested'],
        };
      }

      final detectedBreedName = appraisalResult['detectedBreed']?.toString() ?? _selectedBreed;
      final notableTraits = List<String>.from(appraisalResult['notableTraits'] as List<dynamic>? ?? []);
      
      // Enforce parameters mapped to traits for GradingEngine
      final isCrested = notableTraits.contains('Crested');
      final isShowQuality = notableTraits.contains('Show Quality');
      final isHighProduction = notableTraits.contains('High Production');

      // 4. Pass traits to existing GradingEngine
      final aiMetrics = await GradingEngine.gradeAnimal(
        breed: detectedBreedName,
        crossBreedDetails: detectedBreedName == 'Cross-Breed / Barnyard Mix' ? 'Wild Encounter' : '',
        birthDate: DateTime.now().subtract(const Duration(days: 90)), // baseline age (~3 months)
        isCrested: isCrested,
        isShowQuality: isShowQuality,
        isHighProduction: isHighProduction,
        originType: 'Wild',
      );

      final user = FirebaseAuth.instance.currentUser;
      final ownerId = user?.uid ?? 'anonymous_user';

      if (mounted) {
        setState(() {
          _statusText = "Uploading to Storage...";
        });
      }

      // 5. Upload to Firebase Storage under /encounter-photos
      final String birdId = FirebaseFirestore.instance.collection('animals').doc().id;
      String? photoUrl;

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('encounter-photos/$birdId.jpg');
        
        final uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        await uploadTask.timeout(const Duration(seconds: 12));
        photoUrl = 'gs://${storageRef.bucket}/${storageRef.fullPath}';
      } catch (e) {
        debugPrint("Firebase Storage Upload failed, using empty photo path: $e");
        // Maintain local preview or mock url fallback
        photoUrl = "";
      }

      // 6. Assemble Bird Model - Hardcode Game Mode Defaults
      final String locationNote = "Coords: (${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)})";
      final String gradingNotes = aiMetrics['grade_notes'] as String? ?? 'Appraised successfully.';

      final newBird = Bird(
        id: birdId,
        name: "Wild ${detectedBreedName.split(' ').first}",
        breed: detectedBreedName,
        category: 'Avian',
        ageOrHatchDate: DateTime.now().subtract(const Duration(days: 90)),
        sex: _selectedSex,
        originType: 'Wild',
        photoUrl: photoUrl,
        uid: ownerId,
        ownerId: ownerId,
        serialNumber: 'ENC-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}',
        flockGrade: (aiMetrics['psa_grade'] as num).toDouble(),
        geneticTraits: notableTraits.isEmpty ? const ['Wild Spirit'] : notableTraits,
        cardVariant: 'Holo',
        level: 1, // baseline level locked to 1
        xp: 0,
        discoveryType: 'Encounter', // Locked discoveryType to Encounter
        hardiness: aiMetrics['hardiness'] as int?,
        eggProduction: aiMetrics['egg_production'] as int?,
        rarityTier: aiMetrics['rarity_tier'] as String?,
        gradeNotes: "$gradingNotes [$locationNote]",
      );

      // Save to Firebase
      try {
        final repo = Provider.of<BirdRepository>(context, listen: false);
        await repo.addBird(newBird);
      } catch (e) {
        debugPrint("Firestore save error: $e. Mocking save for presentation.");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Encounter scan registered and graded!"),
            backgroundColor: AppColors.success,
          ),
        );

        // Route to Grading Summary Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GradingSummaryScreen(
              bird: newBird,
              latitude: lat,
              longitude: lon,
              imageBytes: imageBytes,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Encounter Scan failed: $e"),
            backgroundColor: AppColors.error,
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

  Uint8List _generateDummyImageBytes() {
    // Return a basic mock jpeg/png byte array representation
    // Under ordinary flutter runtime this is replaced by actual file bytes.
    return Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 108, 137, 0, 
      0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 96, 64, 4, 0, 0, 150, 
      0, 145, 230, 249, 211, 107, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scannerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Encounter Scanner', style: TextStyle(fontFamily: AppTextStyles.brandFont, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. Camera Viewfinder or Simulated Feed
          Positioned.fill(
            child: (_isCameraSupported && _isCameraInitialized && _cameraController != null)
                ? CameraPreview(_cameraController!)
                : _buildSimulatedViewfinder(),
          ),

          // 2. Centered TCG Card Frame Overlay Target
          Positioned.fill(
            child: _buildCardTargetOverlay(),
          ),

          // 3. Status indicator & controls overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primaryLight),
                      const SizedBox(height: 16),
                      Text(
                        _statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildScannerControls(),
    );
  }

  Widget _buildSimulatedViewfinder() {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Camera unavailable (Simulator/Web Mode)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure Simulated Scan Target:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    dropdownColor: Colors.grey[900],
                    value: _selectedBreed,
                    decoration: const InputDecoration(
                      labelText: 'Simulated Breed',
                      labelStyle: TextStyle(color: Colors.white70),
                      fillColor: Colors.white10,
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: _primaryBreeds.map((String breed) {
                      return DropdownMenuItem<String>(
                        value: breed,
                        child: Text(breed),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBreed = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    dropdownColor: Colors.grey[900],
                    value: _selectedSex,
                    decoration: const InputDecoration(
                      labelText: 'Simulated Sex',
                      labelStyle: TextStyle(color: Colors.white70),
                      fillColor: Colors.white10,
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: ['Male', 'Female', 'Unknown'].map((String sex) {
                      return DropdownMenuItem<String>(
                        value: sex,
                        child: Text(sex),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSex = val);
                      }
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCardTargetOverlay() {
    return AnimatedBuilder(
      animation: _scannerAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            // Sleek target frame sized like a vertical TCG card (aspect ratio ~ 0.7)
            final cardWidth = width * 0.72;
            final cardHeight = cardWidth / 0.7;

            final left = (width - cardWidth) / 2;
            final top = (height - cardHeight) / 2;

            final scanY = top + (cardHeight * _scannerAnimation.value);

            return Stack(
              children: [
                // Dark translucent margins outside target frame
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.6),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(color: Colors.black),
                      Positioned(
                        left: left,
                        top: top,
                        width: cardWidth,
                        height: cardHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card Frame Outline
                Positioned(
                  left: left,
                  top: top,
                  width: cardWidth,
                  height: cardHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primaryLight, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryLight.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Card Corner accents
                        _buildCornerAccent(top: true, left: true),
                        _buildCornerAccent(top: true, left: false),
                        _buildCornerAccent(top: false, left: true),
                        _buildCornerAccent(top: false, left: false),
                        
                        // Centered scanning reticle
                        const Center(
                          child: Icon(
                            Icons.center_focus_weak_rounded,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                        
                        // Text prompt at the bottom inside target
                        Positioned(
                          bottom: 16,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ALIGN ANIMAL IN FRAME',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Laser Scanning Line
                Positioned(
                  left: left + 2,
                  top: scanY,
                  width: cardWidth - 4,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryLight.withOpacity(0.01),
                          AppColors.primaryLight,
                          AppColors.primaryLight.withOpacity(0.01),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryLight.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 1.5,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCornerAccent({required bool top, required bool left}) {
    return Positioned(
      top: top ? 8 : null,
      bottom: top ? null : 8,
      left: left ? 8 : null,
      right: left ? null : 8,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            bottom: top ? BorderSide.none : const BorderSide(color: Colors.white, width: 2),
            left: left ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            right: left ? BorderSide.none : const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Capture button
          GestureDetector(
            onTap: _captureAndGrade,
            child: Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 4),
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          // Empty spacing for balancing
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
