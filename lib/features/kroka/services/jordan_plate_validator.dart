import '../models/vehicle_plate_model.dart';

class JordanPlateValidator {
  const JordanPlateValidator();

  static const int minPlateCode = 0;
  static const int maxPlateCode = 99;
  static const int minPlateNumber = 1;
  static const int maxPlateNumber = 99999;

  JordanPlateValidationResult validate({
    required String rawCode,
    required String rawNumber,
    required bool required,
    String source = VehiclePlateInputSource.manual,
    double? confidence,
    String? rawText,
  }) {
    final normalizedCode = _normalizeDigits(rawCode).trim();
    final normalizedNumber = _normalizeDigits(rawNumber).trim();

    if (!required && normalizedCode.isEmpty && normalizedNumber.isEmpty) {
      return const JordanPlateValidationResult.optionalEmpty();
    }

    if (normalizedCode.isEmpty || normalizedNumber.isEmpty) {
      return const JordanPlateValidationResult.failure(
        errorKey: 'kroka.errors.plate_required',
      );
    }

    if (!_isDigitsOnly(normalizedCode) || !_isDigitsOnly(normalizedNumber)) {
      return const JordanPlateValidationResult.failure(
        errorKey: 'kroka.errors.plate_digits_only',
      );
    }

    final code = int.tryParse(normalizedCode);
    final number = int.tryParse(normalizedNumber);

    if (code == null || code < minPlateCode || code > maxPlateCode) {
      return const JordanPlateValidationResult.failure(
        errorKey: 'kroka.errors.invalid_plate_code',
      );
    }

    if (number == null || number < minPlateNumber || number > maxPlateNumber) {
      return const JordanPlateValidationResult.failure(
        errorKey: 'kroka.errors.invalid_plate_number',
      );
    }

    return JordanPlateValidationResult.success(
      VehiclePlateModel.normalized(
        code: code,
        number: number,
        source: source,
        confidence: confidence,
        rawText: rawText,
      ),
    );
  }

  String _normalizeDigits(String value) {
    const digitMap = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    final buffer = StringBuffer();

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(digitMap[char] ?? char);
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), '');
  }

  bool _isDigitsOnly(String value) {
    return RegExp(r'^[0-9]+$').hasMatch(value);
  }
}

class JordanPlateValidationResult {
  const JordanPlateValidationResult._({
    required this.isValid,
    required this.isOptionalEmpty,
    this.plate,
    this.errorKey,
  });

  const JordanPlateValidationResult.optionalEmpty()
    : this._(isValid: true, isOptionalEmpty: true);

  const JordanPlateValidationResult.failure({required String errorKey})
    : this._(isValid: false, isOptionalEmpty: false, errorKey: errorKey);

  const JordanPlateValidationResult.success(VehiclePlateModel plate)
    : this._(isValid: true, isOptionalEmpty: false, plate: plate);

  final bool isValid;
  final bool isOptionalEmpty;
  final VehiclePlateModel? plate;
  final String? errorKey;
}
