import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/services/firebase_auth_service.dart';
import '../models/accident_evidence_model.dart';
import '../models/driver_license_model.dart';
import '../models/generated_report_model.dart';
import '../models/kroka_damage_zone.dart';
import '../models/vehicle_plate_model.dart';
import '../repositories/kroka_repository.dart';
import '../services/evidence_capture_service.dart';
import '../services/jordan_plate_validator.dart';
import '../services/kroka_storage_service.dart';
import '../services/license_scan_service.dart';
import '../services/plate_ocr_service.dart';
import '../services/pdf_report_service.dart';

class KrokaViewModel extends ChangeNotifier {
  KrokaViewModel({
    FirebaseAuthService? authService,
    LocationService? locationService,
    GeocodingService? geocodingService,
    JordanPlateValidator? plateValidator,
    KrokaRepository? repository,
    EvidenceCaptureService? evidenceCaptureService,
    KrokaStorageService? storageService,
    PlateOcrService? plateOcrService,
    LicenseScanService? licenseScanService,
    PdfReportService? pdfReportService,
    NotificationService? notificationService,
  }) : _authService = authService ?? FirebaseAuthService(),
       _locationService = locationService ?? const LocationService(),
       _geocodingService = geocodingService ?? GeocodingService(),
       _plateValidator = plateValidator ?? const JordanPlateValidator(),
       _repository = repository ?? KrokaRepository(),
       _evidenceCaptureService =
           evidenceCaptureService ?? const EvidenceCaptureService(),
       _storageService = storageService ?? KrokaStorageService(),
       _plateOcrService = plateOcrService ?? PlateOcrService(),
       _licenseScanService = licenseScanService ?? LicenseScanService(),
       _pdfReportService = pdfReportService ?? const PdfReportService(),
       _notificationService = notificationService ?? NotificationService(),
       _ownsNotificationService = notificationService == null {
    _attachFieldListeners();
    refreshLocation();
  }

  final FirebaseAuthService _authService;
  final LocationService _locationService;
  final GeocodingService _geocodingService;
  final JordanPlateValidator _plateValidator;
  final KrokaRepository _repository;
  final EvidenceCaptureService _evidenceCaptureService;
  final KrokaStorageService _storageService;
  final PlateOcrService _plateOcrService;
  final LicenseScanService _licenseScanService;
  final PdfReportService _pdfReportService;
  final NotificationService _notificationService;
  final bool _ownsNotificationService;

  static final Set<String> _validDamageZoneIds = KrokaDamageZone.values
      .map((zone) => zone.id)
      .toSet();

  /// All currently selected damage zone IDs (multi-select).
  ///
  /// Stored as an insertion-ordered linked-hash-set equivalent via a List
  /// that is wrapped in a Set for O(1) contains checks.
  final Set<String> selectedDamageZoneIds = {};

  /// Backward-compatible read for callers that expect a single zone.
  /// Returns the first selected zone ID, or empty string if none selected.
  String get selectedHitPoint {
    return selectedDamageZoneIds.isEmpty ? '' : selectedDamageZoneIds.first;
  }

  static const Set<String> _validFaultStatuses = {'me', 'other', 'unknown'};

  static const int _maxNotesLength = 500;

  final myCarCodeController = TextEditingController();
  final myCarNumController = TextEditingController();

  final otherCarCodeController = TextEditingController();
  final otherCarNumController = TextEditingController();

  final notesController = TextEditingController();

  String faultStatus = '';

  bool isLocationLoading = false;
  bool isLocationFetched = false;
  bool isSubmitting = false;
  bool isReportSubmitted = false;
  bool isEvidenceUpdating = false;
  bool isEvidenceCapturing = false;
  bool isDraftCreating = false;
  bool isPlateScanning = false;
  bool isLicenseScanning = false;
  bool isPdfGenerating = false;

  String? locationErrorKey;
  String? validationErrorKey;
  String? submissionErrorKey;
  String? evidenceErrorKey;
  String? draftErrorKey;
  String? plateScanErrorKey;
  String? licenseScanErrorKey;
  String? pdfReportErrorKey;

  String? submittedReportId;
  String? submittedReferenceCode;

  String? draftReportId;
  String? draftReferenceCode;

  GeneratedReportModel? generatedReport;

  String? _localEvidenceSessionId;

  CapturedEvidenceFile? _pendingEvidenceFile;
  String? _pendingEvidencePurpose;
  String? _pendingEvidenceSourceLabel;

  Position? _capturedPosition;
  DateTime? _locationCapturedAtClient;
  String? _locationName;

  final List<AccidentEvidenceModel> _evidenceItems = [];

  VehiclePlateModel? _lastMyScannedPlate;
  VehiclePlateModel? _lastOtherScannedPlate;

  DriverLicenseModel? _myDriverLicense;
  DriverLicenseModel? _otherDriverLicense;

  bool _isDisposed = false;

  Position? get capturedPosition => _capturedPosition;

  DateTime? get locationCapturedAtClient => _locationCapturedAtClient;

  double? get capturedLatitude => _capturedPosition?.latitude;

  double? get capturedLongitude => _capturedPosition?.longitude;

  double? get locationAccuracyMeters => _capturedPosition?.accuracy;

  String? get locationName => _locationName;

  List<AccidentEvidenceModel> get evidenceItems {
    return List<AccidentEvidenceModel>.unmodifiable(_evidenceItems);
  }

  int get evidenceCount => _evidenceItems.length;

  bool get hasEvidence => _evidenceItems.isNotEmpty;

  bool get hasPendingEvidenceSelection => _pendingEvidenceFile?.isValid == true;

  String get pendingEvidenceFileName {
    return _pendingEvidenceFile?.fileName.trim() ?? '';
  }

  int? get pendingEvidenceSizeBytes => _pendingEvidenceFile?.sizeBytes;

  String get pendingEvidenceTypeLabelKey {
    switch (_pendingEvidenceFile?.type) {
      case AccidentEvidenceType.image:
        return 'kroka.evidence.types.images';
      case AccidentEvidenceType.video:
        return 'kroka.evidence.types.videos';
      case AccidentEvidenceType.audio:
        return 'kroka.evidence.types.audio';
      default:
        return 'kroka.evidence.types.files';
    }
  }

  String get pendingEvidenceSourceLabelKey {
    switch (_pendingEvidenceFile?.captureSource) {
      case AccidentEvidenceCaptureSource.camera:
        return 'kroka.evidence.sources.camera';
      case AccidentEvidenceCaptureSource.gallery:
        return 'kroka.evidence.sources.gallery';
      case AccidentEvidenceCaptureSource.filePicker:
        return 'kroka.evidence.sources.file';
      default:
        return 'kroka.evidence.sources.unknown';
    }
  }

  bool get canAddPendingEvidence {
    return hasPendingEvidenceSelection &&
        !isEvidenceBusy &&
        !isDraftCreating &&
        !isSubmitting &&
        !isReportSubmitted;
  }

  bool get hasUploadedEvidence {
    return _evidenceItems.any((evidence) => evidence.isUploaded);
  }

  bool get isImageCaptured {
    return _evidenceItems.any(
      (evidence) => evidence.type == AccidentEvidenceType.image,
    );
  }

  /// Evidence capture is available through the configured capture service.
  /// The current implementation supports selecting image, video, and audio
  /// files, then uploading them to Firebase Storage and linking them to the
  /// active Kroka draft report.
  bool get hasEvidenceCaptureSupport => true;

  bool get isEvidenceBusy => isEvidenceCapturing || isEvidenceUpdating;

  DriverLicenseModel? get myDriverLicense => _myDriverLicense;

  DriverLicenseModel? get otherDriverLicense => _otherDriverLicense;

  bool get hasMyDriverLicense => _myDriverLicense?.isScanned == true;

  bool get hasOtherDriverLicense => _otherDriverLicense?.isScanned == true;

  bool get hasAnyDriverLicenseStatus {
    return _myDriverLicense != null || _otherDriverLicense != null;
  }

  bool get hasGeneratedPdfReport => generatedReport?.isValid == true;

  String? get generatedPdfUrl => generatedReport?.downloadUrl;

  bool get canGeneratePdfReport {
    return isReportSubmitted &&
        submittedReportId != null &&
        submittedReferenceCode != null &&
        !isPdfGenerating &&
        !isSubmitting;
  }

  bool get canScanDriverLicense {
    return !isLicenseScanning &&
        !isSubmitting &&
        !isDraftCreating &&
        !isEvidenceUpdating &&
        !isEvidenceCapturing &&
        !isPlateScanning &&
        !isPdfGenerating &&
        !isReportSubmitted;
  }

  bool get hasDraftReport {
    return draftReportId != null && draftReportId!.trim().isNotEmpty;
  }

  bool get hasDraftReference {
    return draftReferenceCode != null && draftReferenceCode!.trim().isNotEmpty;
  }

  bool get canCreateDraft {
    return !isDraftCreating && !isSubmitting && !isReportSubmitted;
  }

  /// Primary selected damage zone (first in the set), or null.
  KrokaDamageZone? get selectedDamageZone {
    if (selectedDamageZoneIds.isEmpty) return null;
    return KrokaDamageZone.maybeFromId(selectedDamageZoneIds.first);
  }

  /// All currently selected zones as typed objects.
  List<KrokaDamageZone> get selectedDamageZones {
    return selectedDamageZoneIds
        .map(KrokaDamageZone.maybeFromId)
        .whereType<KrokaDamageZone>()
        .toList(growable: false);
  }

  /// Returns true if the given zone ID is currently selected.
  bool isDamageZoneSelected(String id) {
    return selectedDamageZoneIds.contains(id.trim());
  }

  String get selectedDamageSide {
    return selectedDamageZone?.side ?? '';
  }

  String get selectedDamageLabelKey {
    if (selectedDamageZoneIds.isEmpty) {
      return 'kroka.review.not_ready';
    }
    if (selectedDamageZoneIds.length == 1) {
      return selectedDamageZone?.labelKey ?? 'kroka.review.not_ready';
    }
    return 'kroka.damage.multiple_selected';
  }

  String? get activeErrorKey {
    return submissionErrorKey ??
        evidenceErrorKey ??
        draftErrorKey ??
        plateScanErrorKey ??
        licenseScanErrorKey ??
        pdfReportErrorKey ??
        validationErrorKey ??
        locationErrorKey;
  }

