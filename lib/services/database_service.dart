// lib/services/database_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  /// Securely deletes a specific animal card document from Firestore.
  static Future<void> deleteAnimalCard(String animalId) async {
    await FirebaseFirestore.instance.collection('animals').doc(animalId).delete();
  }
}
