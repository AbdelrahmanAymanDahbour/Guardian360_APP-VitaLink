import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_thresholds.dart';

/// ==========================================
/// 📞 Emergency Contact Model - Guardian 360
/// ==========================================
/// نموذج جهة اتصال الطوارئ.
///
/// يتكامل مع:
/// - ContactsViewModel
/// - FirebaseService
/// - AlertService
/// - AlertModel / EmergencyContactSnapshot
///
/// مسؤول عن:
/// - تمثيل جهة اتصال واحدة.
/// - التحويل من/إلى Map وFirestore.
/// - توفير snapshot آمن وقت البلاغ.
///
/// غير مسؤول عن:
/// - إرسال SMS أو WhatsApp.
/// - الاتصال الفعلي.
/// - منطق الشاشة أو التحقق UI.
class EmergencyContactModel {
  static const Object _unset = Object();

  final String id;
  final String name;
  final String phone;
  final String relation;

  /// 1 = primary, 2+ = backup.
  final int priority;

  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastContactedAt;

  const EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.priority = 1,
    this.isVerified = false,
    required this.createdAt,
    this.lastContactedAt,
  });

  // ==========================================
  // Factory Constructors
  // ==========================================

  factory EmergencyContactModel.create({
    required String name,
    required String phone,
    required String relation,
    int priority = 1,
  }) {
    final now = DateTime.now();

    return EmergencyContactModel(
      id: 'contact_${now.microsecondsSinceEpoch}',
      name: _sanitizeText(name),
      phone: _sanitizePhone(phone),
      relation: EmergencyContactRelations.normalize(relation),
      priority: _normalizePriority(priority),
      createdAt: now,
    );
  }

  factory EmergencyContactModel.empty() {
    final now = DateTime.now();

    return EmergencyContactModel(
      id: 'contact_${now.microsecondsSinceEpoch}',
      name: '',
      phone: '',
      relation: EmergencyContactRelations.other,
      priority: 1,
      createdAt: now,
    );
  }

  factory EmergencyContactModel.fromMap(Map<String, dynamic> map) {
    final createdAt = _toDateTime(map['createdAt']) ?? DateTime.now();

    return EmergencyContactModel(
      id: _stringOrFallback(
        map['id'] ?? map['contactId'],
        fallback: 'contact_${createdAt.microsecondsSinceEpoch}',
      ),
      name: _sanitizeText(_stringOrFallback(map['name'])),
      phone: _sanitizePhone(_stringOrFallback(map['phone'])),
      relation: EmergencyContactRelations.normalize(
        _stringOrFallback(map['relation']),
      ),
      priority: _normalizePriority(_toInt(map['priority'], fallback: 1)),
      isVerified: _toBool(map['isVerified'], fallback: false),
      createdAt: createdAt,
      lastContactedAt: _toDateTime(map['lastContactedAt']),
    );
  }

  factory EmergencyContactModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return EmergencyContactModel.fromMap({...data, 'id': data['id'] ?? doc.id});
  }

  // ==========================================
  // Serialization
  // ==========================================

  /// General app/local map.
  ///
  /// Uses ISO strings for easier local storage/debugging.
  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'id': id,
      'name': name,
      'phone': phone,
      'relation': relation,
      'priority': priority,
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastContactedAt': lastContactedAt?.toIso8601String(),
    });
  }

  /// Firestore document map.
  ///
  /// Keeps id optional because sometimes the contact is stored as a sub-map
  /// inside the user document, not as a standalone document.
  Map<String, dynamic> toFirestoreMap({bool includeId = false}) {
    return _removeNullValues({
      if (includeId) 'id': id,
      'name': name,
      'phone': phone,
      'relation': relation,
      'priority': priority,
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastContactedAt': lastContactedAt != null
          ? Timestamp.fromDate(lastContactedAt!)
          : null,
    });
  }

  /// Compact snapshot saved inside an emergency report / alert.
  Map<String, dynamic> toSnapshot() {
    return _removeNullValues({
      'id': id,
      'name': name,
      'phone': phone,
      'relation': relation,
      'priority': priority,
      'isPrimary': isPrimary,
      'isVerified': isVerified,
    });
  }

  // ==========================================
  // Copy With
  // ==========================================

  EmergencyContactModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? relation,
    int? priority,
    bool? isVerified,
    DateTime? createdAt,
    Object? lastContactedAt = _unset,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      name: name != null ? _sanitizeText(name) : this.name,
      phone: phone != null ? _sanitizePhone(phone) : this.phone,
      relation: relation != null
          ? EmergencyContactRelations.normalize(relation)
          : this.relation,
      priority: priority != null ? _normalizePriority(priority) : this.priority,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastContactedAt: identical(lastContactedAt, _unset)
          ? this.lastContactedAt
          : lastContactedAt as DateTime?,
    );
  }

  EmergencyContactModel markContacted({DateTime? time}) {
    return copyWith(lastContactedAt: time ?? DateTime.now());
  }

  // ==========================================
  // Validation / Helpers
  // ==========================================

  bool get isPrimary => priority == 1;

  bool get hasName => name.trim().isNotEmpty;

  bool get hasPhone => phone.trim().isNotEmpty;

  bool get hasValidPhone {
    final digitsCount = phone.replaceAll(RegExp(r'[^0-9]'), '').length;

    return digitsCount >= AppThresholds.minPhoneLength &&
        digitsCount <= AppThresholds.maxPhoneLength;
  }

  bool get isValid {
    return id.trim().isNotEmpty &&
        hasName &&
        hasValidPhone &&
        EmergencyContactRelations.isKnownRelation(relation) &&
        priority >= 1 &&
        priority <= AppThresholds.maxEmergencyContacts;
  }

  bool get canBeUsedForEmergencySnapshot {
    return hasName || hasPhone;
  }

  // ==========================================
  // Private Helpers
  // ==========================================

  static String _sanitizeText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _sanitizePhone(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '');
  }

  static int _normalizePriority(int value) {
    if (value < 1) return 1;
    if (value > AppThresholds.maxEmergencyContacts) {
      return AppThresholds.maxEmergencyContacts;
    }
    return value;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is String) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }

    return fallback;
  }

  static String _stringOrFallback(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }

  @override
  String toString() {
    return 'EmergencyContactModel('
        'id: $id, '
        'name: $name, '
        'phone: $phone, '
        'relation: $relation, '
        'priority: $priority, '
        'isVerified: $isVerified, '
        'isValid: $isValid'
        ')';
  }
}