  bool get hasCapturedLocation {
    return _capturedPosition != null && _locationCapturedAtClient != null;
  }

  bool get hasSelectedDamagePoint {
    return selectedDamageZoneIds.isNotEmpty &&
        selectedDamageZoneIds.every(_validDamageZoneIds.contains);
  }

  bool get hasSelectedFaultStatus {
    return _validFaultStatuses.contains(faultStatus.trim());
  }

  bool get hasMyVehiclePlateInput {
    return myCarCodeController.text.trim().isNotEmpty &&
        myCarNumController.text.trim().isNotEmpty;
  }

  bool get hasOptionalOtherVehiclePlateInput {
    return otherCarCodeController.text.trim().isNotEmpty ||
        otherCarNumController.text.trim().isNotEmpty;
  }

  bool get canScanPlate {
    return !isPlateScanning &&
        !isSubmitting &&
        !isDraftCreating &&
        !isEvidenceUpdating &&
        !isEvidenceCapturing &&
        !isLicenseScanning &&
        !isPdfGenerating &&
        !isReportSubmitted;
  }

  bool get hasMyPlateOcrScan {
    return _lastMyScannedPlate != null &&
        _lastMyScannedPlate!.normalizedKey ==
            VehiclePlateModel.buildNormalizedKey(
              code: int.tryParse(myCarCodeController.text.trim()) ?? -1,
              number: int.tryParse(myCarNumController.text.trim()) ?? -1,
            );
  }

  bool get hasOtherPlateOcrScan {
    return _lastOtherScannedPlate != null &&
        _lastOtherScannedPlate!.normalizedKey ==
            VehiclePlateModel.buildNormalizedKey(
              code: int.tryParse(otherCarCodeController.text.trim()) ?? -1,
              number: int.tryParse(otherCarNumController.text.trim()) ?? -1,
            );
  }

  String get myPlateOcrSourceLabelKey {
    return _plateOcrSourceLabelKey(_lastMyScannedPlate?.source);
  }

  String get otherPlateOcrSourceLabelKey {
    return _plateOcrSourceLabelKey(_lastOtherScannedPlate?.source);
  }

  bool get isBasicFormComplete {
    return hasCapturedLocation &&
        hasSelectedDamagePoint &&
        hasSelectedFaultStatus &&
        hasMyVehiclePlateInput;
  }

  bool get canSubmit {
    return !isSubmitting &&
        !isLocationLoading &&
        !isEvidenceUpdating &&
        !isEvidenceCapturing &&
        !isDraftCreating &&
        !isPlateScanning &&
        !isLicenseScanning &&
        !isPdfGenerating &&
        !isReportSubmitted &&
        isBasicFormComplete;
  }

  bool get canUpdateSubmittedEvidence {
    return !isSubmitting &&
        !isEvidenceUpdating &&
        !isEvidenceCapturing &&
        !isDraftCreating &&
        !isPlateScanning &&
        !isLicenseScanning &&
        !isPdfGenerating &&
        isReportSubmitted &&
        submittedReportId != null;
  }

  String getLocationName() {
    final safeLocationName = _locationName?.trim();

    if (safeLocationName != null && safeLocationName.isNotEmpty) {
      return safeLocationName;
    }

    final position = _capturedPosition;
    if (position == null || !_isUsablePosition(position)) {
      return '';
    }

    return '${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
  }

  /// Compatibility only for older UI references.
  /// This does not represent police patrol arrival time.
  String getEstimatedArrivalTime() {
    return submittedReferenceCode ?? draftReferenceCode ?? '';
  }

  List<String> get missingRequirementKeys {
    final missing = <String>[];

    if (!hasCapturedLocation) {
      missing.add('kroka.errors.location_required');
    }

    if (!hasSelectedDamagePoint) {
      missing.add('kroka.errors.damage_required');
    }

    if (!hasSelectedFaultStatus) {
      missing.add('kroka.errors.fault_required');
    }

    if (!hasMyVehiclePlateInput) {
      missing.add('kroka.errors.plate_required');
    }

    return missing;
  }

  KrokaReviewState get reviewState {
    return KrokaReviewState(
      isLocationReady: hasCapturedLocation,
      isDamageReady: hasSelectedDamagePoint,
      isFaultReady: hasSelectedFaultStatus,
      isMyPlateReady: hasMyVehiclePlateInput,
      isOtherPlateProvided: hasOptionalOtherVehiclePlateInput,
      hasEvidence: hasEvidence,
      evidenceCount: evidenceCount,
      damageLabelKey: selectedDamageLabelKey,
      selectedDamageZoneIds: Set<String>.unmodifiable(selectedDamageZoneIds),
      faultLabelKey: _faultLabelKey,
      myPlatePreview: _validatedPlatePreview(
        rawCode: myCarCodeController.text,
        rawNumber: myCarNumController.text,
        required: true,
      ),
      otherPlatePreview: _validatedPlatePreview(
        rawCode: otherCarCodeController.text,
        rawNumber: otherCarNumController.text,
        required: false,
      ),
      locationPreview: getLocationName(),
    );
  }

  String get _faultLabelKey {
    switch (faultStatus.trim()) {
      case 'me':
        return 'kroka.fault.me';
      case 'other':
        return 'kroka.fault.other';
      case 'unknown':
        return 'kroka.fault.unknown';
      default:
        return 'kroka.review.not_ready';
    }
  }

  String? _validatedPlatePreview({
    required String rawCode,
    required String rawNumber,
    required bool required,
  }) {
    final result = _plateValidator.validate(
      rawCode: rawCode,
      rawNumber: rawNumber,
      required: required,
    );

    if (result.isOptionalEmpty) return null;

    return result.plate?.displayLabel;
  }

  /// Toggles a damage zone in/out of [selectedDamageZoneIds].
  ///
  /// If the zone is already selected it is removed (deselect).
  /// If it is not selected it is added.
  void toggleDamageZone(String id) {
    final safeId = id.trim();

    if (!_validDamageZoneIds.contains(safeId)) {
      validationErrorKey = 'kroka.errors.invalid_damage_point';
      _safeNotifyListeners();
      return;
    }

    _clearTransientErrors();

    if (selectedDamageZoneIds.contains(safeId)) {
      selectedDamageZoneIds.remove(safeId);
    } else {
      selectedDamageZoneIds.add(safeId);
    }

    _safeNotifyListeners();
  }

  /// Backward-compatible alias for [toggleDamageZone].
  void selectHitPoint(String point) => toggleDamageZone(point);

  void selectFaultStatus(String status) {
    final safeStatus = status.trim();

    if (!_validFaultStatuses.contains(safeStatus)) {
      validationErrorKey = 'kroka.errors.invalid_fault_status';
      _safeNotifyListeners();
      return;
    }

    _clearTransientErrors();

    if (faultStatus == safeStatus) {
      _safeNotifyListeners();
      return;
    }

    faultStatus = safeStatus;
    _safeNotifyListeners();
  }

  Future<bool> scanMyVehiclePlate() {
    return scanMyVehiclePlateFromGallery();
  }

  Future<bool> scanOtherVehiclePlate() {
    return scanOtherVehiclePlateFromGallery();
  }

  Future<bool> scanMyVehiclePlateFromCamera() {
    return _scanVehiclePlate(
      isMineVehicle: true,
      source: PlateOcrImageSource.camera,
    );
  }

  Future<bool> scanMyVehiclePlateFromGallery() {
    return _scanVehiclePlate(
      isMineVehicle: true,
      source: PlateOcrImageSource.gallery,
    );
  }

  Future<bool> scanOtherVehiclePlateFromCamera() {
    return _scanVehiclePlate(
      isMineVehicle: false,
      source: PlateOcrImageSource.camera,
    );
  }

  Future<bool> scanOtherVehiclePlateFromGallery() {
    return _scanVehiclePlate(
      isMineVehicle: false,
      source: PlateOcrImageSource.gallery,
    );
  }

  Future<bool> _scanVehiclePlate({
    required bool isMineVehicle,
    required String source,
  }) async {
    if (!canScanPlate) return false;

    _clearTransientErrors();

    isPlateScanning = true;
    plateScanErrorKey = null;
    licenseScanErrorKey = null;
    _safeNotifyListeners();

    try {
      final result = source == PlateOcrImageSource.camera
          ? await _plateOcrService.captureAndReadVehiclePlateFromCamera()
          : await _plateOcrService.pickAndReadVehiclePlateFromGallery();

      if (result.isCancelled) {
        return true;
      }

      final scannedPlate = result.plate;

      if (!result.isSuccess || scannedPlate == null) {
        plateScanErrorKey = _mapPlateOcrFailureCode(result.errorCode);
        return false;
      }

      if (isMineVehicle) {
        _lastMyScannedPlate = scannedPlate;
        myCarCodeController.text = scannedPlate.code.toString();
        myCarNumController.text = scannedPlate.number.toString();
      } else {
        _lastOtherScannedPlate = scannedPlate;
        otherCarCodeController.text = scannedPlate.code.toString();
        otherCarNumController.text = scannedPlate.number.toString();
      }

      await _uploadPlateScanEvidenceSafely(
        result: result,
        scannedPlate: scannedPlate,
        isMineVehicle: isMineVehicle,
      );

      plateScanErrorKey = null;
      licenseScanErrorKey = null;
      pdfReportErrorKey = null;
      return true;
    } catch (_) {
      plateScanErrorKey = 'kroka.errors.plate_ocr_failed';
      return false;
    } finally {
      isPlateScanning = false;
      _safeNotifyListeners();
    }
  }

  bool addUploadedEvidence(AccidentEvidenceModel evidence) {
    if (!_isReportSafeEvidence(evidence)) {
      evidenceErrorKey = 'kroka.errors.invalid_evidence';
      _safeNotifyListeners();
      return false;
    }

    _clearTransientErrors();

    final safeId = evidence.id.trim();

    if (safeId.isEmpty) {
      evidenceErrorKey = 'kroka.errors.invalid_evidence';
      _safeNotifyListeners();
      return false;
    }

    final existingIndex = _evidenceItems.indexWhere(
      (item) => item.id.trim() == safeId,
    );

    if (existingIndex >= 0) {
      _evidenceItems[existingIndex] = evidence;
    } else {
      _evidenceItems.add(evidence);
    }

    _sortEvidenceItems();
    _safeNotifyListeners();

    return true;
  }

