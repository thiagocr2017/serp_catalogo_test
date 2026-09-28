class CatalogAgent {
  const CatalogAgent({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;
}

class CatalogPreferences {
  const CatalogPreferences({
    this.cardsPerPage = 4,
    this.backgroundColor = '#FFFFFF',
    this.cardColor = '#FFFFFF',
    this.designAccentColor = '#3949AB',
    this.textColor = '#111111',
    this.highlightTextColor = '#1565C0',
    this.secondaryTextColor = '#616161',
    this.promotionColor = '#C62828',
    this.promotionTextColor = '#FFFFFF',
    this.promotionPreviousPriceColor = '#757575',
    this.promotionPriceColor = '#C62828',
    this.promotionDescriptionColor = '#C62828',
    this.imageFit = 'cover',
    this.logoUrl,
    this.selectedAgentId,
  });

  final int cardsPerPage;
  final String backgroundColor;
  final String cardColor;
  final String designAccentColor;
  final String textColor;
  final String highlightTextColor;
  final String secondaryTextColor;
  final String promotionColor;
  final String promotionTextColor;
  final String promotionPreviousPriceColor;
  final String promotionPriceColor;
  final String promotionDescriptionColor;
  final String imageFit;
  final String? logoUrl;
  final String? selectedAgentId;
}
