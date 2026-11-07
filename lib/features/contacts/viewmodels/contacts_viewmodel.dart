import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_thresholds.dart';
import '../../../core/models/emergency_contact_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/services/firebase_auth_service.dart';

/// ==========================================
/// 📞 Contacts ViewModel - Guardian 360
/// ==========================================
/// مسؤول عن جهات اتصال الطوارئ فقط.
///
/// مصدر الحقيقة الرسمي عند توفر الاتصال:
/// users/{uid}
/// - primaryEmergencyContact
/// - extraEmergencyContacts
/// - hasEmergencyContacts
///
/// التخزين المحلي SharedPreferences:
/// - Cache سريع للعرض.
/// - Pending Sync عند فشل السحابة.
///
/// غير مسؤول عن:
/// - إرسال SMS.
/// - إجراء مكالمات.
/// - إنشاء بلاغات.
/// - تعديل جهات اتصال الهاتف الأصلية.
///
/// ملاحظة الاستيراد:
/// - يتم اختيار جهة من الهاتف.
/// - لا يتم حفظها مباشرة.
/// - يتم تعبئة الفورم فقط، ثم المستخدم يراجع ويضغط حفظ.
class ContactsViewModel extends ChangeNotifier {
  ContactsViewModel({
    FirebaseAuthService? authService,
    FirebaseService? firebaseService,
  }) : _authService = authService ?? FirebaseAuthService(),
       _firebaseService = firebaseService ?? FirebaseService() {
    unawaited(loadContacts());
  }

  final FirebaseAuthService _authService;
  final FirebaseService _firebaseService;

  static const String _localCacheKey = 'emergency_contacts';
  static const String _pendingSyncKey = 'emergency_contacts_pending_sync';
  static const Duration _loadTimeout = Duration(seconds: 8);
  static const Duration _saveTimeout = Duration(seconds: 8);

  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  /// قيمة افتراضية للـ Dropdown فقط.
  /// لا يتم حفظ أي جهة إلا بعد ضغط المستخدم زر الحفظ.
  String selectedRelation = EmergencyContactRelations.father;

  final List<String> relations = EmergencyContactRelations.all;

  List<EmergencyContactModel> contacts = [];

  bool isLoading = true;
  bool isSaving = false;
  bool isImportingFromPhone = false;
  bool isSyncingWithCloud = false;
  bool hasPendingCloudSync = false;

  String errorMessage = '';
  String successMessage = '';

  bool _isDisposed = false;

  // ==========================================
  // Getters
  // ==========================================

  bool get hasContacts => contacts.isNotEmpty;

  bool get canAddMoreContacts =>
      contacts.length < AppThresholds.maxEmergencyContacts;

  int get contactsCount => contacts.length;

  int get maxContacts => AppThresholds.maxEmergencyContacts;

  bool get isBusy => isLoading || isSaving || isImportingFromPhone;

  String get readinessTitle {
    if (hasPendingCloudSync) {
      return hasContacts
          ? 'contacts.readiness.local_saved_title'
          : 'contacts.readiness.pending_sync_title';
    }

    return hasContacts
        ? 'contacts.readiness.ready_title'
        : 'contacts.readiness.incomplete_title';
  }

  String get readinessSubtitle {
    if (hasPendingCloudSync) {
      return 'contacts.readiness.pending_sync_subtitle';
    }

    return hasContacts
        ? 'contacts.readiness.ready_subtitle'
        : 'contacts.readiness.incomplete_subtitle';
  }

  Color get readinessColor {
    if (hasPendingCloudSync) return Colors.blueGrey;
    return hasContacts ? Colors.green : Colors.orange;
  }

  EmergencyContactModel? get primaryContact {
    if (contacts.isEmpty) return null;
    return contacts.first;
  }

