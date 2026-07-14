import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/bird.dart';
import '../services/grading_engine.dart';

class CardCanvasService {
  /// Dynamically composites a vertical TCG trading card graphic and shares it.
  static Future<void> exportAndShareCard(Bird animal) async {
    try {
      final pngBytes = await generateCardGraphic(animal);
      
      final String safeName = animal.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final xFile = XFile.fromData(
        pngBytes,
        name: '${safeName}_tcg_card.png',
        mimeType: 'image/png',
      );

      final double grade = GradingEngine.calculateGrade(animal);
      final String deckType = animal.geneticTraits.isNotEmpty ? animal.geneticTraits[0] : animal.breed;

      final String shareText =
          'Check out my latest addition to my TCG Farms binder! 🦅✨\n\n'
          'Card: ${animal.name}\n'
          'Deck: $deckType\n'
          'Grade: PSA ${grade.toStringAsFixed(1)}\n\n'
          'Collect, grade, and track your own animals by creating your master binder here: https://duckxmeta.github.io/JustDuckit-app/';

      await Share.shareXFiles(
        [xFile],
        text: shareText,
      );
    } catch (e) {
      debugPrint('Error sharing card graphic: $e');
    }
  }

  /// Helper to download image bytes using Firebase Storage SDK to bypass web CORS bucket blocks.
  static Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      if (!url.startsWith('gs://') && !url.startsWith('https://')) {
        return null;
      }
      String? extractedPath;
      if (url.startsWith('gs://')) {
        final uriStr = url.substring(5);
        final slashIndex = uriStr.indexOf('/');
        if (slashIndex != -1) {
          extractedPath = uriStr.substring(slashIndex + 1);
        }
      } else if (url.contains('&token=') && url.contains('/o/')) {
        final oIndex = url.indexOf('/o/');
        if (oIndex != -1) {
          final start = oIndex + 3;
          final qIndex = url.indexOf('?', start);
          final encodedPath = qIndex != -1 ? url.substring(start, qIndex) : url.substring(start);
          extractedPath = Uri.decodeComponent(encodedPath);
        }
      }

      if (extractedPath != null) {
        return await FirebaseStorage.instance
            .ref()
            .child(extractedPath)
            .getData(10 * 1024 * 1024);
      }