/// ==========================================
/// 📋 Relations Constants
/// ==========================================
class EmergencyContactRelations {
  static const String father = 'father';
  static const String mother = 'mother';
  static const String brother = 'brother';
  static const String sister = 'sister';
  static const String spouse = 'spouse';
  static const String son = 'son';
  static const String daughter = 'daughter';
  static const String friend = 'friend';
  static const String colleague = 'colleague';
  static const String other = 'other';

  static const List<String> all = [
    father,
    mother,
    brother,
    sister,
    spouse,
    son,
    daughter,
    friend,
    colleague,
    other,
  ];

  static String normalize(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) return other;

    if (all.contains(normalized)) return normalized;

    switch (normalized) {
      case 'dad':
      case 'parent':
        return father;
      case 'mom':
        return mother;
      case 'sibling':
        return brother;
      case 'wife':
      case 'husband':
      case 'partner':
        return spouse;
      default:
        return other;
    }
  }

  static bool isKnownRelation(String value) {
    return all.contains(normalize(value));
  }

  /// Relation key for future localization.
  static String keyOf(String relation) {
    switch (normalize(relation)) {
      case father:
        return 'father';
      case mother:
        return 'mother';
      case brother:
        return 'brother';
      case sister:
        return 'sister';
      case spouse:
        return 'spouse';
      case son:
        return 'son';
      case daughter:
        return 'daughter';
      case friend:
        return 'friend';
      case colleague:
        return 'colleague';
      case other:
      default:
        return 'other';
    }
  }
}