  List<EmergencyContactModel> get backupContacts {
    if (contacts.length <= 1) return const [];
    return contacts.skip(1).toList(growable: false);
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==========================================
  // Loading
  // ==========================================

  Future<void> loadContacts({bool forceCloudRefresh = false}) async {
    errorMessage = '';
    successMessage = '';

    final cachedContacts = await _loadContactsFromCache();
    hasPendingCloudSync = await _loadPendingSyncFlag();

    if (cachedContacts.isNotEmpty) {
      contacts = _reindexContacts(cachedContacts);
      isLoading = false;
      _safeNotify();
    } else {
      isLoading = true;
      _safeNotify();
    }

    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      isLoading = false;

      if (contacts.isEmpty) {
        errorMessage = 'contacts.errors.login_required_manage';
      }

      _safeNotify();
      return;
    }

    try {
      // إذا كان لدينا تعديل محلي غير مرفوع، نحاول رفعه أولاً.
      // لا نغطيه ببيانات السحابة قبل نجاح المزامنة.
      if (hasPendingCloudSync) {
        final synced = await _syncContactsToCloud(showUserMessage: false);

        if (!synced) {
          isLoading = false;
          _safeNotify();
          return;
        }
      }

      // إذا لا يوجد pending، نثق بالسحابة كمصدر رسمي ونحدث الكاش.
      final userResult = await _firebaseService
          .getUser(currentUser.uid)
          .timeout(_loadTimeout);

      if (userResult.isSuccess && userResult.data != null) {
        final remoteContacts = _parseContactsFromUserData(userResult.data!);

        contacts = _reindexContacts(remoteContacts);
        await _cacheContactsLocally(contacts);
        await _setPendingSync(false);

        errorMessage = '';
      } else if (contacts.isEmpty) {
        errorMessage = 'contacts.errors.load_failed';
      }
    } on TimeoutException {
      debugPrint('⏱️ ContactsViewModel: loadContacts timeout');

      if (contacts.isEmpty) {
        errorMessage = 'contacts.errors.load_unavailable';
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ContactsViewModel loadContacts error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (contacts.isEmpty) {
        errorMessage = 'contacts.errors.load_failed';
      }
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> refreshContacts() async {
    await loadContacts(forceCloudRefresh: true);
  }

  Future<List<EmergencyContactModel>> _loadContactsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_localCacheKey);

      if (rawJson == null || rawJson.trim().isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(rawJson);

      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) {
            return EmergencyContactModel.fromMap(
              item.map((key, dynamic value) => MapEntry(key.toString(), value)),
            );
          })
          .where((contact) => contact.canBeUsedForEmergencySnapshot)
          .toList();
    } catch (e) {
      debugPrint('⚠️ ContactsViewModel: Failed to load cache - $e');
      return const [];
    }
  }

  List<EmergencyContactModel> _parseContactsFromUserData(
    Map<String, dynamic> userData,
  ) {
    final parsed = <EmergencyContactModel>[];

    final primary = _asStringKeyMap(userData['primaryEmergencyContact']);

    if (primary != null) {
      final contact = EmergencyContactModel.fromMap({
        ...primary,
        'priority': 1,
      });

      if (contact.canBeUsedForEmergencySnapshot) {
        parsed.add(contact.copyWith(priority: 1));
      }
    }

    final extra = userData['extraEmergencyContacts'];

    if (extra is List) {
      for (final item in extra) {
        final map = _asStringKeyMap(item);
        if (map == null) continue;

        final contact = EmergencyContactModel.fromMap(map);

        if (contact.canBeUsedForEmergencySnapshot) {
          parsed.add(contact);
        }
      }
    }

    return parsed;
  }

  // ==========================================
  // Add / Delete / Reorder
  // ==========================================

  Future<bool> addContactFromForm() async {
    final validationError = validateForm();

    if (validationError != null) {
      errorMessage = validationError;
      successMessage = '';
      _safeNotify();
      return false;
    }

    final normalizedPhone = normalizeJordanPhone(phoneController.text.trim());

    if (normalizedPhone == null) {
      errorMessage = 'contacts.validation.invalid_phone';
      successMessage = '';
      _safeNotify();
      return false;
    }

    final newContact = EmergencyContactModel.create(
      name: _cleanText(nameController.text),
      phone: normalizedPhone,
      relation: selectedRelation,
      priority: contacts.length + 1,
    );

    return addContact(newContact);
  }

  Future<bool> addContact(EmergencyContactModel contact) async {
    if (!canAddMoreContacts) {
      errorMessage = 'contacts.errors.max_reached';
      successMessage = '';
      _safeNotify();
      return false;
    }

    final validationError = validateContact(contact);

    if (validationError != null) {
      errorMessage = validationError;
      successMessage = '';
      _safeNotify();
      return false;
    }

    final normalizedPhone = normalizeJordanPhone(contact.phone);

    if (normalizedPhone == null) {
      errorMessage = 'contacts.validation.invalid_phone';
      successMessage = '';
      _safeNotify();
      return false;
    }

    if (_isDuplicatePhone(normalizedPhone)) {
      errorMessage = 'contacts.validation.duplicate_phone';
      successMessage = '';
      _safeNotify();
      return false;
    }

    final updatedContacts = _reindexContacts([
      ...contacts,
      contact.copyWith(name: _cleanText(contact.name), phone: normalizedPhone),
    ]);

    final savedLocally = await _persistContactsLocallyThenSync(
      updatedContacts,
      successText: 'contacts.messages.added',
    );

    if (!savedLocally) return false;

    clearForm();
    _safeNotify();
    return true;
  }

  Future<bool> deleteContact(int index) async {
    if (index < 0 || index >= contacts.length) {
      errorMessage = 'contacts.errors.not_found';
      successMessage = '';
      _safeNotify();
      return false;
    }

    final updatedContacts = List<EmergencyContactModel>.from(contacts)
      ..removeAt(index);

    final savedLocally = await _persistContactsLocallyThenSync(
      _reindexContacts(updatedContacts),
      successText: 'contacts.messages.deleted',
    );

    return savedLocally;
  }

  Future<bool> makePrimary(int index) async {
    if (index < 0 || index >= contacts.length) {
      errorMessage = 'contacts.errors.not_found';
      successMessage = '';
      _safeNotify();
      return false;
    }

    if (index == 0) return true;

    final selected = contacts[index];

    final updatedContacts = List<EmergencyContactModel>.from(contacts)
      ..removeAt(index)
      ..insert(0, selected);

    return _persistContactsLocallyThenSync(
      _reindexContacts(updatedContacts),
      successText: 'contacts.messages.primary_updated',
    );
  }

  Future<bool> moveContactUp(int index) async {
    if (index <= 0 || index >= contacts.length) return false;

    final updatedContacts = List<EmergencyContactModel>.from(contacts);
    final item = updatedContacts.removeAt(index);
    updatedContacts.insert(index - 1, item);

    return _persistContactsLocallyThenSync(
      _reindexContacts(updatedContacts),
      successText: 'contacts.messages.order_updated',
      quietSuccess: true,
    );
  }

  Future<bool> moveContactDown(int index) async {
    if (index < 0 || index >= contacts.length - 1) return false;

    final updatedContacts = List<EmergencyContactModel>.from(contacts);
    final item = updatedContacts.removeAt(index);
    updatedContacts.insert(index + 1, item);

    return _persistContactsLocallyThenSync(
      _reindexContacts(updatedContacts),
      successText: 'contacts.messages.order_updated',
      quietSuccess: true,
    );
  }

  // ==========================================
  // Phone Contact Import
  // ==========================================

  /// يفتح منتقي جهات الاتصال الأصلي من نظام الهاتف.
  ///
  /// لا يتم حفظ الجهة مباشرة بعد الاستيراد.
  /// يتم فقط تعبئة الاسم والرقم داخل الفورم حتى يراجع المستخدم البيانات.
  Future<bool> importContactFromPhone() async {
    if (isSaving || isImportingFromPhone) return false;

    isImportingFromPhone = true;
    errorMessage = '';
    successMessage = '';
    _safeNotify();

    try {
      final pickedContactId = await FlutterContacts.native.showPicker();

      if (pickedContactId == null || pickedContactId.trim().isEmpty) {
        errorMessage = '';
        successMessage = '';
        return false;
      }

      final permission = await FlutterContacts.permissions.request(
        PermissionType.read,
      );

      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.limited) {
        errorMessage = 'contacts.errors.contacts_permission_denied';
        successMessage = '';
        return false;
      }

      final contact = await FlutterContacts.get(
        pickedContactId,
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      if (contact == null) {
        errorMessage = 'contacts.errors.import_read_failed';
        successMessage = '';
        return false;
      }

      final importedName = _extractContactName(contact);
      final importedPhone = _extractBestJordanPhone(contact);

      if (importedName.isNotEmpty) {
        nameController.text = importedName;
      }

      if (importedPhone == null) {
        errorMessage = importedName.isNotEmpty
            ? 'contacts.errors.import_phone_required'
            : 'contacts.errors.import_data_failed';
        successMessage = '';
        _safeNotify();
        return false;
      }

      if (_isDuplicatePhone(importedPhone)) {
        phoneController.text = importedPhone;
        errorMessage = 'contacts.validation.duplicate_phone';
        successMessage = '';
        _safeNotify();
        return false;
      }

      phoneController.text = importedPhone;

      errorMessage = '';
      successMessage = 'contacts.messages.imported_review';
      _safeNotify();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ContactsViewModel importContactFromPhone error: $e');
      debugPrintStack(stackTrace: stackTrace);

      errorMessage = 'contacts.errors.import_failed';
      successMessage = '';
      return false;
    } finally {
      isImportingFromPhone = false;
      _safeNotify();
    }
  }

  String _extractContactName(Contact contact) {
    final displayName = _cleanText(contact.displayName);

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final name = contact.name;

    final first = _cleanText(name?.first);
    final middle = _cleanText(name?.middle);
    final last = _cleanText(name?.last);

    return [first, middle, last]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _extractBestJordanPhone(Contact contact) {
    if (contact.phones.isEmpty) return null;

    for (final phone in contact.phones) {
      final normalized = normalizeJordanPhone(phone.number);
      if (normalized != null) return normalized;
    }

    return null;
  }

  /// يستخدم عند استيراد جهة من أي مصدر خارجي لاحقاً.
  void prefillImportedContact({required String name, required String phone}) {
    nameController.text = _cleanText(name);

    final normalizedPhone = normalizeJordanPhone(phone);
    phoneController.text = normalizedPhone ?? phone.trim();

    errorMessage = normalizedPhone == null
        ? 'contacts.validation.review_phone'
        : '';

    successMessage = '';
    _safeNotify();
  }

  // ==========================================
  // Validation
  // ==========================================

  String? validateForm() {
    final name = _cleanText(nameController.text);
    final phone = phoneController.text.trim();

    if (name.isEmpty) {
      return 'contacts.validation.name_required';
    }

    if (name.length < 2) {
      return 'contacts.validation.name_too_short';
    }

    if (_containsDigits(name)) {
      return 'contacts.validation.name_has_digits';
    }

    final normalizedPhone = normalizeJordanPhone(phone);

    if (normalizedPhone == null) {
      return 'contacts.validation.invalid_phone';
    }

    if (_isDuplicatePhone(normalizedPhone)) {
      return 'contacts.validation.duplicate_phone';
    }

    if (!relations.contains(selectedRelation)) {
      return 'contacts.validation.invalid_relation';
    }

    return null;
  }

  String? validateContact(EmergencyContactModel contact) {
    final name = _cleanText(contact.name);

    if (name.length < 2) {
      return 'contacts.validation.name_too_short';
    }

    if (_containsDigits(name)) {
      return 'contacts.validation.name_has_digits';
    }

    if (normalizeJordanPhone(contact.phone) == null) {
      return 'contacts.validation.invalid_phone';
    }

    if (!EmergencyContactRelations.isKnownRelation(contact.relation)) {
      return 'contacts.validation.invalid_relation';
    }

    return null;
  }

  /// يوحّد رقم الهاتف لصيغة دولية أردنية واحدة.
  String? normalizeJordanPhone(String input) {
    var phone = _normalizeArabicDigits(input.trim());

    if (phone.isEmpty) return null;

    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    if (phone.startsWith('962')) {
      phone = '+$phone';
    }

    if (RegExp(r'^07[789]\d{7}$').hasMatch(phone)) {
      return '+962${phone.substring(1)}';
    }

    if (RegExp(r'^\+9627[789]\d{7}$').hasMatch(phone)) {
      return phone;
    }

    return null;
  }

  // ==========================================
  // Persistence / Sync
  // ==========================================

  Future<bool> _persistContactsLocallyThenSync(
    List<EmergencyContactModel> updatedContacts, {
    required String successText,
    bool quietSuccess = false,
  }) async {
    isSaving = true;
    errorMessage = '';
    successMessage = '';
    _safeNotify();

    final previousContacts = List<EmergencyContactModel>.from(contacts);

    try {
      contacts = _reindexContacts(updatedContacts);

      await _cacheContactsLocally(contacts);
      await _setPendingSync(true);

      final cloudSynced = await _syncContactsToCloud(showUserMessage: false);

      if (cloudSynced) {
        successMessage = quietSuccess ? '' : successText;
      } else {
        successMessage = quietSuccess
            ? ''
            : 'contacts.messages.local_saved_pending_sync';
      }

      errorMessage = '';
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ContactsViewModel local persist error: $e');
      debugPrintStack(stackTrace: stackTrace);

      contacts = previousContacts;

      errorMessage = 'contacts.errors.save_failed';
      successMessage = '';

      return false;
    } finally {
      isSaving = false;
      _safeNotify();
    }
  }

  Future<void> _cacheContactsLocally(
    List<EmergencyContactModel> contactsToCache,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      contactsToCache.map((contact) => contact.toMap()).toList(),
    );

    await prefs.setString(_localCacheKey, encoded);
  }

  Future<bool> _syncContactsToCloud({bool showUserMessage = true}) async {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      await _setPendingSync(true);

      if (showUserMessage) {
        errorMessage = 'contacts.errors.login_required_sync';
        successMessage = '';
      }

      return false;
    }

    isSyncingWithCloud = true;
    _safeNotify();

    try {
      final orderedContacts = _reindexContacts(contacts);

      final primary = orderedContacts.isNotEmpty
          ? orderedContacts.first.toSnapshot()
          : <String, dynamic>{};

      final extras = orderedContacts.length > 1
          ? orderedContacts
                .skip(1)
                .map((contact) => contact.toSnapshot())
                .toList()
          : <Map<String, dynamic>>[];

      final result = await _firebaseService
          .updateUser(currentUser.uid, {
            'primaryEmergencyContact': primary,
            'extraEmergencyContacts': extras,
            'hasEmergencyContacts': orderedContacts.isNotEmpty,
            'emergencyContactsUpdatedAt': _firebaseService.serverTimestamp,
          })
          .timeout(_saveTimeout);

      if (result.isFailure) {
        debugPrint('⚠️ ContactsViewModel cloud sync failed: ${result.error}');
        await _setPendingSync(true);

        if (showUserMessage) {
          errorMessage = '';
          successMessage = 'contacts.messages.local_saved_pending_sync';
        }

        return false;
      }

      await _setPendingSync(false);

      if (showUserMessage) {
        errorMessage = '';
      }

      return true;
    } on TimeoutException {
      debugPrint('⏱️ ContactsViewModel: cloud sync timeout');
      await _setPendingSync(true);

      if (showUserMessage) {
        errorMessage = '';
        successMessage = 'contacts.messages.local_saved_pending_sync';
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ ContactsViewModel cloud sync error: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _setPendingSync(true);

      if (showUserMessage) {
        errorMessage = '';
        successMessage = 'contacts.messages.local_saved_pending_sync';
      }

      return false;
    } finally {
      isSyncingWithCloud = false;
      _safeNotify();
    }
  }

  Future<void> syncPendingContactsIfNeeded() async {
    hasPendingCloudSync = await _loadPendingSyncFlag();

    if (!hasPendingCloudSync) return;

    await _syncContactsToCloud(showUserMessage: false);
  }

  Future<bool> _loadPendingSyncFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingSyncKey) ?? false;
  }

  Future<void> _setPendingSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSyncKey, value);

    hasPendingCloudSync = value;
  }

  // ==========================================
  // Form Helpers
  // ==========================================

  void setRelation(String relation) {
    selectedRelation = EmergencyContactRelations.normalize(relation);
    _safeNotify();
  }

  void clearForm() {
    nameController.clear();
    phoneController.clear();
    selectedRelation = EmergencyContactRelations.father;
  }

  void prepareAddForm() {
    clearForm();
    errorMessage = '';
    successMessage = '';
    _safeNotify();
  }

  void clearMessages() {
    errorMessage = '';
    successMessage = '';
    _safeNotify();
  }

  // ==========================================
  // Internal Helpers
  // ==========================================

  List<EmergencyContactModel> _reindexContacts(
    List<EmergencyContactModel> input,
  ) {
    final uniqueContacts = <EmergencyContactModel>[];
    final seenPhones = <String>{};

    for (final contact in input) {
      final normalizedPhone = normalizeJordanPhone(contact.phone);
      final normalizedName = _cleanText(contact.name);

      if (normalizedName.isEmpty) continue;
      if (normalizedPhone == null) continue;
      if (seenPhones.contains(normalizedPhone)) continue;

      seenPhones.add(normalizedPhone);

      uniqueContacts.add(
        contact.copyWith(name: normalizedName, phone: normalizedPhone),
      );
    }

    final limited = uniqueContacts.take(maxContacts).toList();

    return List<EmergencyContactModel>.generate(limited.length, (index) {
      return limited[index].copyWith(priority: index + 1);
    });
  }

  bool _isDuplicatePhone(String normalizedPhone) {
    return contacts.any((contact) {
      return normalizeJordanPhone(contact.phone) == normalizedPhone;
    });
  }

  bool _containsDigits(String value) {
    return RegExp(r'\d').hasMatch(_normalizeArabicDigits(value));
  }

  String _normalizeArabicDigits(String value) {
    const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const easternArabicIndic = [
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    var result = value;

    for (var i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(arabicIndic[i], englishDigits[i]);
      result = result.replaceAll(easternArabicIndic[i], englishDigits[i]);
    }

    return result;
  }

  String _cleanText(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;

    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;

    nameController.dispose();
    phoneController.dispose();

    super.dispose();
  }
}
