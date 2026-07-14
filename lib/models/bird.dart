import 'package:cloud_firestore/cloud_firestore.dart';

class Bird {
  final String id;
  final String name;
  final String breed;
  final String category; // e.g. 'Avian', 'Pets', 'Livestock', 'Aquatic'
  final DateTime ageOrHatchDate;
  final String sex;
  final String originType;
  final String? sireId;
  final String? damId;
  final String? photoUrl;
  final String uid; // backward compatibility key for firebase rules
  final String ownerId; // premium naming convention key

  // Collectible Gamified Features
  final String serialNumber;
  final double flockGrade;
  final List<String> geneticTraits;
  final String cardVariant; // 'Standard', 'Holo', 'Full-Art'
  final int level;
  final int xp;
  final String discoveryType; // 'Resident' or 'Encounter'

  // AI Appraisal Metrics
  final int? hardiness;
  final int? eggProduction;
  final String? rarityTier;
  final String? gradeNotes;

  Bird({
    required this.id,
    required this.name,
    required this.breed,
    this.category = 'Avian',
    required this.ageOrHatchDate,
    required this.sex,
    required this.originType,
    this.sireId,
    this.damId,
    this.photoUrl,
    required this.uid,
    required this.ownerId,
    this.serialNumber = 'N/A',
    this.flockGrade = 8.5,
    this.geneticTraits = const [],
    this.cardVariant = 'Standard',
    this.level = 1,
    this.xp = 0,
    this.discoveryType = 'Resident',
    this.hardiness,
    this.eggProduction,
    this.rarityTier,
    this.gradeNotes,
  });

  factory Bird.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final String resolvedOwnerId = data['owner_id'] as String? ?? data['uid'] as String? ?? '';
    final String parsedBreed = data['breed'] as String? ?? '';
    return Bird(
      id: doc.id,
      name: data['name'] as String? ?? '',
      breed: parsedBreed,
      category: data['category'] as String? ?? (['avian', 'pets', 'livestock', 'aquatic'].contains(parsedBreed.toLowerCase()) ? parsedBreed : 'Avian'),
      ageOrHatchDate: data['age_or_hatch_date'] is Timestamp
          ? (data['age_or_hatch_date'] as Timestamp).toDate()
          : DateTime.now(),
      sex: data['sex'] as String? ?? '',
      originType: data['origin_type'] as String? ?? '',
      sireId: data['sire_id'] as String?,
      damId: data['dam_id'] as String?,
      photoUrl: (doc.data() as Map<String, dynamic>?)?.containsKey('photo_url') == true ? (doc.get('photo_url') as String? ?? '') : '',
      uid: resolvedOwnerId,
      ownerId: resolvedOwnerId,
      serialNumber: data['serial_number'] as String? ?? 'N/A',
      flockGrade: (data['flock_grade'] as num?)?.toDouble() ?? 8.5,
      geneticTraits: List<String>.from(data['genetic_traits'] as List<dynamic>? ?? []),
      cardVariant: data['card_variant'] as String? ?? 'Standard',
      level: data['level'] as int? ?? 1,
      xp: data['xp'] as int? ?? 0,
      discoveryType: data['discovery_type'] as String? ?? 'Resident',
      hardiness: data['hardiness'] as int?,
      eggProduction: data['egg_production'] as int?,
      rarityTier: data['rarity_tier'] as String?,
      gradeNotes: data['grade_notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.toString(),
      'breed': breed.toString(),
      'category': category.toString(),
      'age_or_hatch_date': Timestamp.fromDate(ageOrHatchDate),
      'sex': sex.toString(),
      'origin_type': originType.toString(),
      if (sireId != null) 'sire_id': sireId.toString(),
      if (damId != null) 'dam_id': damId.toString(),
      if (photoUrl != null) 'photo_url': photoUrl.toString(),
      'uid': ownerId.toString(),
      'owner_id': ownerId.toString(),
      'serial_number': serialNumber.toString(),
      'flock_grade': flockGrade,
      'genetic_traits': geneticTraits.map((t) => t.toString()).toList(),
      'card_variant': cardVariant.toString(),
      'level': level,
      'xp': xp,
      'discovery_type': discoveryType.toString(),
      if (hardiness != null) 'hardiness': hardiness,
      if (eggProduction != null) 'egg_production': eggProduction,
      if (rarityTier != null) 'rarity_tier': rarityTier.toString(),
      if (gradeNotes != null) 'grade_notes': gradeNotes.toString(),
    };
  }

  Bird copyWith({
    String? id,
    String? name,
    String? breed,
    String? category,
    DateTime? ageOrHatchDate,
    String? sex,
    String? originType,
    String? sireId,
    String? damId,
    String? photoUrl,
    String? uid,
    String? ownerId,
    String? serialNumber,
    double? flockGrade,
    List<String>? geneticTraits,
    String? cardVariant,
    int? level,
    int? xp,
    String? discoveryType,
    int? hardiness,
    int? eggProduction,
    String? rarityTier,
    String? gradeNotes,
  }) {
    return Bird(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      category: category ?? this.category,
      ageOrHatchDate: ageOrHatchDate ?? this.ageOrHatchDate,
      sex: sex ?? this.sex,
      originType: originType ?? this.originType,
      sireId: sireId ?? this.sireId,
      damId: damId ?? this.damId,
      photoUrl: photoUrl ?? this.photoUrl,
      uid: uid ?? this.uid,
      ownerId: ownerId ?? this.ownerId,
      serialNumber: serialNumber ?? this.serialNumber,
      flockGrade: flockGrade ?? this.flockGrade,
      geneticTraits: geneticTraits ?? this.geneticTraits,
      cardVariant: cardVariant ?? this.cardVariant,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      discoveryType: discoveryType ?? this.discoveryType,
      hardiness: hardiness ?? this.hardiness,
      eggProduction: eggProduction ?? this.eggProduction,
      rarityTier: rarityTier ?? this.rarityTier,
      gradeNotes: gradeNotes ?? this.gradeNotes,
    );
  }
}
