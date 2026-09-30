import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/modules/configuration/api/configuration_api.dart';

void main() {
  test(
    'design preferences command excludes logo and selected agent fields',
    () {
      const values = CatalogDesignPreferencesInput(
        cardsPerPage: 4,
        backgroundColor: '#FFFFFF',
        cardColor: '#FFFFFF',
        designAccentColor: '#3949AB',
        textColor: '#111111',
        highlightTextColor: '#1565C0',
        secondaryTextColor: '#616161',
        promotionColor: '#C62828',
        promotionTextColor: '#FFFFFF',
        promotionPreviousPriceColor: '#757575',
        promotionPriceColor: '#C62828',
        promotionDescriptionColor: '#C62828',
        imageFit: 'cover',
      );
      const command = SaveCatalogPreferencesCommand(
        values: values,
        expectedVersion: 7,
        identity: IdentityContext(
          actorName: 'Equipo local',
          deviceName: 'Mac',
          deviceIdentifier: 'device-001',
        ),
      );

      expect(command.values.cardsPerPage, 4);
      expect(command.expectedVersion, 7);
    },
  );

  test(
    'new catalog response exposes a canonical logo reference, not a URL',
    () {
      const preferences = CatalogPreferencesDto(
        cardsPerPage: 4,
        backgroundColor: '#FFFFFF',
        cardColor: '#FFFFFF',
        designAccentColor: '#3949AB',
        textColor: '#111111',
        highlightTextColor: '#1565C0',
        secondaryTextColor: '#616161',
        promotionColor: '#C62828',
        promotionTextColor: '#FFFFFF',
        promotionPreviousPriceColor: '#757575',
        promotionPriceColor: '#C62828',
        promotionDescriptionColor: '#C62828',
        imageFit: 'cover',
        logoObjectName: 'catalog-logo',
        logoVersion: 3,
        selectedAgentId: null,
        version: 7,
      );

      expect(preferences.logoObjectName, 'catalog-logo');
      expect(preferences.logoVersion, 3);
    },
  );
}