  bool removeEvidence(String evidenceId) {
    final safeEvidenceId = evidenceId.trim();

    if (safeEvidenceId.isEmpty) {
      evidenceErrorKey = 'kroka.errors.invalid_evidence';
      _safeNotifyListeners();
      return false;
    }

    final beforeCount = _evidenceItems.length;

    _evidenceItems.removeWhere(
      (evidence) => evidence.id.trim() == safeEvidenceId,
    );

    final removed = _evidenceItems.length != beforeCount;

    if (!removed) {
      evidenceErrorKey = 'kroka.errors.evidence_not_found';
      _safeNotifyListeners();
      return false;
    }

    _clearTransientErrors();
    _safeNotifyListeners();

    return true;
  }

  void clearEvidence() {
    if (_evidenceItems.isEmpty && !hasPendingEvidenceSelection) return;

    _evidenceItems.clear();
    _pendingEvidenceFile = null;
    _pendingEvidencePurpose = null;
    _pendingEvidenceSourceLabel = null;
    evidenceErrorKey = null;
    _safeNotifyListeners();
  }

  Future<bool> refreshLocation() async {
    if (isLocationLoading) return hasCapturedLocation;

    isLocationLoading = true;
    locationErrorKey = null;
    submissionErrorKey = null;

    if (!hasCapturedLocation) {
      isLocationFetched = false;
    }

    _safeNotifyListeners();

    try {
      final position = await _locationService.getCurrentPosition();

      if (position == null || !_isUsablePosition(position)) {
        if (!hasCapturedLocation) {
          isLocationFetched = false;
        }

        locationErrorKey = 'kroka.errors.location_unavailable';
        return false;
      }

      _capturedPosition = position;
      _locationCapturedAtClient = _safePositionTimestamp(position);
      isLocationFetched = true;

      _locationName = await _resolveLocationName(position);
      locationErrorKey = null;

      return true;
    } catch (_) {
      if (!hasCapturedLocation) {
        isLocationFetched = false;
      }

      locationErrorKey = 'kroka.errors.location_unavailable';
      return false;
    } finally {
      isLocationLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> ensureDraftReport() async {
    if (hasDraftReport && hasDraftReference) {
      return true;
    }

    if (!canCreateDraft) {
      return false;
    }

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();

    if (userId == null || userId.isEmpty) {
      draftErrorKey = 'kroka.errors.user_not_signed_in';
      _safeNotifyListeners();
      return false;
    }

    isDraftCreating = true;
    draftErrorKey = null;
    _safeNotifyListeners();

    try {
      final result = await _repository.createDraftReport(userId: userId);

      if (result.isFailure || result.data == null) {
        draftErrorKey = _mapDraftFailureCode(result.error?.code);
        return false;
      }

      final draft = result.data!;

      draftReportId = draft.reportId;
      draftReferenceCode = draft.referenceCode;
      draftErrorKey = null;

      return true;
    } catch (_) {
      draftErrorKey = 'kroka.errors.draft_create_failed';
      return false;
    } finally {
      isDraftCreating = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> updateDraftReportEvidence() async {
    if (isEvidenceUpdating) return false;

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();

    if (userId == null || userId.isEmpty) {
      evidenceErrorKey = 'kroka.errors.user_not_signed_in';
      _safeNotifyListeners();
      return false;
    }

    final draftReady = await ensureDraftReport();

    if (!draftReady) {
      evidenceErrorKey = draftErrorKey ?? 'kroka.errors.draft_create_failed';
      _safeNotifyListeners();
      return false;
    }

    final reportId = draftReportId?.trim();

    if (reportId == null || reportId.isEmpty) {
      evidenceErrorKey = 'kroka.errors.draft_not_found';
      _safeNotifyListeners();
      return false;
    }

    isEvidenceUpdating = true;
    evidenceErrorKey = null;
    _safeNotifyListeners();

    try {
      final result = await _repository.updateReportEvidence(
        reportId: reportId,
        userId: userId,
        evidenceItems: _reportSafeEvidenceItems(),
      );

      if (result.isFailure || result.data == null) {
        evidenceErrorKey = _mapEvidenceFailureCode(result.error?.code);
        return false;
      }

      evidenceErrorKey = null;
      return true;
    } catch (_) {
      evidenceErrorKey = 'kroka.errors.evidence_update_failed';
      return false;
    } finally {
      isEvidenceUpdating = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> submitReport() async {
    if (isSubmitting) return false;

    if (isReportSubmitted) {
      return submittedReportId != null && submittedReferenceCode != null;
    }

    _clearSubmitErrors();

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();

    if (userId == null || userId.isEmpty) {
      validationErrorKey = 'kroka.errors.user_not_signed_in';
      _safeNotifyListeners();
      return false;
    }

    final locationReady = await _ensureLocationReady();

    if (!locationReady) {
      validationErrorKey = 'kroka.errors.location_required';
      _safeNotifyListeners();
      return false;
    }

    final form = _validateForm();

    if (form == null) {
      _safeNotifyListeners();
      return false;
    }

    final position = _capturedPosition;
    final locationCapturedAt = _locationCapturedAtClient;

    if (position == null ||
        locationCapturedAt == null ||
        !_isUsablePosition(position)) {
      validationErrorKey = 'kroka.errors.location_required';
      _safeNotifyListeners();
      return false;
    }

    final existingDraftReportId = hasDraftReport ? draftReportId : null;

    isSubmitting = true;
    _safeNotifyListeners();

    try {
      // Use the primary (first) selected zone as the canonical zone for the
      // report record; all zones are also included via damageZoneIds.
      final primaryZoneId = selectedDamageZoneIds.isNotEmpty
          ? selectedDamageZoneIds.first
          : '';

      final result = await _repository.submitReport(
        userId: userId,
        damageZoneId: primaryZoneId,
        damageZoneIds: selectedDamageZoneIds.toList(growable: false),
        faultEstimate: faultStatus,
        myVehiclePlate: form.myVehiclePlate,
        otherVehiclePlate: form.otherVehiclePlate,
        position: position,
        locationName: _locationName,
        notes: form.notes,
        evidenceItems: _reportSafeEvidenceItems(),
        myDriverLicense: _reportSafeDriverLicense(_myDriverLicense),
        otherDriverLicense: _reportSafeDriverLicense(_otherDriverLicense),
        draftReportId: existingDraftReportId,
        locationCapturedAtClient: locationCapturedAt,
      );

      if (result.isFailure || result.data == null) {
        submissionErrorKey = _mapSubmitFailureCode(result.error?.code);
        return false;
      }

      final submission = result.data!;

      submittedReportId = submission.reportId;
      submittedReferenceCode = submission.referenceCode;

      draftReportId = null;
      draftReferenceCode = null;
      draftErrorKey = null;
      _localEvidenceSessionId = null;

      isReportSubmitted = true;
      submissionErrorKey = null;
      validationErrorKey = null;
      evidenceErrorKey = null;
      pdfReportErrorKey = null;

      await _generateSubmittedPdfReport(
        userId: userId,
        reportId: submission.reportId,
        referenceCode: submission.referenceCode,
        form: form,
        position: position,
        locationCapturedAt: locationCapturedAt,
      );

      unawaited(
        _sendKrokaSavedNotificationSafely(
          reportId: submission.reportId,
          referenceCode: submission.referenceCode,
        ),
      );

      return true;
    } catch (_) {
      submissionErrorKey = 'kroka.errors.submit_failed';
      return false;
    } finally {
      isSubmitting = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> updateSubmittedReportEvidence() async {
    if (isEvidenceUpdating) return false;

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();

    if (userId == null || userId.isEmpty) {
      evidenceErrorKey = 'kroka.errors.user_not_signed_in';
      _safeNotifyListeners();
      return false;
    }

    final reportId = submittedReportId?.trim();

    if (reportId == null || reportId.isEmpty || !isReportSubmitted) {
      evidenceErrorKey = 'kroka.errors.report_not_submitted';
      _safeNotifyListeners();
      return false;
    }

    isEvidenceUpdating = true;
    evidenceErrorKey = null;
    _safeNotifyListeners();

    try {
      final result = await _repository.updateReportEvidence(
        reportId: reportId,
        userId: userId,
        evidenceItems: _reportSafeEvidenceItems(),
      );

      if (result.isFailure || result.data == null) {
        evidenceErrorKey = _mapEvidenceFailureCode(result.error?.code);
        return false;
      }

      evidenceErrorKey = null;
      return true;
    } catch (_) {
      evidenceErrorKey = 'kroka.errors.evidence_update_failed';
      return false;
    } finally {
      isEvidenceUpdating = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> discardDraftIfEmpty() async {
    if (!hasDraftReport || hasEvidence || isReportSubmitted) {
      return true;
    }

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();
    final reportId = draftReportId?.trim();

    if (userId == null ||
        userId.isEmpty ||
        reportId == null ||
        reportId.isEmpty) {
      draftReportId = null;
      draftReferenceCode = null;
      draftErrorKey = null;
      _safeNotifyListeners();
      return true;
    }

    try {
      final result = await _repository.discardDraftReport(
        reportId: reportId,
        userId: userId,
      );

      if (result.isFailure) {
        draftErrorKey = _mapDraftFailureCode(result.error?.code);
        _safeNotifyListeners();
        return false;
      }

      draftReportId = null;
      draftReferenceCode = null;
      draftErrorKey = null;
      _safeNotifyListeners();

      return true;
    } catch (_) {
      draftErrorKey = 'kroka.errors.draft_discard_failed';
      _safeNotifyListeners();
      return false;
    }
  }

  Future<bool> selectImageEvidenceFromCamera() {
    return _capturePendingEvidenceFile(
      captureAction: _evidenceCaptureService.captureImageFromCamera,
      purpose: AccidentEvidencePurpose.damagePhoto,
      sourceLabel: AccidentEvidenceCaptureSource.camera,
    );
  }

  Future<bool> selectImageEvidenceFromGallery() {
    return _capturePendingEvidenceFile(
      captureAction: _evidenceCaptureService.pickImageFromGallery,
      purpose: AccidentEvidencePurpose.damagePhoto,
      sourceLabel: AccidentEvidenceCaptureSource.gallery,
    );
  }

  Future<bool> selectVideoEvidenceFromCamera() {
    return _capturePendingEvidenceFile(
      captureAction: _evidenceCaptureService.captureVideoFromCamera,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.camera,
    );
  }

  Future<bool> selectVideoEvidenceFromGallery() {
    return _capturePendingEvidenceFile(
      captureAction: _evidenceCaptureService.pickVideoFromGallery,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.gallery,
    );
  }

  Future<bool> selectVideoEvidenceFromFiles() {
    return _capturePendingEvidenceFile(
      captureAction: _evidenceCaptureService.pickVideoEvidenceFile,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.filePicker,
    );
  }

  Future<bool> selectAudioEvidenceFromFiles() {
    return _capturePendingEvidenceFile(
      captureAction: _evidenceCaptureService.pickAudioEvidenceFile,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.filePicker,
    );
  }

  void clearPendingEvidenceSelection() {
    if (!hasPendingEvidenceSelection) return;

    _pendingEvidenceFile = null;
    _pendingEvidencePurpose = null;
    _pendingEvidenceSourceLabel = null;
    evidenceErrorKey = null;
    _safeNotifyListeners();
  }

  Future<bool> uploadPendingEvidence() async {
    final pendingFile = _pendingEvidenceFile;

    if (pendingFile == null || !pendingFile.isValid) {
      evidenceErrorKey = 'kroka.errors.evidence_selection_required';
      _safeNotifyListeners();
      return false;
    }

    final purpose = _pendingEvidencePurpose ?? AccidentEvidencePurpose.general;
    final sourceLabel =
        _pendingEvidenceSourceLabel ?? pendingFile.captureSource;

    final result = await _uploadCapturedEvidenceFile(
      capturedFile: pendingFile,
      purpose: purpose,
      captureSource: pendingFile.captureSource,
      storageMetadata: {
        'source': 'guardian360_kroka',
        'evidencePurpose': purpose,
        'captureSource': pendingFile.captureSource,
      },
      evidenceMetadata: _buildEvidenceContextMetadata(
        capturedAtClient: pendingFile.capturedAtClient,
        extra: {
          'evidencePurpose': purpose,
          'captureSource': pendingFile.captureSource,
          'captureMethodLabel': sourceLabel,
          'addedAfterExplicitConfirmation': true,
        },
      ),
    );

    if (result) {
      _pendingEvidenceFile = null;
      _pendingEvidencePurpose = null;
      _pendingEvidenceSourceLabel = null;
      _safeNotifyListeners();
    }

    return result;
  }

  Future<bool> _capturePendingEvidenceFile({
    required Future<EvidenceCaptureResult> Function() captureAction,
    required String purpose,
    required String sourceLabel,
  }) async {
    if (isEvidenceBusy || isSubmitting || isReportSubmitted) {
      return false;
    }

    _clearTransientErrors();

    isEvidenceCapturing = true;
    evidenceErrorKey = null;
    _safeNotifyListeners();

    EvidenceCaptureResult captureResult;

    try {
      captureResult = await captureAction();
    } catch (_) {
      evidenceErrorKey = 'kroka.errors.evidence_update_failed';
      return false;
    } finally {
      isEvidenceCapturing = false;
      _safeNotifyListeners();
    }

    if (captureResult.isCancelled) {
      return true;
    }

    final capturedFile = captureResult.file;

    if (!captureResult.isSuccess || capturedFile == null) {
      evidenceErrorKey = _mapEvidenceCaptureFailureCode(
        captureResult.errorCode,
      );
      _safeNotifyListeners();
      return false;
    }

    _pendingEvidenceFile = capturedFile;
    _pendingEvidencePurpose = purpose;
    _pendingEvidenceSourceLabel = sourceLabel;
    evidenceErrorKey = null;
    _safeNotifyListeners();

    return true;
  }

  Future<bool> captureAndUploadEvidence() {
    return captureAndUploadEvidenceFromFiles();
  }

  Future<bool> captureAndUploadEvidenceFromCamera() {
    return _captureAndUploadCapturedFile(
      captureAction: _evidenceCaptureService.captureImageFromCamera,
      purpose: AccidentEvidencePurpose.damagePhoto,
      sourceLabel: AccidentEvidenceCaptureSource.camera,
    );
  }

  Future<bool> captureAndUploadEvidenceFromGallery() {
    return _captureAndUploadCapturedFile(
      captureAction: _evidenceCaptureService.pickImageFromGallery,
      purpose: AccidentEvidencePurpose.damagePhoto,
      sourceLabel: AccidentEvidenceCaptureSource.gallery,
    );
  }

  Future<bool> captureAndUploadEvidenceFromFiles() {
    return _captureAndUploadCapturedFile(
      captureAction: _evidenceCaptureService.pickEvidenceFile,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.filePicker,
    );
  }

  Future<bool> captureAndUploadVideoFromCamera() {
    return _captureAndUploadCapturedFile(
      captureAction: _evidenceCaptureService.captureVideoFromCamera,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.camera,
    );
  }

  Future<bool> captureAndUploadVideoFromGallery() {
    return _captureAndUploadCapturedFile(
      captureAction: _evidenceCaptureService.pickVideoFromGallery,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.gallery,
    );
  }

  Future<bool> pickAndUploadVideoFile() {
    return _captureAndUploadCapturedFile(
      captureAction: _evidenceCaptureService.pickVideoEvidenceFile,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.filePicker,
    );
  }

  Future<bool> pickAndUploadAudioFile() {
    return _captureAndUploadCapturedFile(
      captureAction: _evidenceCaptureService.pickAudioEvidenceFile,
      purpose: AccidentEvidencePurpose.general,
      sourceLabel: AccidentEvidenceCaptureSource.filePicker,
    );
  }

  Future<bool> addWitnessStatement({
    String? name,
    String? phone,
    required String statement,
  }) async {
    if (isEvidenceBusy || isSubmitting || isReportSubmitted) return false;

    final safeName = _stringOrNull(name);
    final safePhone = _stringOrNull(phone);
    final safeStatement = _stringOrNull(statement);

    if (safeName == null && safePhone == null && safeStatement == null) {
      evidenceErrorKey = 'kroka.errors.invalid_evidence';
      _safeNotifyListeners();
      return false;
    }

    final capturedAt = DateTime.now().toUtc();
    final witnessEvidence = AccidentEvidenceModel(
      id: 'witness_${capturedAt.microsecondsSinceEpoch}',
      type: AccidentEvidenceType.witnessStatement,
      status: AccidentEvidenceStatus.local,
      capturedAtClient: capturedAt,
      purpose: AccidentEvidencePurpose.witness,
      captureSource: AccidentEvidenceCaptureSource.filePicker,
      sortOrder: _evidenceItems.length,
      witness: AccidentWitnessModel(
        name: safeName,
        phone: safePhone,
        statement: safeStatement,
      ),
      metadata: _buildEvidenceContextMetadata(
        capturedAtClient: capturedAt,
        extra: {
          'evidencePurpose': AccidentEvidencePurpose.witness,
          'captureSource': 'manual_witness_statement',
        },
      ),
    );

    if (!witnessEvidence.isValid) {
      evidenceErrorKey = 'kroka.errors.invalid_evidence';
      _safeNotifyListeners();
      return false;
    }

    _evidenceItems.add(witnessEvidence);
    _sortEvidenceItems();
    evidenceErrorKey = null;
    _safeNotifyListeners();

    await _syncEvidenceIfRemoteReportExists();
    return true;
  }

  Future<bool> scanMyDriverLicenseFromCamera() {
    return _scanDriverLicense(
      role: DriverLicenseRole.myDriver,
      source: DriverLicenseCaptureSource.camera,
    );
  }

  Future<bool> scanMyDriverLicenseFromGallery() {
    return _scanDriverLicense(
      role: DriverLicenseRole.myDriver,
      source: DriverLicenseCaptureSource.gallery,
    );
  }

  Future<bool> scanOtherDriverLicenseFromCamera() {
    return _scanDriverLicense(
      role: DriverLicenseRole.otherDriver,
      source: DriverLicenseCaptureSource.camera,
    );
  }

  Future<bool> scanOtherDriverLicenseFromGallery() {
    return _scanDriverLicense(
      role: DriverLicenseRole.otherDriver,
      source: DriverLicenseCaptureSource.gallery,
    );
  }

  Future<bool> confirmMyDriverLicense() async {
    return _confirmDriverLicense(DriverLicenseRole.myDriver);
  }

  Future<bool> confirmOtherDriverLicense() async {
    return _confirmDriverLicense(DriverLicenseRole.otherDriver);
  }

  Future<bool> skipMyDriverLicense() async {
    return _markDriverLicenseSkipped(
      role: DriverLicenseRole.myDriver,
      status: DriverLicenseVerificationStatus.skipped,
      reason: 'not_available_or_user_skipped',
    );
  }

  Future<bool> markOtherDriverLicenseRefused() async {
    return _markDriverLicenseSkipped(
      role: DriverLicenseRole.otherDriver,
      status: DriverLicenseVerificationStatus.refused,
      reason: 'other_party_refused_or_unavailable',
    );
  }

  Future<bool> _scanDriverLicense({
    required String role,
    required String source,
  }) async {
    if (!canScanDriverLicense) return false;

    _clearTransientErrors();

    isLicenseScanning = true;
    licenseScanErrorKey = null;
    _safeNotifyListeners();

    DriverLicenseScanResult result;

    try {
      result = source == DriverLicenseCaptureSource.camera
          ? await _licenseScanService.captureFromCamera(role: role)
          : await _licenseScanService.pickFromGallery(role: role);
    } catch (_) {
      licenseScanErrorKey = 'kroka.errors.license_scan_failed';
      return false;
    } finally {
      isLicenseScanning = false;
      _safeNotifyListeners();
    }

    if (result.isCancelled) return true;

    final scannedLicense = result.license;

    if (!result.isSuccess || scannedLicense == null) {
      licenseScanErrorKey = _mapLicenseScanFailureCode(result.errorCode);
      _safeNotifyListeners();
      return false;
    }

    DriverLicenseModel licenseWithEvidence = scannedLicense;

    final uploadedEvidence = await _uploadDriverLicenseEvidenceSafely(
      result: result,
      license: scannedLicense,
    );

    if (uploadedEvidence != null) {
      licenseWithEvidence = scannedLicense.copyWith(
        evidenceId: uploadedEvidence.id,
        evidenceUrl: uploadedEvidence.downloadUrl,
        storagePath: uploadedEvidence.storagePath,
        metadata: {
          ...scannedLicense.metadata,
          'linkedEvidenceId': uploadedEvidence.id,
          'linkedEvidenceUrl': uploadedEvidence.downloadUrl,
          'linkedEvidenceStoragePath': uploadedEvidence.storagePath,
        },
      );
    }

    if (role == DriverLicenseRole.myDriver) {
      _myDriverLicense = licenseWithEvidence;
    } else {
      _otherDriverLicense = licenseWithEvidence;
    }

    if (uploadedEvidence != null || licenseScanErrorKey == null) {
      licenseScanErrorKey = null;
      pdfReportErrorKey = null;
    }
    _safeNotifyListeners();

    await _syncEvidenceIfRemoteReportExists();
    return true;
  }

  Future<AccidentEvidenceModel?> _uploadDriverLicenseEvidenceSafely({
    required DriverLicenseScanResult result,
    required DriverLicenseModel license,
  }) async {
    final imageBytes = result.imageBytes;

    if (imageBytes == null || imageBytes.isEmpty) return null;

    final role = DriverLicenseRole.normalize(result.role);
    final source = DriverLicenseCaptureSource.normalize(result.source);
    final evidenceId =
        'license_${role}_${DateTime.now().microsecondsSinceEpoch}';
    final capturedAt = result.capturedAtClient ?? DateTime.now().toUtc();
    final captureSource = source == DriverLicenseCaptureSource.camera
        ? AccidentEvidenceCaptureSource.camera
        : AccidentEvidenceCaptureSource.gallery;
    final fileName = _safeDriverLicenseEvidenceFileName(
      rawName: result.imageName,
      evidenceId: evidenceId,
      source: source,
      mimeType: result.imageMimeType,
    );

    final capturedFile = CapturedEvidenceFile(
      id: evidenceId,
      type: AccidentEvidenceType.image,
      bytes: imageBytes,
      fileName: fileName,
      mimeType: result.imageMimeType ?? 'image/jpeg',
      sizeBytes: imageBytes.length,
      capturedAtClient: capturedAt,
      localPath: result.imagePath,
      captureSource: captureSource,
      metadata: _buildEvidenceContextMetadata(
        capturedAtClient: capturedAt,
        extra: {
          'evidencePurpose': AccidentEvidencePurpose.driverLicense,
          'driverRole': role,
          'licenseSource': source,
          'captureSource': captureSource,
          'rawOcrText': result.rawText,
          'extractedFullName': license.fullName,
          'extractedNationalId': license.nationalId,
          'extractedLicenseNumber': license.licenseNumber,
          'extractedLicenseClass': license.licenseClass,
          'extractedExpiryDate': license.expiryDate?.toUtc().toIso8601String(),
          'ocrConfidence': license.confidence,
          'requiresHumanReview': true,
          'isLiveCameraCapture': source == DriverLicenseCaptureSource.camera,
        },
      ),
    );

    if (!capturedFile.isValid) return null;

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();

    if (userId == null || userId.isEmpty) {
      licenseScanErrorKey = 'kroka.errors.user_not_signed_in';
      return null;
    }

    final storageReportId = _activeEvidenceStorageReportId();

    isEvidenceUpdating = true;
    _safeNotifyListeners();

    try {
      final uploadResult = await _storageService.uploadEvidenceBytes(
        bytes: capturedFile.bytes,
        userId: userId,
        reportId: storageReportId,
        evidenceId: capturedFile.id,
        type: capturedFile.type,
        fileName: capturedFile.fileName,
        mimeType: capturedFile.mimeType,
        capturedAtClient: capturedFile.capturedAtClient,
        sortOrder: _evidenceItems.length,
        metadata: {
          'source': 'guardian360_kroka_driver_license',
          'evidencePurpose': AccidentEvidencePurpose.driverLicense,
          'driverRole': role,
          'licenseSource': source,
          'captureSource': captureSource,
        },
        purpose: AccidentEvidencePurpose.driverLicense,
        captureSource: captureSource,
        evidenceMetadata: {
          ...capturedFile.metadata,
          'evidenceStorageReportId': storageReportId,
          'willAttachOnSubmit': !hasDraftReport && !isReportSubmitted,
        },
        note: role == DriverLicenseRole.myDriver
            ? 'Driver license verification evidence - my driver'
            : 'Driver license verification evidence - other driver',
      );

      if (uploadResult.isFailure || uploadResult.data == null) {
        licenseScanErrorKey = _mapEvidenceFailureCode(uploadResult.error?.code);
        return null;
      }

      final uploadedEvidence = uploadResult.data!;
      final nextEvidenceItems = _mergedEvidenceItems(uploadedEvidence);

      _evidenceItems
        ..clear()
        ..addAll(nextEvidenceItems);

      return uploadedEvidence;
    } catch (_) {
      licenseScanErrorKey = 'kroka.errors.license_scan_failed';
      return null;
    } finally {
      isEvidenceUpdating = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> _confirmDriverLicense(String role) async {
    final safeRole = DriverLicenseRole.normalize(role);
    final current = safeRole == DriverLicenseRole.myDriver
        ? _myDriverLicense
        : _otherDriverLicense;

    if (current == null || !current.hasUsefulData) {
      licenseScanErrorKey = 'kroka.errors.license_scan_required';
      _safeNotifyListeners();
      return false;
    }

    final confirmed = current.copyWith(
      status: DriverLicenseVerificationStatus.verified,
      reviewedAtClient: DateTime.now().toUtc(),
      metadata: {
        ...current.metadata,
        'humanReviewed': true,
        'verificationMeaning': 'supportive_not_legal_decision',
      },
    );

    if (safeRole == DriverLicenseRole.myDriver) {
      _myDriverLicense = confirmed;
    } else {
      _otherDriverLicense = confirmed;
    }

    licenseScanErrorKey = null;
    _safeNotifyListeners();

    await _syncEvidenceIfRemoteReportExists();
    return true;
  }

  Future<bool> _markDriverLicenseSkipped({
    required String role,
    required String status,
    required String reason,
  }) async {
    final safeRole = DriverLicenseRole.normalize(role);
    final now = DateTime.now().toUtc();
    final skipped = DriverLicenseModel(
      driverRole: safeRole,
      status: DriverLicenseVerificationStatus.normalize(status),
      scannedAtClient: now,
      reviewedAtClient: now,
      source: DriverLicenseCaptureSource.manual,
      skipReason: reason,
      metadata: {
        'supportiveVerification': true,
        'notMandatory': true,
        'reason': reason,
      },
    );

    if (safeRole == DriverLicenseRole.myDriver) {
      _myDriverLicense = skipped;
    } else {
      _otherDriverLicense = skipped;
    }

    licenseScanErrorKey = null;
    _safeNotifyListeners();

    await _syncEvidenceIfRemoteReportExists();
    return true;
  }

  Future<bool> _captureAndUploadCapturedFile({
    required Future<EvidenceCaptureResult> Function() captureAction,
    required String purpose,
    required String sourceLabel,
  }) async {
    if (isEvidenceBusy || isSubmitting || isReportSubmitted) {
      return false;
    }

    _clearTransientErrors();

    isEvidenceCapturing = true;
    _safeNotifyListeners();

    EvidenceCaptureResult captureResult;

    try {
      captureResult = await captureAction();
    } catch (_) {
      evidenceErrorKey = 'kroka.errors.evidence_update_failed';
      return false;
    } finally {
      isEvidenceCapturing = false;
      _safeNotifyListeners();
    }

    if (captureResult.isCancelled) {
      return true;
    }

    final capturedFile = captureResult.file;

    if (!captureResult.isSuccess || capturedFile == null) {
      evidenceErrorKey = _mapEvidenceCaptureFailureCode(
        captureResult.errorCode,
      );
      _safeNotifyListeners();
      return false;
    }

    return _uploadCapturedEvidenceFile(
      capturedFile: capturedFile,
      purpose: purpose,
      captureSource: capturedFile.captureSource,
      storageMetadata: {
        'source': 'guardian360_kroka',
        'evidencePurpose': purpose,
        'captureSource': capturedFile.captureSource,
      },
      evidenceMetadata: _buildEvidenceContextMetadata(
        capturedAtClient: capturedFile.capturedAtClient,
        extra: {
          'evidencePurpose': purpose,
          'captureSource': capturedFile.captureSource,
          'captureMethodLabel': sourceLabel,
        },
      ),
    );
  }

  Future<bool> _uploadCapturedEvidenceFile({
    required CapturedEvidenceFile capturedFile,
    required String purpose,
    required String captureSource,
    Map<String, String>? storageMetadata,
    Map<String, dynamic>? evidenceMetadata,
    String? note,
  }) async {
    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();

    if (userId == null || userId.isEmpty) {
      evidenceErrorKey = 'kroka.errors.user_not_signed_in';
      _safeNotifyListeners();
      return false;
    }

    final storageReportId = _activeEvidenceStorageReportId();

    isEvidenceUpdating = true;
    evidenceErrorKey = null;
    _safeNotifyListeners();

    try {
      final uploadResult = await _storageService.uploadEvidenceBytes(
        bytes: capturedFile.bytes,
        userId: userId,
        reportId: storageReportId,
        evidenceId: capturedFile.id,
        type: capturedFile.type,
        fileName: capturedFile.fileName,
        mimeType: capturedFile.mimeType,
        capturedAtClient: capturedFile.capturedAtClient,
        sortOrder: _evidenceItems.length,
        metadata: storageMetadata,
        purpose: purpose,
        captureSource: captureSource,
        evidenceMetadata: {
          ...capturedFile.metadata,
          ...?evidenceMetadata,
          'evidenceStorageReportId': storageReportId,
          'willAttachOnSubmit': !hasDraftReport && !isReportSubmitted,
        },
        note: note,
      );

      if (uploadResult.isFailure || uploadResult.data == null) {
        evidenceErrorKey = _mapEvidenceFailureCode(uploadResult.error?.code);
        return false;
      }

      final uploadedEvidence = uploadResult.data!;
      final nextEvidenceItems = _mergedEvidenceItems(uploadedEvidence);

      _evidenceItems
        ..clear()
        ..addAll(nextEvidenceItems);

      evidenceErrorKey = null;
      _safeNotifyListeners();

      await _syncEvidenceIfRemoteReportExists();
      return true;
    } catch (_) {
      evidenceErrorKey = 'kroka.errors.evidence_update_failed';
      return false;
    } finally {
      isEvidenceUpdating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _syncEvidenceIfRemoteReportExists() async {
    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();

    if (userId == null || userId.isEmpty) return;

    final reportId = isReportSubmitted
        ? submittedReportId?.trim()
        : draftReportId?.trim();

    if (reportId == null || reportId.isEmpty) return;

    try {
      await _repository.updateReportEvidence(
        reportId: reportId,
        userId: userId,
        evidenceItems: _reportSafeEvidenceItems(),
      );
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ KrokaViewModel: Evidence will be attached on final submit - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _activeEvidenceStorageReportId() {
    final submittedId = submittedReportId?.trim();
    if (isReportSubmitted && submittedId != null && submittedId.isNotEmpty) {
      return submittedId;
    }

    final draftId = draftReportId?.trim();
    if (draftId != null && draftId.isNotEmpty) {
      return draftId;
    }

    return _ensureLocalEvidenceSessionId();
  }

  String _ensureLocalEvidenceSessionId() {
    final current = _localEvidenceSessionId?.trim();
    if (current != null && current.isNotEmpty) return current;

    final sessionId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    _localEvidenceSessionId = sessionId;
    return sessionId;
  }

  Future<void> simulateCameraCapture() async {
    await captureAndUploadEvidenceFromCamera();
  }

  void resetSubmissionState() {
    isReportSubmitted = false;
    submittedReportId = null;
    submittedReferenceCode = null;
    generatedReport = null;

    draftReportId = null;
    draftReferenceCode = null;
    _localEvidenceSessionId = null;
    _pendingEvidenceFile = null;
    _pendingEvidencePurpose = null;
    _pendingEvidenceSourceLabel = null;

    submissionErrorKey = null;
    validationErrorKey = null;
    evidenceErrorKey = null;
    draftErrorKey = null;
    plateScanErrorKey = null;
    licenseScanErrorKey = null;
    pdfReportErrorKey = null;

    _safeNotifyListeners();
  }

  void clearFormForNewReport({bool refreshCurrentLocation = true}) {
    unawaited(discardDraftIfEmpty());

    selectedDamageZoneIds.clear();
    faultStatus = '';

    myCarCodeController.clear();
    myCarNumController.clear();
    otherCarCodeController.clear();
    otherCarNumController.clear();
    notesController.clear();

    _evidenceItems.clear();
    _lastMyScannedPlate = null;
    _lastOtherScannedPlate = null;
    _myDriverLicense = null;
    _otherDriverLicense = null;
    generatedReport = null;

    isReportSubmitted = false;
    submittedReportId = null;
    submittedReferenceCode = null;
    generatedReport = null;

    draftReportId = null;
    draftReferenceCode = null;
    _localEvidenceSessionId = null;

    validationErrorKey = null;
    submissionErrorKey = null;
    evidenceErrorKey = null;
    draftErrorKey = null;
    plateScanErrorKey = null;
    licenseScanErrorKey = null;
    pdfReportErrorKey = null;

    if (refreshCurrentLocation) {
      refreshLocation();
    } else {
      _safeNotifyListeners();
    }
  }

  Future<bool> openLocationSettings() {
    return _locationService.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return _locationService.openAppSettings();
  }

  _ValidatedKrokaForm? _validateForm() {
    if (selectedDamageZoneIds.isEmpty ||
        !selectedDamageZoneIds.every(_validDamageZoneIds.contains)) {
      validationErrorKey = 'kroka.errors.damage_required';
      return null;
    }

    if (!_validFaultStatuses.contains(faultStatus)) {
      validationErrorKey = 'kroka.errors.fault_required';
      return null;
    }

    final myPlateResult = _plateValidator.validate(
      rawCode: myCarCodeController.text,
      rawNumber: myCarNumController.text,
      required: true,
    );

    if (!myPlateResult.isValid || myPlateResult.plate == null) {
      validationErrorKey =
          myPlateResult.errorKey ?? 'kroka.errors.invalid_vehicle_plate';
      return null;
    }

    final otherPlateResult = _plateValidator.validate(
      rawCode: otherCarCodeController.text,
      rawNumber: otherCarNumController.text,
      required: false,
    );

    if (!otherPlateResult.isValid) {
      validationErrorKey =
          otherPlateResult.errorKey ?? 'kroka.errors.invalid_vehicle_plate';
      return null;
    }

    final otherPlate = otherPlateResult.plate;

    if (otherPlate != null &&
        otherPlate.normalizedKey == myPlateResult.plate!.normalizedKey) {
      validationErrorKey = 'kroka.errors.duplicate_vehicle_plate';
      return null;
    }

    final normalizedNotes = _normalizeNotes(notesController.text);

    if (normalizedNotes != null && normalizedNotes.length > _maxNotesLength) {
      validationErrorKey = 'kroka.errors.notes_too_long';
      return null;
    }

    validationErrorKey = null;

    return _ValidatedKrokaForm(
      myVehiclePlate: _plateWithTrackedSource(
        plate: myPlateResult.plate!,
        trackedOcrPlate: _lastMyScannedPlate,
      ),
      otherVehiclePlate: otherPlate == null
          ? null
          : _plateWithTrackedSource(
              plate: otherPlate,
              trackedOcrPlate: _lastOtherScannedPlate,
            ),
      notes: normalizedNotes,
    );
  }

  VehiclePlateModel _plateWithTrackedSource({
    required VehiclePlateModel plate,
    required VehiclePlateModel? trackedOcrPlate,
  }) {
    if (trackedOcrPlate == null) return plate;

    if (trackedOcrPlate.normalizedKey == plate.normalizedKey) {
      return trackedOcrPlate;
    }

    return plate.copyWith(
      source: VehiclePlateInputSource.editedAfterOcr,
      confidence: trackedOcrPlate.confidence,
      rawText: trackedOcrPlate.rawText,
    );
  }

  Future<bool> _ensureLocationReady() async {
    if (hasCapturedLocation && _capturedPosition != null) {
      return _isUsablePosition(_capturedPosition!);
    }

    return refreshLocation();
  }

  Future<String?> _resolveLocationName(Position position) async {
    try {
      final areaName = await _geocodingService.getAreaNameFromCoordinates(
        LatLng(position.latitude, position.longitude),
      );

      final safeAreaName = areaName.trim();

      if (safeAreaName.isEmpty || _isGenericGeocodingFallback(safeAreaName)) {
        return null;
      }

      return safeAreaName;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendKrokaSavedNotificationSafely({
    required String reportId,
    required String referenceCode,
  }) async {
    if (_isDisposed) return;

    try {
      await _notificationService.sendKrokaReportSavedNotification(
        reportId: reportId,
        referenceCode: referenceCode,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ KrokaViewModel: Kroka saved notification failed, report remains saved - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> generateSubmittedPdfReport() async {
    if (!canGeneratePdfReport) return false;

    final currentUser = _authService.currentUser;
    final userId = currentUser?.uid.trim();
    final reportId = submittedReportId?.trim();
    final referenceCode = submittedReferenceCode?.trim();
    final position = _capturedPosition;
    final locationCapturedAt = _locationCapturedAtClient;
    final form = _validateForm();

    if (userId == null || userId.isEmpty) {
      pdfReportErrorKey = 'kroka.errors.user_not_signed_in';
      _safeNotifyListeners();
      return false;
    }

    if (reportId == null ||
        reportId.isEmpty ||
        referenceCode == null ||
        referenceCode.isEmpty) {
      pdfReportErrorKey = 'kroka.errors.report_not_submitted';
      _safeNotifyListeners();
      return false;
    }

    if (form == null || position == null || locationCapturedAt == null) {
      pdfReportErrorKey = 'kroka.errors.pdf_generation_failed';
      _safeNotifyListeners();
      return false;
    }

    return _generateSubmittedPdfReport(
      userId: userId,
      reportId: reportId,
      referenceCode: referenceCode,
      form: form,
      position: position,
      locationCapturedAt: locationCapturedAt,
    );
  }

  Future<bool> _generateSubmittedPdfReport({
    required String userId,
    required String reportId,
    required String referenceCode,
    required _ValidatedKrokaForm form,
    required Position position,
    required DateTime locationCapturedAt,
  }) async {
    if (isPdfGenerating) return false;

    isPdfGenerating = true;
    pdfReportErrorKey = null;
    _safeNotifyListeners();

    try {
      final generatedAt = DateTime.now().toUtc();
      final qrPayload = _buildReportQrPayload(
        reportId: reportId,
        referenceCode: referenceCode,
        generatedAtClient: generatedAt,
      );

      final input = KrokaPdfReportInput(
        reportId: reportId,
        referenceCode: referenceCode,
        userId: userId,
        damageLabel: _damagePdfLabel(
          selectedDamageZone?.id ?? selectedDamageZoneIds.firstOrNull ?? '',
        ),
        faultEstimate: faultStatus,
        myVehiclePlate: form.myVehiclePlate,
        otherVehiclePlate: form.otherVehiclePlate,
        myDriverLicense: _reportSafeDriverLicense(_myDriverLicense),
        otherDriverLicense: _reportSafeDriverLicense(_otherDriverLicense),
        latitude: position.latitude,
        longitude: position.longitude,
        locationAccuracyMeters: position.accuracy,
        locationCapturedAtClient: locationCapturedAt.toUtc(),
        submittedAtClient: generatedAt,
        qrPayload: qrPayload,
        locationName: _locationName,
        speedKmhAtCapture: _speedKmhOrNull(position.speed),
        headingDegreesAtCapture: _headingOrNull(position.heading),
        notes: form.notes,
        evidenceItems: _reportSafeEvidenceItems(),
      );

      final pdfBytes = await _pdfReportService.buildAccidentReportPdf(input);
      final fileName = _safePdfFileName(referenceCode);
      final uploadResult = await _storageService.uploadReportPdfBytes(
        bytes: pdfBytes,
        userId: userId,
        reportId: reportId,
        referenceCode: referenceCode,
        fileName: fileName,
        generatedAtClient: generatedAt,
        qrPayload: qrPayload,
        metadata: {
          'source': 'guardian360_smart_kroka',
          'reportType': 'minor_traffic_accident',
          'evidenceCount': _reportSafeEvidenceItems().length.toString(),
        },
      );

      if (uploadResult.isFailure || uploadResult.data == null) {
        pdfReportErrorKey = _mapPdfReportFailureCode(uploadResult.error?.code);
        return false;
      }

      final generated = uploadResult.data!;
      final attachResult = await _repository.attachGeneratedReport(
        reportId: reportId,
        userId: userId,
        generatedReport: generated,
      );

      if (attachResult.isFailure) {
        pdfReportErrorKey = _mapPdfReportFailureCode(attachResult.error?.code);
        generatedReport = generated;
        return false;
      }

      generatedReport = generated;
      pdfReportErrorKey = null;
      return true;
    } catch (e, stackTrace) {
      debugPrint('⚠️ KrokaViewModel: PDF report generation failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      pdfReportErrorKey = 'kroka.errors.pdf_generation_failed';
      return false;
    } finally {
      isPdfGenerating = false;
      _safeNotifyListeners();
    }
  }

  String _buildReportQrPayload({
    required String reportId,
    required String referenceCode,
    required DateTime generatedAtClient,
  }) {
    return 'guardian360://kroka/report?ref=$referenceCode&id=$reportId&v=${GeneratedReportModel.currentVersion}&t=${generatedAtClient.toUtc().toIso8601String()}';
  }

  String _safePdfFileName(String referenceCode) {
    final safeReference = referenceCode
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final code = safeReference.isEmpty
        ? 'kroka_${DateTime.now().millisecondsSinceEpoch}'
        : safeReference;

    return 'guardian360_$code.pdf';
  }

  String _damagePdfLabel(String value) {
    switch (value) {
      case 'front':
        return 'أمام';
      case 'front_left':
        return 'أمام يسار';
      case 'front_right':
        return 'أمام يمين';
      case 'left':
        return 'يسار';
      case 'left_front_door':
        return 'باب يسار أمامي';
      case 'left_rear_door':
        return 'باب يسار خلفي';
      case 'right':
        return 'يمين';
      case 'right_front_door':
        return 'باب يمين أمامي';
      case 'right_rear_door':
        return 'باب يمين خلفي';
      case 'rear_left':
        return 'خلف يسار';
      case 'rear_right':
        return 'خلف يمين';
      case 'back':
        return 'خلف';
      default:
        return value.trim().isEmpty ? 'غير محدد' : value.trim();
    }
  }

  DateTime _safePositionTimestamp(Position position) {
    final timestamp = position.timestamp;

    return timestamp.toUtc();
  }

  bool _isGenericGeocodingFallback(String value) {
    final normalized = value.trim();
    final lower = normalized.toLowerCase();

    return normalized == 'موقعك الحالي' ||
        normalized == 'موقع غير معروف' ||
        normalized == 'عنوان غير معروف' ||
        lower == 'unknown location' ||
        lower == 'unknown address';
  }

  bool _isUsablePosition(Position position) {
    return _hasValidCoordinates(position.latitude, position.longitude) &&
        !position.accuracy.isNaN &&
        !position.accuracy.isInfinite &&
        position.accuracy >= 0.0;
  }

  bool _hasValidCoordinates(double latitude, double longitude) {
    return !latitude.isNaN &&
        !latitude.isInfinite &&
        !longitude.isNaN &&
        !longitude.isInfinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        !(latitude == 0.0 && longitude == 0.0);
  }

  bool _isReportSafeEvidence(AccidentEvidenceModel evidence) {
    if (!evidence.isValid) return false;

    if (evidence.isMedia) {
      return evidence.hasRemoteReference;
    }

    if (evidence.isWitnessStatement) {
      return true;
    }

    return false;
  }

  List<AccidentEvidenceModel> _reportSafeEvidenceItems() {
    if (_evidenceItems.isEmpty) return const [];

    final safeItems = _evidenceItems
        .where(_isReportSafeEvidence)
        .toList(growable: true);

    if (safeItems.isEmpty) return const [];

    safeItems.sort((a, b) {
      final sortOrderCompare = a.sortOrder.compareTo(b.sortOrder);

      if (sortOrderCompare != 0) return sortOrderCompare;

      return a.capturedAtClient.compareTo(b.capturedAtClient);
    });

    final seenIds = <String>{};
    final uniqueItems = <AccidentEvidenceModel>[];

    for (final item in safeItems) {
      final safeId = item.id.trim();

      if (safeId.isEmpty) continue;

      if (seenIds.add(safeId)) {
        uniqueItems.add(item);
      }
    }

    return List<AccidentEvidenceModel>.unmodifiable(uniqueItems);
  }

  List<AccidentEvidenceModel> _mergedEvidenceItems(
    AccidentEvidenceModel newEvidence,
  ) {
    final mergedItems = <AccidentEvidenceModel>[..._evidenceItems];
    final safeNewEvidenceId = newEvidence.id.trim();

    if (safeNewEvidenceId.isEmpty || !_isReportSafeEvidence(newEvidence)) {
      return _reportSafeEvidenceItems();
    }

    final existingIndex = mergedItems.indexWhere(
      (item) => item.id.trim() == safeNewEvidenceId,
    );

    if (existingIndex >= 0) {
      mergedItems[existingIndex] = newEvidence;
    } else {
      mergedItems.add(newEvidence);
    }

    final safeItems = mergedItems
        .where(_isReportSafeEvidence)
        .toList(growable: true);

    safeItems.sort((a, b) {
      final sortOrderCompare = a.sortOrder.compareTo(b.sortOrder);

      if (sortOrderCompare != 0) return sortOrderCompare;

      return a.capturedAtClient.compareTo(b.capturedAtClient);
    });

    final seenIds = <String>{};
    final uniqueItems = <AccidentEvidenceModel>[];

    for (final item in safeItems) {
      final safeId = item.id.trim();

      if (safeId.isEmpty) continue;

      if (seenIds.add(safeId)) {
        uniqueItems.add(item);
      }
    }

    return List<AccidentEvidenceModel>.unmodifiable(uniqueItems);
  }

  Future<void> _uploadPlateScanEvidenceSafely({
    required PlateOcrResult result,
    required VehiclePlateModel scannedPlate,
    required bool isMineVehicle,
  }) async {
    final imageBytes = result.imageBytes;

    if (imageBytes == null || imageBytes.isEmpty) return;

    final source = PlateOcrImageSource.normalize(result.source);
    final captureSource = source == PlateOcrImageSource.camera
        ? AccidentEvidenceCaptureSource.ocrCamera
        : AccidentEvidenceCaptureSource.ocrGallery;
    final vehicleRole = isMineVehicle ? 'my_vehicle' : 'other_vehicle';
    final evidenceId =
        'plate_${vehicleRole}_${DateTime.now().microsecondsSinceEpoch}';
    final capturedAt = result.capturedAtClient ?? DateTime.now().toUtc();
    final fileName = _safePlateEvidenceFileName(
      rawName: result.imageName,
      evidenceId: evidenceId,
      captureSource: captureSource,
      mimeType: result.imageMimeType,
    );

    final capturedFile = CapturedEvidenceFile(
      id: evidenceId,
      type: AccidentEvidenceType.image,
      bytes: imageBytes,
      fileName: fileName,
      mimeType: result.imageMimeType ?? 'image/jpeg',
      sizeBytes: imageBytes.length,
      capturedAtClient: capturedAt,
      localPath: result.imagePath,
      captureSource: captureSource,
      metadata: _buildEvidenceContextMetadata(
        capturedAtClient: capturedAt,
        extra: {
          'evidencePurpose': AccidentEvidencePurpose.vehiclePlate,
          'vehicleRole': vehicleRole,
          'ocrSource': source,
          'captureSource': captureSource,
          'rawOcrText': result.rawText,
          'detectedPlateCode': scannedPlate.code,
          'detectedPlateNumber': scannedPlate.number,
          'finalPlateCode': scannedPlate.code,
          'finalPlateNumber': scannedPlate.number,
          'finalPlateKey': scannedPlate.normalizedKey,
          'plateCountryCode': scannedPlate.countryCode,
          'ocrConfidence': scannedPlate.confidence,
          'isLiveCameraCapture': source == PlateOcrImageSource.camera,
        },
      ),
    );

    if (!capturedFile.isValid) return;

    await _uploadCapturedEvidenceFile(
      capturedFile: capturedFile,
      purpose: AccidentEvidencePurpose.vehiclePlate,
      captureSource: captureSource,
      storageMetadata: {
        'source': 'guardian360_kroka_plate_ocr',
        'evidencePurpose': AccidentEvidencePurpose.vehiclePlate,
        'vehicleRole': vehicleRole,
        'ocrSource': source,
        'captureSource': captureSource,
        'detectedPlateCode': scannedPlate.code.toString(),
        'detectedPlateNumber': scannedPlate.number.toString(),
      },
      evidenceMetadata: capturedFile.metadata,
      note: isMineVehicle
          ? 'Vehicle plate OCR evidence - my vehicle'
          : 'Vehicle plate OCR evidence - other vehicle',
    );
  }

  Map<String, dynamic> _buildEvidenceContextMetadata({
    DateTime? capturedAtClient,
    Map<String, dynamic> extra = const {},
  }) {
    final position = _capturedPosition;
    final capturedAt = capturedAtClient ?? DateTime.now().toUtc();

    return {
      'capturedAtClient': capturedAt.toUtc().toIso8601String(),
      'locationName': _locationName,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'locationAccuracyMeters': position?.accuracy,
      'speedKmhAtCapture': position == null
          ? null
          : _speedKmhOrNull(position.speed),
      'headingDegreesAtCapture': position == null
          ? null
          : _headingOrNull(position.heading),
      'locationCapturedAtClient': _locationCapturedAtClient
          ?.toUtc()
          .toIso8601String(),
      'hasLocationSnapshot': position != null && _isUsablePosition(position),
      ...extra,
    };
  }

  DriverLicenseModel? _reportSafeDriverLicense(DriverLicenseModel? license) {
    if (license == null || !license.isValid) return null;
    return license;
  }

  String _safeDriverLicenseEvidenceFileName({
    required String? rawName,
    required String evidenceId,
    required String source,
    required String? mimeType,
  }) {
    final safeRawName = rawName?.trim();

    if (safeRawName != null &&
        safeRawName.isNotEmpty &&
        safeRawName.contains('.')) {
      return safeRawName;
    }

    final extension = _extensionFromMimeType(mimeType);
    final sourceLabel = source == DriverLicenseCaptureSource.camera
        ? 'camera'
        : 'gallery';

    return '${evidenceId}_$sourceLabel.$extension';
  }

  String _safePlateEvidenceFileName({
    required String? rawName,
    required String evidenceId,
    required String captureSource,
    required String? mimeType,
  }) {
    final safeRawName = rawName?.trim();

    if (safeRawName != null &&
        safeRawName.isNotEmpty &&
        safeRawName.contains('.')) {
      return safeRawName;
    }

    final extension = _extensionFromMimeType(mimeType);
    final sourceLabel = captureSource == AccidentEvidenceCaptureSource.ocrCamera
        ? 'camera'
        : 'gallery';

    return '${evidenceId}_$sourceLabel.$extension';
  }

  String _extensionFromMimeType(String? mimeType) {
    switch (mimeType?.trim().toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      case 'image/jpg':
      default:
        return 'jpg';
    }
  }

  double? _speedKmhOrNull(double speedMetersPerSecond) {
    if (speedMetersPerSecond.isNaN ||
        speedMetersPerSecond.isInfinite ||
        speedMetersPerSecond < 0) {
      return null;
    }

    final speedKmh = speedMetersPerSecond * 3.6;

    if (speedKmh.isNaN || speedKmh.isInfinite || speedKmh < 0) {
      return null;
    }

    return double.parse(speedKmh.toStringAsFixed(2));
  }

  double? _headingOrNull(double heading) {
    if (heading.isNaN || heading.isInfinite || heading < 0) return null;

    return double.parse(heading.toStringAsFixed(2));
  }

  void _sortEvidenceItems() {
    if (_evidenceItems.length < 2) return;

    _evidenceItems.sort((a, b) {
      final sortOrderCompare = a.sortOrder.compareTo(b.sortOrder);

      if (sortOrderCompare != 0) return sortOrderCompare;

      return a.capturedAtClient.compareTo(b.capturedAtClient);
    });
  }

  String? _stringOrNull(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) return null;

    return trimmed;
  }

  String? _normalizeNotes(String value) {
    final lines = value
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    return lines.join('\n');
  }

  String _plateOcrSourceLabelKey(String? source) {
    switch (VehiclePlateInputSource.normalize(source ?? '')) {
      case VehiclePlateInputSource.ocrCamera:
        return 'kroka.vehicles.ocr_camera_filled';
      case VehiclePlateInputSource.ocrGallery:
      case VehiclePlateInputSource.ocr:
        return 'kroka.vehicles.ocr_gallery_filled';
      case VehiclePlateInputSource.editedAfterOcr:
        return 'kroka.vehicles.ocr_edited_filled';
      case VehiclePlateInputSource.manual:
      default:
        return 'kroka.vehicles.ocr_filled';
    }
  }

  String _mapPlateOcrFailureCode(String? code) {
    switch (code) {
      case 'unsupported-platform':
        return 'kroka.errors.plate_ocr_unsupported_platform';
      case 'unsupported-image-type':
      case 'empty-image-file':
      case 'image-path-unavailable':
        return 'kroka.errors.plate_ocr_invalid_image';
      case 'no-text-detected':
        return 'kroka.errors.plate_ocr_no_text';
      case 'no-plate-detected':
        return 'kroka.errors.plate_ocr_no_plate';
      case 'ocr-failed':
      default:
        return 'kroka.errors.plate_ocr_failed';
    }
  }

  String _mapSubmitFailureCode(String? code) {
    switch (code) {
      case 'invalid-user-id':
        return 'kroka.errors.user_not_signed_in';
      case 'invalid-coordinates':
      case 'invalid-location-accuracy':
        return 'kroka.errors.location_required';
      case 'invalid-damage-zone':
        return 'kroka.errors.invalid_damage_point';
      case 'invalid-fault-estimate':
        return 'kroka.errors.fault_required';
      case 'kroka-draft-not-found':
        return 'kroka.errors.draft_not_found';
      case 'kroka-draft-owner-mismatch':
        return 'kroka.errors.not_allowed';
      case 'kroka-draft-not-editable':
        return 'kroka.errors.draft_not_editable';
      case 'kroka-submit-timeout':
      case 'kroka-submit-failed':
      default:
        return 'kroka.errors.submit_failed';
    }
  }

  String _mapLicenseScanFailureCode(String? code) {
    switch (code) {
      case 'unsupported-platform':
        return 'kroka.errors.license_scan_unsupported_platform';
      case 'unsupported-image-type':
      case 'empty-image-file':
      case 'image-path-unavailable':
        return 'kroka.errors.license_scan_invalid_image';
      case 'no-text-detected':
        return 'kroka.errors.license_scan_no_text';
      case 'no-license-data-detected':
        return 'kroka.errors.license_scan_no_data';
      case 'scan-failed':
      default:
        return 'kroka.errors.license_scan_failed';
    }
  }

  String _mapEvidenceCaptureFailureCode(String? code) {
    switch (code) {
      case 'invalid-file':
      case 'empty-file':
      case 'invalid-evidence':
        return 'kroka.errors.invalid_evidence';
      case 'unsupported-file-type':
      case 'file-too-large':
      case 'capture-failed':
      default:
        return 'kroka.errors.evidence_update_failed';
    }
  }

  String _mapEvidenceFailureCode(String? code) {
    switch (code) {
      case 'invalid-user-id':
        return 'kroka.errors.user_not_signed_in';
      case 'invalid-report-id':
      case 'kroka-report-not-found':
        return 'kroka.errors.report_not_submitted';
      case 'kroka-report-owner-mismatch':
      case 'kroka-draft-owner-mismatch':
        return 'kroka.errors.not_allowed';
      case 'kroka-report-discarded':
        return 'kroka.errors.draft_not_editable';
      case 'empty-evidence-file':
      case 'unsupported-evidence-type':
      case 'invalid-evidence-file-name':
      case 'invalid-evidence-mime-type':
      case 'invalid-uploaded-evidence':
      case 'evidence-upload-timeout':
      case 'evidence-upload-failed':
      case 'kroka-evidence-update-timeout':
      case 'kroka-evidence-update-failed':
      default:
        return 'kroka.errors.evidence_update_failed';
    }
  }

  String _mapPdfReportFailureCode(String? code) {
    switch (code) {
      case 'invalid-user-id':
        return 'kroka.errors.user_not_signed_in';
      case 'invalid-report-id':
      case 'kroka-report-not-found':
        return 'kroka.errors.report_not_submitted';
      case 'kroka-report-owner-mismatch':
        return 'kroka.errors.not_allowed';
      case 'empty-pdf-report':
      case 'invalid-pdf-file-name':
      case 'invalid-generated-report':
      case 'pdf-report-upload-timeout':
      case 'pdf-report-upload-failed':
      case 'kroka-generated-report-update-timeout':
      case 'kroka-generated-report-update-failed':
      default:
        return 'kroka.errors.pdf_generation_failed';
    }
  }

  String _mapDraftFailureCode(String? code) {
    switch (code) {
      case 'invalid-user-id':
        return 'kroka.errors.user_not_signed_in';
      case 'invalid-report-id':
      case 'kroka-draft-not-found':
        return 'kroka.errors.draft_not_found';
      case 'kroka-draft-owner-mismatch':
        return 'kroka.errors.not_allowed';
      case 'kroka-draft-not-editable':
        return 'kroka.errors.draft_not_editable';
      case 'kroka-draft-create-timeout':
      case 'kroka-draft-create-failed':
        return 'kroka.errors.draft_create_failed';
      case 'kroka-draft-discard-timeout':
      case 'kroka-draft-discard-failed':
        return 'kroka.errors.draft_discard_failed';
      default:
        return 'kroka.errors.draft_operation_failed';
    }
  }

  void _attachFieldListeners() {
    myCarCodeController.addListener(_onFormFieldChanged);
    myCarNumController.addListener(_onFormFieldChanged);
    otherCarCodeController.addListener(_onFormFieldChanged);
    otherCarNumController.addListener(_onFormFieldChanged);
    notesController.addListener(_onFormFieldChanged);
  }

  void _removeFieldListeners() {
    myCarCodeController.removeListener(_onFormFieldChanged);
    myCarNumController.removeListener(_onFormFieldChanged);
    otherCarCodeController.removeListener(_onFormFieldChanged);
    otherCarNumController.removeListener(_onFormFieldChanged);
    notesController.removeListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    if (_isDisposed) return;

    _clearTransientErrors();
    _safeNotifyListeners();
  }

  void _clearSubmitErrors() {
    validationErrorKey = null;
    submissionErrorKey = null;
    evidenceErrorKey = null;
    draftErrorKey = null;
    plateScanErrorKey = null;
    licenseScanErrorKey = null;
    pdfReportErrorKey = null;
  }

  void _clearTransientErrors() {
    validationErrorKey = null;
    submissionErrorKey = null;
    evidenceErrorKey = null;
    draftErrorKey = null;
    plateScanErrorKey = null;
    licenseScanErrorKey = null;
    pdfReportErrorKey = null;
  }

  void _safeNotifyListeners() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;

    _removeFieldListeners();

    myCarCodeController.dispose();
    myCarNumController.dispose();
    otherCarCodeController.dispose();
    otherCarNumController.dispose();
    notesController.dispose();

    unawaited(_plateOcrService.dispose());
    unawaited(_licenseScanService.dispose());

    if (_ownsNotificationService) {
      unawaited(_notificationService.dispose());
    }

    super.dispose();
  }
}

class _ValidatedKrokaForm {
  const _ValidatedKrokaForm({
    required this.myVehiclePlate,
    required this.otherVehiclePlate,
    required this.notes,
  });

  final VehiclePlateModel myVehiclePlate;
  final VehiclePlateModel? otherVehiclePlate;
  final String? notes;
}

class KrokaReviewState {
  const KrokaReviewState({
    required this.isLocationReady,
    required this.isDamageReady,
    required this.isFaultReady,
    required this.isMyPlateReady,
    required this.isOtherPlateProvided,
    required this.hasEvidence,
    required this.evidenceCount,
    required this.damageLabelKey,
    required this.selectedDamageZoneIds,
    required this.faultLabelKey,
    required this.myPlatePreview,
    required this.otherPlatePreview,
    required this.locationPreview,
  });

  final bool isLocationReady;
  final bool isDamageReady;
  final bool isFaultReady;
  final bool isMyPlateReady;
  final bool isOtherPlateProvided;
  final bool hasEvidence;
  final int evidenceCount;

  /// All currently selected damage zone IDs (unmodifiable snapshot).
  final Set<String> selectedDamageZoneIds;

  final String damageLabelKey;
  final String faultLabelKey;
  final String? myPlatePreview;
  final String? otherPlatePreview;
  final String locationPreview;
}
