// lib/widgets/storage_image.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageImage extends StatelessWidget {
  final String photoUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget errorWidget;

  const StorageImage({
    super.key,
    required this.photoUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    required this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.network(
          photoUrl,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget;
          },
        ),
      );
    }

    if (!photoUrl.startsWith('gs://')) {
      return errorWidget;
    }
    
    return FutureBuilder<Uint8List?>(
      future: _downloadBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return errorWidget;
        }
        return Container(
          width: width,
          height: height,
          color: const Color(0xFF0C1013), // dark card theme background
          child: Image.memory(
            snapshot.data!,
            fit: fit,
            alignment: Alignment.topCenter,
          ),
        );
      },
    );
  }

  Future<Uint8List?> _downloadBytes() async {
    try {
      String? extractedPath;
      if (photoUrl.startsWith('gs://')) {
        final uriStr = photoUrl.substring(5);
        final slashIndex = uriStr.indexOf('/');
        if (slashIndex != -1) {
          extractedPath = uriStr.substring(slashIndex + 1);
        }
      } else if (photoUrl.contains('&token=') && photoUrl.contains('/o/')) {
        final oIndex = photoUrl.indexOf('/o/');
        if (oIndex != -1) {
          final start = oIndex + 3;
          final qIndex = photoUrl.indexOf('?', start);
          final encodedPath = qIndex != -1 ? photoUrl.substring(start, qIndex) : photoUrl.substring(start);
          extractedPath = Uri.decodeComponent(encodedPath);
        }
      }

      if (extractedPath != null) {
        return await FirebaseStorage.instance
            .ref()
            .child(extractedPath)
            .getData(10 * 1024 * 1024);
      }

      final ref = FirebaseStorage.instance.refFromURL(photoUrl);
      return await ref.getData(10 * 1024 * 1024); // 10MB limit
    } catch (e) {
      debugPrint('Error downloading storage image bytes: $e');
      return null;
    }
  }
}
