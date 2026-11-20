import 'dart:typed_data';

import 'package:barcode/barcode.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/accident_evidence_model.dart';
import '../models/driver_license_model.dart';
import '../models/generated_report_model.dart';
import '../models/vehicle_plate_model.dart';

class PdfReportService {
  const PdfReportService();

  Future<Uint8List> buildAccidentReportPdf(KrokaPdfReportInput input) async {
    final fonts = await _loadFontsSafely();
    final doc = pw.Document(
      title: 'Guardian360 Kroka Report ${input.referenceCode}',
      author: 'Guardian360',
      creator: 'Guardian360 Smart Kroka',
      subject: 'Minor traffic accident documentation report',
      keywords: 'Guardian360, Kroka, accident, insurance, police',
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
          textDirection: pw.TextDirection.rtl,
        ),
        footer: (context) => _footer(context, input),
        build: (context) => [
          _header(input),
          pw.SizedBox(height: 12),
          _legalNotice(),
          pw.SizedBox(height: 14),
          _section(
            title: 'بيانات التقرير',
            icon: '01',
            rows: [
              _row('الرقم المرجعي', input.referenceCode),
              _row('معرف التقرير', input.reportId),
              _row('نوع التقرير', 'توثيق حادث مروري بسيط'),
              _row(
                'وقت إنشاء التقرير',
                _formatDateTime(input.submittedAtClient),
              ),
              _row('نسخة التقرير', 'v${GeneratedReportModel.currentVersion}'),
            ],
          ),
          _section(
            title: 'موقع الحادث والمؤشرات',
            icon: '02',
            rows: [
              _row('الموقع', _fallback(input.locationName, 'غير محدد بالاسم')),
              _row(
                'الإحداثيات',
                '${input.latitude.toStringAsFixed(6)}, ${input.longitude.toStringAsFixed(6)}',
              ),
              _row(
                'دقة الموقع',
                '${input.locationAccuracyMeters.toStringAsFixed(0)} م',
              ),
              _row(
                'وقت التقاط الموقع',
                _formatDateTime(input.locationCapturedAtClient),
              ),
              _row(
                'سرعة الجهاز عند الالتقاط',
                input.speedKmhAtCapture == null
                    ? 'غير متاحة'
                    : '${input.speedKmhAtCapture!.toStringAsFixed(1)} كم/س',
              ),
              _row(
                'اتجاه الجهاز',
                input.headingDegreesAtCapture == null
                    ? 'غير متاح'
                    : '${input.headingDegreesAtCapture!.toStringAsFixed(0)}°',
              ),
            ],
          ),
          _section(
            title: 'بيانات الحادث',
            icon: '03',
            rows: [
              _row('مكان الضرر', input.damageLabel),
              _row('تقدير المسؤولية', _faultLabel(input.faultEstimate)),
              _row(
                'ملاحظات المستخدم',
                _fallback(input.notes, 'لا توجد ملاحظات'),
              ),
            ],
          ),
          _section(
            title: 'بيانات المركبات',
            icon: '04',
            rows: [
              _row('لوحة مركبتي', _plateLabel(input.myVehiclePlate)),
              _row(
                'مصدر لوحة مركبتي',
                _plateSourceLabel(input.myVehiclePlate.source),
              ),
              _row(
                'لوحة الطرف الآخر',
                input.otherVehiclePlate == null
                    ? 'غير مدخلة'
                    : _plateLabel(input.otherVehiclePlate!),
              ),
              _row(
                'مصدر لوحة الطرف الآخر',
                input.otherVehiclePlate == null
                    ? 'غير متاح'
                    : _plateSourceLabel(input.otherVehiclePlate!.source),
              ),
            ],
          ),
          _section(
            title: 'توثيق السائق صاحب البلاغ',
            icon: '05',
            rows: [
              _row('رخصة صاحب البلاغ', _licenseSummary(input.myDriverLicense)),
              _row(
                'نطاق التوثيق',
                'توثيق الرخصة مخصص لصاحب البلاغ فقط، بينما توثق بيانات الطرف الآخر عبر اللوحة والأدلة والشهود لتجنب أي احتكاك بين الأطراف.',
              ),
            ],
          ),
          _section(
            title: 'الأدلة المرفقة',
            icon: '06',
            rows: _evidenceRows(input.evidenceItems),
          ),
          _timelineSection(input.evidenceItems),
          _qrSection(input),
        ],
      ),
    );

    return doc.save();
  }

  Future<_PdfFonts> _loadFontsSafely() async {
    try {
      final regular = await PdfGoogleFonts.cairoRegular();
      final bold = await PdfGoogleFonts.cairoBold();
      return _PdfFonts(regular: regular, bold: bold);
    } catch (_) {
      return _PdfFonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  pw.Widget _header(KrokaPdfReportInput input) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#8B0000'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Guardian360',
                  textDirection: pw.TextDirection.ltr,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'تقرير الكروكة الذكية للحوادث البسيطة',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              input.referenceCode,
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#8B0000'),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _legalNotice() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF7F7'),
        border: pw.Border.all(color: PdfColor.fromHex('#E4CACA')),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        'تنبيه مهني: هذا التقرير يوثق بيانات حادث مروري بسيط كما أدخلها المستخدم، مع أدلة رقمية ومؤشرات موقع ووقت. التقرير لا يمثل حكماً قانونياً نهائياً ولا يغني عن تقييم الشرطة أو الجهات المختصة أو شركة التأمين.',
        style: pw.TextStyle(
          color: PdfColor.fromHex('#6E0000'),
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          height: 1.4,
        ),
      ),
    );
  }

  pw.Widget _section({
    required String title,
    required String icon,
    required List<_ReportRow> rows,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#EADADA')),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#8B0000'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  icon,
                  textDirection: pw.TextDirection.ltr,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                title,
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#8B0000'),
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 9),
          ...rows.map(_rowWidget),
        ],
      ),
    );
  }

  pw.Widget _rowWidget(_ReportRow row) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FAF8F8'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              row.label,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#888888'),
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              row.value,
              textDirection: _looksLatin(row.value)
                  ? pw.TextDirection.ltr
                  : pw.TextDirection.rtl,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#222222'),
                fontSize: 9.8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _timelineSection(List<AccidentEvidenceModel> evidenceItems) {
    final items =
        evidenceItems.where((item) => item.isValid).toList(growable: true)
          ..sort((a, b) => a.capturedAtClient.compareTo(b.capturedAtClient));

    if (items.isEmpty) return pw.SizedBox.shrink();

    final rows = items
        .take(12)
        .map((item) {
          return _row(
            _formatDateTime(item.capturedAtClient),
            '${_evidenceTypeLabel(item.type)} • ${_evidencePurposeLabel(item.purpose)} • ${_captureSourceLabel(item.captureSource)}',
          );
        })
        .toList(growable: false);

    return _section(title: 'التسلسل الزمني للأدلة', icon: '07', rows: rows);
  }

  pw.Widget _qrSection(KrokaPdfReportInput input) {
    final data = input.qrPayload;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 2),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F7F7F7'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 82,
            height: 82,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColor.fromHex('#D8D8D8')),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.BarcodeWidget(
              barcode: Barcode.qrCode(),
              data: data,
              width: 72,
              height: 72,
              drawText: false,
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'رمز تحقق التقرير',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#8B0000'),
                    fontSize: 12.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'يمثل هذا الرمز ملخصاً رقمياً للتقرير المرجعي داخل Guardian360، ويمكن استخدامه لاحقاً للربط مع رابط آمن أو بوابة مراجعة للشرطة أو التأمين.',
                  style: const pw.TextStyle(fontSize: 9.5, height: 1.4),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  data,
                  textDirection: pw.TextDirection.ltr,
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context, KrokaPdfReportInput input) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Guardian360 • ${input.referenceCode} • صفحة ${context.pageNumber}/${context.pagesCount}',
        textDirection: pw.TextDirection.rtl,
        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
      ),
    );
  }

  List<_ReportRow> _evidenceRows(List<AccidentEvidenceModel> evidenceItems) {
    if (evidenceItems.isEmpty) {
      return [_row('الحالة', 'لا توجد أدلة مرفقة')];
    }

    final images = _countEvidenceType(
      evidenceItems,
      AccidentEvidenceType.image,
    );
    final videos = _countEvidenceType(
      evidenceItems,
      AccidentEvidenceType.video,
    );
    final audios = _countEvidenceType(
      evidenceItems,
      AccidentEvidenceType.audio,
    );
    final witnesses = _countEvidenceType(
      evidenceItems,
      AccidentEvidenceType.witnessStatement,
    );
    final plate = evidenceItems
        .where((item) => item.purpose == AccidentEvidencePurpose.vehiclePlate)
        .length;
    final licenses = evidenceItems
        .where((item) => item.purpose == AccidentEvidencePurpose.driverLicense)
        .length;
    final camera = evidenceItems
        .where(
          (item) =>
              item.captureSource == AccidentEvidenceCaptureSource.camera ||
              item.captureSource == AccidentEvidenceCaptureSource.ocrCamera,
        )
        .length;

    return [
      _row('إجمالي الأدلة', evidenceItems.length.toString()),
      _row('صور', images.toString()),
      _row('فيديو', videos.toString()),
      _row('صوت', audios.toString()),
      _row('شهود', witnesses.toString()),
      _row('أدلة اللوحات', plate.toString()),
      _row('أدلة الرخص', licenses.toString()),
      _row('مصادر تصوير مباشر', camera.toString()),
    ];
  }

  int _countEvidenceType(List<AccidentEvidenceModel> items, String type) {
    return items.where((item) => item.type == type).length;
  }

  _ReportRow _row(String label, String value) {
    return _ReportRow(label: label, value: _fallback(value, 'غير متاح'));
  }

  String _plateLabel(VehiclePlateModel plate) {
    return '${plate.code} - ${plate.number} / ${plate.countryCode}';
  }

  String _plateSourceLabel(String? source) {
    switch (source) {
      case VehiclePlateInputSource.ocrCamera:
        return 'OCR - تصوير مباشر';
      case VehiclePlateInputSource.ocrGallery:
      case VehiclePlateInputSource.ocr:
        return 'OCR - من المعرض';
      case VehiclePlateInputSource.editedAfterOcr:
        return 'تم تعديلها بعد OCR';
      case VehiclePlateInputSource.manual:
      default:
        return 'إدخال يدوي';
    }
  }

  String _licenseSummary(DriverLicenseModel? license) {
    if (license == null) return 'غير موثقة';

    final status = _licenseStatusLabel(license.status);
    final parts = <String>[status];

    if (_hasText(license.fullName)) parts.add(license.fullName!.trim());
    if (_hasText(license.licenseNumber)) {
      parts.add('رقم الرخصة: ${license.licenseNumber!.trim()}');
    }
    if (_hasText(license.nationalId)) {
      parts.add('الهوية: ${license.nationalId!.trim()}');
    }
    if (_hasText(license.licenseClass)) {
      parts.add('الفئة: ${license.licenseClass!.trim()}');
    }
    if (license.expiryDate != null) {
      parts.add('الانتهاء: ${_formatDate(license.expiryDate!)}');
    }
    if (license.hasEvidence) parts.add('صورة الرخصة مرفقة كدليل');

    return parts.join(' • ');
  }

  String _licenseStatusLabel(String status) {
    switch (status) {
      case DriverLicenseVerificationStatus.verified:
        return 'تم التوثيق';
      case DriverLicenseVerificationStatus.pendingReview:
        return 'بانتظار المراجعة';
      case DriverLicenseVerificationStatus.skipped:
        return 'تم التخطي';
      case DriverLicenseVerificationStatus.refused:
        return 'رفض الطرف الآخر';
      case DriverLicenseVerificationStatus.notProvided:
      default:
        return 'غير موثقة';
    }
  }

  String _faultLabel(String value) {
    switch (value) {
      case 'me':
        return 'أنا';
      case 'other':
        return 'الطرف الآخر';
      case 'unknown':
        return 'غير متأكد';
      default:
        return 'غير محدد';
    }
  }

  String _evidenceTypeLabel(String type) {
    switch (type) {
      case AccidentEvidenceType.image:
        return 'صورة';
      case AccidentEvidenceType.video:
        return 'فيديو';
      case AccidentEvidenceType.audio:
        return 'صوت';
      case AccidentEvidenceType.witnessStatement:
        return 'شاهد';
      default:
        return type;
    }
  }

  String _evidencePurposeLabel(String purpose) {
    switch (purpose) {
      case AccidentEvidencePurpose.damagePhoto:
        return 'ضرر المركبة';
      case AccidentEvidencePurpose.vehiclePlate:
        return 'لوحة مركبة';
      case AccidentEvidencePurpose.driverLicense:
        return 'رخصة قيادة';
      case AccidentEvidencePurpose.witness:
        return 'شهادة شاهد';
      case AccidentEvidencePurpose.general:
      default:
        return 'دليل عام';
    }
  }

  String _captureSourceLabel(String? source) {
    switch (source) {
      case AccidentEvidenceCaptureSource.camera:
      case AccidentEvidenceCaptureSource.ocrCamera:
        return 'كاميرا';
      case AccidentEvidenceCaptureSource.gallery:
      case AccidentEvidenceCaptureSource.ocrGallery:
        return 'معرض';
      case AccidentEvidenceCaptureSource.filePicker:
        return 'ملف';
      default:
        return 'غير محدد';
    }
  }

  String _fallback(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  bool _looksLatin(String value) {
    return RegExp(r'^[\x00-\x7F]+$').hasMatch(value);
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${_two(local.month)}/${_two(local.day)}';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${_two(local.month)}/${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class KrokaPdfReportInput {
  KrokaPdfReportInput({
    required this.reportId,
    required this.referenceCode,
    required this.userId,
    required this.damageLabel,
    required this.faultEstimate,
    required this.myVehiclePlate,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracyMeters,
    required this.locationCapturedAtClient,
    required this.submittedAtClient,
    required this.qrPayload,
    this.otherVehiclePlate,
    this.myDriverLicense,
    this.otherDriverLicense,
    this.locationName,
    this.speedKmhAtCapture,
    this.headingDegreesAtCapture,
    this.notes,
    this.evidenceItems = const [],
  });

  final String reportId;
  final String referenceCode;
  final String userId;
  final String damageLabel;
  final String faultEstimate;
  final VehiclePlateModel myVehiclePlate;
  final VehiclePlateModel? otherVehiclePlate;
  final DriverLicenseModel? myDriverLicense;
  final DriverLicenseModel? otherDriverLicense;
  final double latitude;
  final double longitude;
  final double locationAccuracyMeters;
  final DateTime locationCapturedAtClient;
  final DateTime submittedAtClient;
  final String qrPayload;
  final String? locationName;
  final double? speedKmhAtCapture;
  final double? headingDegreesAtCapture;
  final String? notes;
  final List<AccidentEvidenceModel> evidenceItems;
}

class _ReportRow {
  const _ReportRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _PdfFonts {
  const _PdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}
