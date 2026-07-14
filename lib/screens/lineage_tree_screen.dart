import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bird.dart';

class LineageTreeScreen extends StatefulWidget {
  final String startBirdId;

  const LineageTreeScreen({super.key, required this.startBirdId});

  @override
  State<LineageTreeScreen> createState() => _LineageTreeScreenState();
}

class _LineageTreeScreenState extends State<LineageTreeScreen> {
  late String _currentBirdId;
  final List<String> _navigationHistory = [];

  @override
  void initState() {
    super.initState();
    _currentBirdId = widget.startBirdId;
  }

  void _navigateToBird(String newBirdId) {
    setState(() {
      _navigationHistory.add(_currentBirdId);
      _currentBirdId = newBirdId;
    });
  }

  void _navigateBack() {
    if (_navigationHistory.isNotEmpty) {
      setState(() {
        _currentBirdId = _navigationHistory.removeLast();
      });
    }
  }

  Future<void> _addParentDialog(Bird childBird, bool isSire) async {
    final nameController = TextEditingController();
    final breedController = TextEditingController(text: childBird.breed);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isSire ? 'Add Father (Sire)' : 'Add Mother (Dam)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Barnaby',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: breedController,
                  decoration: const InputDecoration(
                    labelText: 'Breed',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a breed';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final user = FirebaseAuth.instance.currentUser;
                final parentRef = FirebaseFirestore.instance.collection('animals').doc();
                
                final newParent = Bird(
                  id: parentRef.id,
                  name: nameController.text.trim(),
                  breed: breedController.text.trim(),
                  ageOrHatchDate: DateTime.now().subtract(const Duration(days: 365)),
                  sex: isSire ? 'Male' : 'Female',
                  originType: 'Hatched',
                  uid: user?.uid ?? 'anonymous',
                  ownerId: user?.uid ?? 'anonymous',
                );

                try {
                  // Create parent document
                  await parentRef.set(newParent.toFirestore());

                  // Update child document link
                  await FirebaseFirestore.instance
                      .collection('animals')
                      .doc(childBird.id)
                      .update({
                    isSire ? 'sire_id' : 'dam_id': parentRef.id,
                  });

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${newParent.name} as parent!'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding parent: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentBirdId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lineage Pedigree'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Error: Invalid or Empty Bird ID targeting lineage tree.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lineage Pedigree'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: _navigationHistory.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateBack,
              )
            : null,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('animals')
            .doc(_currentBirdId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Bird not found'));
          }

          final rootBird = Bird.fromFirestore(snapshot.data!);

          return Container(
            color: Colors.grey.shade50,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Upper Section: Parents Row
                Expanded(
                  child: Row(
                    children: [
                      // Dam (Mother)
                      Expanded(
                        child: _buildParentNode(
                          parentId: rootBird.damId,
                          isSire: false,
                          childBird: rootBird,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Sire (Father)
                      Expanded(
                        child: _buildParentNode(
                          parentId: rootBird.sireId,
                          isSire: true,
                          childBird: rootBird,
                        ),
                      ),
                    ],
                  ),
                ),

                // Connection Lines
                CustomPaint(
                  size: const Size(double.infinity, 60),
                  painter: ConnectionLinesPainter(),
                ),

                // Lower Section: Current Root Bird
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.teal, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.pets, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              rootBird.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rootBird.geneticTraits.isNotEmpty ? rootBird.geneticTraits[0] : rootBird.breed,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                rootBird.sex,
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParentNode({
    required String? parentId,
    required bool isSire,
    required Bird childBird,
  }) {
    if (parentId == null) {
      return GestureDetector(
        onTap: () => _addParentDialog(childBird, isSire),
        child: Container(
          height: 140,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid, width: 1.5),
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: DashBorderWidget(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSire ? Icons.male : Icons.female,
                  color: Colors.grey.shade500,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  isSire ? 'Add Father (Sire)' : 'Add Mother (Dam)',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '(Genesis Bird)',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('animals')
          .doc(parentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Not found'));
        }

        final parentBird = Bird.fromFirestore(snapshot.data!);

        return GestureDetector(
          onTap: () => _navigateToBird(parentBird.id),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 150,
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isSire ? Colors.blue.shade100 : Colors.pink.shade100,
                    child: Icon(
                      isSire ? Icons.male : Icons.female,
                      color: isSire ? Colors.blue.shade800 : Colors.pink.shade800,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    parentBird.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parentBird.geneticTraits.isNotEmpty ? parentBird.geneticTraits[0] : parentBird.breed,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSire ? 'Father' : 'Mother',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSire ? Colors.blue.shade700 : Colors.pink.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom Painter for drawing the connecting branch lines
class ConnectionLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal.shade300
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width / 2, size.height) // Child connection point (bottom-center)
      ..cubicTo(
        size.width / 2, size.height / 2,
        size.width / 4, size.height / 2,
        size.width / 4, 0, // Dam connection point (top-left)
      )
      ..moveTo(size.width / 2, size.height)
      ..cubicTo(
        size.width / 2, size.height / 2,
        3 * size.width / 4, size.height / 2,
        3 * size.width / 4, 0, // Sire connection point (top-right)
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Simple Dash Border wrapper using a Canvas
class DashBorderWidget extends StatelessWidget {
  final Widget child;

  const DashBorderWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashBorderPainter(),
      child: child,
    );
  }
}

class _DashBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5;
    const double dashSpace = 5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
