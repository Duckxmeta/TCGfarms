import 'package:cloud_firestore/cloud_firestore.dart';

class IncubationBatch {
  final String id;
  final String batchName;
  final String breedTemplateId;
  final DateTime startDate;
  final DateTime projectedHatchDate;
  final DateTime lockdownDate;
  final String uid;

  IncubationBatch({
    required this.id,
    required this.batchName,
    required this.breedTemplateId,
    required this.startDate,
    required this.projectedHatchDate,
    required this.lockdownDate,
    required this.uid,
  });

  factory IncubationBatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.now();
    }

    return IncubationBatch(
      id: doc.id,
      batchName: data['batch_name'] as String? ?? '',
      breedTemplateId: data['breed_template_id'] as String? ?? '',
      startDate: parseDateTime(data['start_date']),
      projectedHatchDate: parseDateTime(data['projected_hatch_date']),
      lockdownDate: parseDateTime(data['lockdown_date']),
      uid: data['uid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'batch_name': batchName,
      'breed_template_id': breedTemplateId,
      'start_date': Timestamp.fromDate(startDate),
      'projected_hatch_date': Timestamp.fromDate(projectedHatchDate),
      'lockdown_date': Timestamp.fromDate(lockdownDate),
      'uid': uid,
    };
  }

  IncubationBatch copyWith({
    String? id,
    String? batchName,
    String? breedTemplateId,
    DateTime? startDate,
    DateTime? projectedHatchDate,
    DateTime? lockdownDate,
    String? uid,
  }) {
    return IncubationBatch(
      id: id ?? this.id,
      batchName: batchName ?? this.batchName,
      breedTemplateId: breedTemplateId ?? this.breedTemplateId,
      startDate: startDate ?? this.startDate,
      projectedHatchDate: projectedHatchDate ?? this.projectedHatchDate,
      lockdownDate: lockdownDate ?? this.lockdownDate,
      uid: uid ?? this.uid,
    );
  }
}
