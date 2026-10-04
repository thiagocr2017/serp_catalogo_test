class PhoneNumberParts {
  const PhoneNumberParts({
    required this.countryCode,
    required this.localNumber,
  });

  final String countryCode;
  final String localNumber;
}

const defaultPhoneCountryCode = '+506';

String phoneDigitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

String normalizeCountryCode(String value) {
  final digits = phoneDigitsOnly(value);
  return digits.isEmpty ? defaultPhoneCountryCode : '+$digits';
}

PhoneNumberParts splitPhoneNumber(
  String? value, {
  String defaultCountryCode = defaultPhoneCountryCode,
}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return PhoneNumberParts(countryCode: defaultCountryCode, localNumber: '');
  }
  final digits = phoneDigitsOnly(raw);
  final defaultCountryDigits = phoneDigitsOnly(defaultCountryCode);
  if (raw.startsWith('+') &&
      digits.startsWith(defaultCountryDigits) &&
      digits.length > defaultCountryDigits.length) {
    return PhoneNumberParts(
      countryCode: '+$defaultCountryDigits',
      localNumber: digits.substring(defaultCountryDigits.length),
    );
  }
  if (raw.startsWith('+') && digits.length > 8) {
    return PhoneNumberParts(
      countryCode: '+${digits.substring(0, digits.length - 8)}',
      localNumber: digits.substring(digits.length - 8),
    );
  }
  return PhoneNumberParts(countryCode: defaultCountryCode, localNumber: digits);
}

bool isValidLocalPhone(String value) => phoneDigitsOnly(value).length >= 8;

String formatLocalPhone(String value) {
  final digits = phoneDigitsOnly(value);
  if (digits.length == 8) {
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }
  if (digits.length > 4) {
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }
  return digits;
}

String formatPhoneNumber({
  required String countryCode,
  required String localNumber,
}) {
  final normalizedCountry = normalizeCountryCode(countryCode);
  final localDigits = phoneDigitsOnly(localNumber);
  return '$normalizedCountry ${formatLocalPhone(localDigits)}'.trim();
}

String? nullableFormattedPhone({
  required String countryCode,
  required String localNumber,
}) {
  final localDigits = phoneDigitsOnly(localNumber);
  if (localDigits.isEmpty) return null;
  return formatPhoneNumber(countryCode: countryCode, localNumber: localDigits);
}

String displayPhone(String? value) {
  final parts = splitPhoneNumber(value);
  if (parts.localNumber.isEmpty) return '';
  return formatPhoneNumber(
    countryCode: parts.countryCode,
    localNumber: parts.localNumber,
  );
}