      final ref = FirebaseStorage.instance.refFromURL(url);
      return await ref.getData(10 * 1024 * 1024); // 10MB limit
    } catch (e) {
      debugPrint('Error downloading image for card canvas: $e');
      return null;
    }
  }

  /// Composites raw PNG bytes of the animal's card template.
  static Future<Uint8List> generateCardGraphic(Bird animal) async {
    final recorder = ui.PictureRecorder();
    const double width = 600;
    const double height = 900;
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    final Color themeColor = _getBorderColor(animal.breed);

    // 1. Outer Deck color border
    final borderPaint = Paint()..color = themeColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, width, height), const Radius.circular(32)),
      borderPaint,
    );

    // 2. Inner card container body
    final innerPaint = Paint()..color = const Color(0xFF141A1E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(16, 16, width - 32, height - 32), const Radius.circular(24)),
      innerPaint,
    );

    // 3. App header title card banner
    final Rect bannerRect = const Rect.fromLTWH(16, 16, width - 32, 120);
    final bannerPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(16, 16),
        Offset(width - 16, 16),
        [themeColor.withOpacity(0.85), const Color(0xFF1A2A3A)],
      );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        bannerRect,
        topLeft: const Radius.circular(24),
        topRight: const Radius.circular(24),
      ),
      bannerPaint,
    );

    // 4. Animal name title text
    final namePainter = TextPainter(
      text: TextSpan(
        text: animal.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    namePainter.layout();
    namePainter.paint(canvas, const Offset(40, 36));

    // 5. Deck sub-header label
    final String displayBreed = animal.geneticTraits.isNotEmpty ? animal.geneticTraits[0] : animal.breed;
    final deckPainter = TextPainter(
      text: TextSpan(
        text: '${displayBreed.toUpperCase()} DECK',
        style: TextStyle(
          color: Colors.teal.shade200,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    deckPainter.layout();
    deckPainter.paint(canvas, const Offset(40, 85));

    // 6. Photo panel window
    final photoRect = const Rect.fromLTWH(40, 160, width - 80, 440);
    final photoBgPaint = Paint()..color = const Color(0xFF0C1013);
    canvas.drawRRect(
      RRect.fromRectAndRadius(photoRect, const Radius.circular(16)),
      photoBgPaint,
    );

    // Draw animal portrait photo if present
    bool hasRenderedPhoto = false;
    if (animal.photoUrl != null && animal.photoUrl!.isNotEmpty) {
      final imageBytes = await _downloadImageBytes(animal.photoUrl!);
      if (imageBytes != null) {
        try {
          final codec = await ui.instantiateImageCodec(imageBytes);
          final frame = await codec.getNextFrame();
          final ui.Image photo = frame.image;

          // Paint image with crop-to-fit scaling
          canvas.save();
          canvas.clipRRect(RRect.fromRectAndRadius(photoRect, const Radius.circular(16)));
          
          final double srcWidth = photo.width.toDouble();
          final double srcHeight = photo.height.toDouble();
          final double destWidth = photoRect.width;
          final double destHeight = photoRect.height;
          
          final double scale = srcWidth / srcHeight > destWidth / destHeight 
              ? destHeight / srcHeight 
              : destWidth / srcWidth;
              
          final double drawWidth = srcWidth * scale;
          final double drawHeight = srcHeight * scale;
          final double left = photoRect.left + (destWidth - drawWidth) / 2;
          final double top = photoRect.top; // Align to topCenter
          
          canvas.drawImageRect(
            photo,
            Rect.fromLTWH(0, 0, srcWidth, srcHeight),
            Rect.fromLTWH(left, top, drawWidth, drawHeight),
            Paint(),
          );
          
          canvas.restore();
          hasRenderedPhoto = true;
        } catch (e) {
          debugPrint('Error drawing photo on canvas: $e');
        }
      }
    }

    // Default icon fallback if no photo was rendered
    if (!hasRenderedPhoto) {
      final placeholderPaint = Paint()
        ..color = themeColor.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawCircle(const Offset(width / 2, 380), 70, placeholderPaint);

      final fillPaint = Paint()..color = themeColor.withOpacity(0.4);
      canvas.drawCircle(const Offset(width / 2, 380), 30, fillPaint);
    }

    // 7. Bottom TCG details content container
    final detailsRect = const Rect.fromLTWH(40, 630, width - 80, 220);
    final detailsPaint = Paint()..color = const Color(0xFF1E262C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(detailsRect, const Radius.circular(16)),
      detailsPaint,
    );

    // 8. Serial number
    final serialPainter = TextPainter(
      text: TextSpan(
        text: 'NO. ${animal.serialNumber.toUpperCase()}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    serialPainter.layout();
    serialPainter.paint(canvas, const Offset(64, 665));

    // 9. Genetics and archetype traits info
    final traitsText = animal.geneticTraits.isEmpty 
        ? 'No special genetics recorded.' 
        : 'GENETIC: ${animal.geneticTraits.join(" • ")}';
    final traitsPainter = TextPainter(
      text: TextSpan(
        text: traitsText,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    traitsPainter.layout(maxWidth: width - 120);
    traitsPainter.paint(canvas, const Offset(64, 715));

    // 10. PSA slab label grade scores
    final double grade = GradingEngine.calculateGrade(animal);
    final String tier = GradingEngine.getTierLabel(grade);

    // Dynamic grade display badge
    final gradeBgPaint = Paint()..color = const Color(0xFF0F1316);
    final Rect gradeBadgeRect = const Rect.fromLTWH(64, 765, 472, 60);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gradeBadgeRect, const Radius.circular(8)),
      gradeBgPaint,
    );

    // PSA Grade score text
    final gradeValuePainter = TextPainter(
      text: TextSpan(
        text: 'PSA ${grade.toStringAsFixed(1)}',
        style: const TextStyle(
          color: Color(0xFFFFD700), // Gold
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    gradeValuePainter.layout();
    gradeValuePainter.paint(canvas, const Offset(84, 782));

    // Grade tier label right-aligned
    final tierPainter = TextPainter(
      text: TextSpan(
        text: tier.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tierPainter.layout();
    tierPainter.paint(canvas, Offset(512 - tierPainter.width, 786));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Maps breed archetype categories to theme borders.
  static Color _getBorderColor(String breed) {
    final b = breed.toLowerCase();
    if (b == 'avian') {
      return Colors.green.shade600;
    } else if (b == 'pets') {
      return Colors.indigo.shade600;
    } else if (b == 'livestock') {
      return Colors.deepOrange.shade800;
    } else if (b == 'aquatic') {
      return Colors.cyan.shade600;
    }
    return Colors.teal;
  }
}
