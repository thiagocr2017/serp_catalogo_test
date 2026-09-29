class BusinessSettings {
  const BusinessSettings({
    required this.defaultCurrency,
    required this.decimalPlaces,
    required this.taxPercentage,
    required this.pricesIncludeTax,
    required this.roundingMode,
    required this.roundingIncrement,
    required this.companyName,
    required this.paymentMethods,
    this.appMode = 'TEST',
    this.isSuperAdmin = false,
  });
  final String defaultCurrency;
  final int decimalPlaces;
  final double taxPercentage;
  final bool pricesIncludeTax;
  final String roundingMode;
  final double roundingIncrement;
  final String companyName;
  final String paymentMethods;
  final String appMode;
  final bool isSuperAdmin;
}
