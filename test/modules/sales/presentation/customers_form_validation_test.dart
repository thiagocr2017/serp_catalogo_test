import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/configuration/api/configuration_api.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/api/sales_routes.dart';
import 'package:serp/modules/sales/presentation/pages/customers_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cliente sin nombre exige correccion antes de guardar', (
    tester,
  ) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escriba el nombre del negocio.'), findsOneWidget);
    expect(find.byType(CustomerFormPage), findsOneWidget);
    expect(api.createdCustomers, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Teléfono'),
      '88887777',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo principal'),
      'cliente@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Dirección'),
      'San José',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Número de documento'),
      '3-101-123456',
    );
    await _selectCustomerType(tester, 'Crédito');
    await tester.enterText(
      find.widgetWithText(TextField, 'Días de crédito'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Límite de crédito'),
      '300.75',
    );
    await _selectProvince(tester, 'San José');
    await tester.enterText(
      find.widgetWithText(TextField, 'Gira (agrupación comercial)'),
      'Gira Central',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.createdCustomerName, 'Cliente Test');
    expect(api.createdPhone, '+506 8888-7777');
    expect(api.createdEmail, 'cliente@example.com');
    expect(api.createdAddress, 'San José');
    expect(api.createdTaxId, '3-101-123456');
    expect(api.createdCreditLimit, 300.75);
    expect(api.createdProvince, 'San José');
    expect(api.createdGira, 'Gira Central');
    expect(api.createdPreferredCarrierId, isNull);
  });

  testWidgets(
    'formulario vacio al guardar muestra advertencias requeridas y no guarda',
    (tester) async {
      final api = _RecordingCustomerApi();

      await tester.pumpWidget(
        _app(api, identificationTypes: _identificationTypes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      // No escribimos absolutamente nada en el formulario y presionamos Guardar
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // Comprobar que aparece la advertencia requerida de nombre fiscal
      expect(find.text('Escriba el nombre del negocio.'), findsOneWidget);
      // Comprobar que aparece el SnackBar informativo
      expect(
        find.text('Por favor revise los campos requeridos marcados en rojo.'),
        findsOneWidget,
      );

      // Comprobar que NO aparecen advertencias espurias en campos opcionales
      expect(find.text('Ingrese al menos 8 dígitos.'), findsNothing);
      expect(find.text('Ingrese un correo válido.'), findsNothing);
      expect(find.text('Requerido para factura electrónica.'), findsNothing);
      expect(
        find.text(
          'Correo de documentación obligatorio para factura electrónica.',
        ),
        findsNothing,
      );
      expect(find.text('Ingrese días de crédito.'), findsNothing);

      // El formulario permanece abierto y no se persiste
      expect(find.byType(CustomerFormPage), findsOneWidget);
      expect(api.createdCustomers, 0);
    },
  );

  testWidgets(
    'formulario vacio con factura electronica activada verifica nuevas reglas y muestra todas las advertencias pertinentes a la vez',
    (tester) async {
      final api = _RecordingCustomerApi();

      await tester.pumpWidget(
        _app(api, identificationTypes: _identificationTypes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      // Seleccionamos Factura electrónica en documento habitual (activa e-invoice y bloquea switch)
      await _selectDocumentPreference(tester, 'Factura electrónica');
      await tester.pumpAndSettle();

      // Verificar que el switch de factura electrónica se activó, está destacado y bloqueado
      expect(find.text('Requiere factura electrónica'), findsOneWidget);
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
      expect(switchWidget.onChanged, isNull);

      // Sin escribir ningún dato en el formulario, presionamos Guardar
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // 1. Advertencia de nombre fiscal requerida
      expect(find.text('Escriba el nombre del negocio.'), findsOneWidget);

      // 2. Advertencias de las nuevas reglas de factura electrónica (tipo, doc, actividad, dirección)
      expect(
        find.text('Requerido para factura electrónica.'),
        findsNWidgets(4),
      );

      // 3. Advertencia de correo de documentación obligatorio
      expect(
        find.text(
          'Correo de documentación obligatorio para factura electrónica.',
        ),
        findsOneWidget,
      );

      // 4. SnackBar informativo general
      expect(
        find.text('Por favor revise los campos requeridos marcados en rojo.'),
        findsOneWidget,
      );

      // Formulario no guarda
      expect(find.byType(CustomerFormPage), findsOneWidget);
      expect(api.createdCustomers, 0);

      // Verificación reactiva: al escribir el nombre, su advertencia se remueve
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
        'Corporación Global S.A.',
      );
      await tester.pumpAndSettle();
      expect(find.text('Escriba el nombre del negocio.'), findsNothing);
      expect(
        find.text('Requerido para factura electrónica.'),
        findsNWidgets(4),
      );

      // Completar los campos requeridos por las reglas de factura electrónica
      await _selectIdentificationType(tester, 'Cédula jurídica');
      await tester.enterText(
        find.widgetWithText(TextField, 'Número de documento'),
        '3-101-987654',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Actividad económica'),
        '464900',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Correo principal'),
        'facturas@corporacion.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Dirección'),
        'San José, Calle Central y Avenida 2',
      );

      // Guardar con datos completos y válidos
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // Se guardó exitosamente con las nuevas reglas
      expect(api.createdCustomers, 1);
      expect(api.createdCustomerName, 'Corporación Global S.A.');
      expect(api.createdRequiresEInvoice, isTrue);
      expect(api.createdDocumentPreference, 'E_INVOICE');
      expect(api.createdIdentificationTypeId, 'type-1');
      expect(api.createdTaxId, '3-101-987654');
      expect(api.createdEconomicActivity, '464900');
      expect(api.createdEmail, 'facturas@corporacion.com');
      expect(api.createdAddress, 'San José, Calle Central y Avenida 2');
    },
  );

  testWidgets('cliente con contacto incompleto muestra error', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Test',
    );
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Agregar'));
    await tester.tap(find.widgetWithText(TextButton, 'Agregar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerFormPage), findsOneWidget);
    expect(api.createdCustomers, 0);
    expect(
      find.text(
        'Cada contacto necesita nombre, teléfono de al menos 8 dígitos y cargo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('contacto agregado exige telefono y cargo', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Test',
    );
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Agregar'));
    await tester.tap(find.widgetWithText(TextButton, 'Agregar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del contacto'),
      'Compradora',
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cada contacto necesita nombre, teléfono de al menos 8 dígitos y cargo.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CustomerFormPage), findsOneWidget);
    expect(api.createdCustomers, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Teléfono').last,
      '99998888',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cada contacto necesita nombre, teléfono de al menos 8 dígitos y cargo.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CustomerFormPage), findsOneWidget);
    expect(api.createdCustomers, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Rol (Compras, Gerencia…)'),
      'Compras',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.savedContacts.single.name, 'Compradora');
    expect(api.savedContacts.single.phone, '+506 9999-8888');
    expect(api.savedContacts.single.role, 'Compras');
  });

  testWidgets('cliente rechaza limite de credito no numerico', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Test',
    );
    await _selectCustomerType(tester, 'Crédito');
    await tester.enterText(
      find.widgetWithText(TextField, 'Días de crédito'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Límite de crédito'),
      'abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese un número válido.'), findsOneWidget);
    expect(find.byType(CustomerFormPage), findsOneWidget);
    expect(api.createdCustomers, 0);
  });

  testWidgets('cliente rechaza telefono menor a 8 digitos', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Test',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Teléfono'), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese al menos 8 dígitos.'), findsOneWidget);
    expect(find.byType(CustomerFormPage), findsOneWidget);
    expect(api.createdCustomers, 0);
  });

  testWidgets('cliente rechaza email invalido', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo principal'),
      'correo-invalido',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese un correo válido.'), findsOneWidget);
    expect(api.createdCustomers, 0);
  });

  testWidgets('cliente guarda correo principal y copias', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Emails',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo principal'),
      'principal@example.com',
    );
    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Agregar correo'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Agregar correo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo 1'),
      'copia1@example.com',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Agregar correo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo 2'),
      'copia2@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.createdEmail, 'principal@example.com');
    expect(api.savedEmails.length, 3);
    expect(
      api.savedEmails
          .where((e) => e.purpose == CustomerEmailPurpose.copy)
          .length,
      2,
    );
    expect(
      api.savedEmails
          .where((e) => e.purpose == CustomerEmailPurpose.primary)
          .length,
      1,
    );
  });

  testWidgets('cliente existente actualiza correo en copia', (tester) async {
    const customerId = 'customer-1';
    final api = _RecordingCustomerApi(
      initialCustomers: const [
        CustomerDto(
          id: customerId,
          name: 'Cliente Actual',
          displayName: 'Actual',
          phone: '+506 1111-2222',
          email: 'principal@example.com',
          documentPreference: 'TICKET',
          isActive: true,
        ),
      ],
      initialEmails: const [
        CustomerEmailDto(
          id: 'email-copy-1',
          customerId: customerId,
          email: 'borrar@example.com',
          purpose: CustomerEmailPurpose.copy,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actual · Cliente Actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Correo 1'),
      'actualizado@example.com',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updatedCustomerId, customerId);
    expect(api.savedEmails.length, 2); // primary + 1 copy
    expect(
      api.savedEmails
          .where(
            (e) =>
                e.id == 'email-copy-1' && e.email == 'actualizado@example.com',
          )
          .length,
      1,
    );
  });

  testWidgets('cliente rechaza correo en copia invalido', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Emails',
    );
    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Agregar correo'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Agregar correo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo 1'),
      'no-es-email',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Un correo en copia no tiene formato válido.'),
      findsOneWidget,
    );
    expect(api.createdCustomers, 0);
  });

  testWidgets(
    'cliente con factura electronica exige todos los datos fiscales',
    (tester) async {
      final api = _RecordingCustomerApi();

      await tester.pumpWidget(
        _app(api, identificationTypes: _identificationTypes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
        'Cliente FE',
      );
      await _enableRequiresEInvoice(tester);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // Identificación, tipo, dirección y actividad comparten el mensaje.
      expect(
        find.text('Requerido para factura electrónica.'),
        findsNWidgets(4),
      );
      expect(
        find.text(
          'Correo de documentación obligatorio para factura electrónica.',
        ),
        findsOneWidget,
      );
      expect(api.createdCustomers, 0);
    },
  );

  testWidgets(
    'cliente con factura electronica solo exige el tipo de identificacion',
    (tester) async {
      final api = _RecordingCustomerApi();

      await tester.pumpWidget(
        _app(api, identificationTypes: _identificationTypes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
        'Cliente FE',
      );
      await _enableRequiresEInvoice(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Número de documento'),
        '123456789',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Correo principal'),
        'fe@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Dirección'),
        'Av. Central 1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Actividad económica'),
        '464900',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Requerido para factura electrónica.'), findsOneWidget);
      expect(api.createdCustomers, 0);
    },
  );

  testWidgets('cliente con factura electronica guarda los datos completos', (
    tester,
  ) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(
      _app(api, identificationTypes: _identificationTypes),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente FE',
    );
    await _enableRequiresEInvoice(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Número de documento'),
      '123456789',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo principal'),
      'fe@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Dirección'),
      'Av. Central 1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Actividad económica'),
      '464900',
    );
    await _selectIdentificationType(tester, 'Cédula jurídica');
    await _selectDocumentPreference(tester, 'Factura electrónica');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.createdRequiresEInvoice, isTrue);
    expect(api.createdTaxId, '123456789');
    expect(api.createdEmail, 'fe@example.com');
    expect(api.createdAddress, 'Av. Central 1');
    expect(api.createdIdentificationTypeId, 'type-1');
    expect(api.createdEconomicActivity, '464900');
    expect(api.createdDocumentPreference, 'E_INVOICE');
  });

  testWidgets('cliente sin factura electronica no exige datos fiscales', (
    tester,
  ) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(
      _app(api, identificationTypes: _identificationTypes),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Simple',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.createdRequiresEInvoice, isFalse);
    expect(api.createdTaxId, isNull);
    expect(api.createdIdentificationTypeId, isNull);
  });

  testWidgets(
    'toggle requiere factura electronica aparece y esta bloqueado cuando documento habitual es Factura electronica',
    (tester) async {
      final api = _RecordingCustomerApi();

      await tester.pumpWidget(
        _app(api, identificationTypes: _identificationTypes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      // Por defecto está en Tiquete y el Switch no debe aparecer
      expect(find.text('Requiere factura electrónica'), findsNothing);
      expect(find.byType(Switch), findsNothing);

      // Al cambiar a Factura electrónica debe aparecer seleccionado y deshabilitado
      await _selectDocumentPreference(tester, 'Factura electrónica');
      expect(find.text('Requiere factura electrónica'), findsOneWidget);
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
      expect(switchWidget.onChanged, isNull);

      // Al volver a Tiquete vuelve a desaparecer
      await _selectDocumentPreference(tester, 'Tiquete');
      expect(find.text('Requiere factura electrónica'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    },
  );

  testWidgets(
    'actividad economica rechaza formato invalido y acepta formato numerico',
    (tester) async {
      final api = _RecordingCustomerApi();

      await tester.pumpWidget(
        _app(api, identificationTypes: _identificationTypes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
        'Cliente FE',
      );
      await _enableRequiresEInvoice(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Número de documento'),
        '123456789',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Correo principal'),
        'fe@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Dirección'),
        'Av. Central 1',
      );
      await _selectIdentificationType(tester, 'Cédula jurídica');

      // Intentar ingresar un código demasiado corto (ej: 12)
      await tester.enterText(
        find.widgetWithText(TextField, 'Actividad económica'),
        '12',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Código CIIU / Hacienda inválido (ej: 464900 ó 464900.1).'),
        findsOneWidget,
      );
      expect(api.createdCustomers, 0);

      // Corregir con formato válido con decimal
      await tester.enterText(
        find.widgetWithText(TextField, 'Actividad económica'),
        '464900.1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(api.createdCustomers, 1);
      expect(api.createdEconomicActivity, '464900.1');
    },
  );

  testWidgets('cliente credito exige dias de credito', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Crédito',
    );
    await _selectCustomerType(tester, 'Crédito');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese días de crédito.'), findsOneWidget);
    expect(api.createdCustomers, 0);
  });

  testWidgets('cliente guarda transporte preferido seleccionado', (
    tester,
  ) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(
      _app(
        api,
        carriers: const [
          CarrierDto(
            id: 'carrier-1',
            name: 'Transporte A',
            isActive: true,
            version: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente con transporte',
    );
    await tester.ensureVisible(find.text('Sin transporte preferido'));
    await tester.tap(find.text('Sin transporte preferido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transporte A').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.createdPreferredCarrierId, 'carrier-1');
  });

  testWidgets('cliente existente carga, actualiza contactos y desactiva', (
    tester,
  ) async {
    final api = _RecordingCustomerApi(
      initialCustomers: const [
        CustomerDto(
          id: 'customer-1',
          name: 'Cliente Actual',
          phone: '+506 1111-2222',
          email: 'actual@example.com',
          province: 'San José',
          gira: 'Gira Central',
          creditLimit: 25,
          documentPreference: 'TICKET',
          isActive: true,
        ),
      ],
      initialContacts: const [
        CustomerContactDto(
          id: 'contact-1',
          customerId: 'customer-1',
          name: 'Comprador',
          phone: '+506 2222-3333',
          role: 'Compras',
        ),
        CustomerContactDto(
          id: 'contact-2',
          customerId: 'customer-1',
          name: 'Gerencia',
          phone: '+506 3333-4444',
          role: 'Gerencia',
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cliente Actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar cliente'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Cliente Actual'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Comprador'), findsOneWidget);
    expect(find.text('Gerencia'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Actualizado',
    );
    await _selectCustomerType(tester, 'Crédito');
    await tester.enterText(
      find.widgetWithText(TextField, 'Días de crédito'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Límite de crédito'),
      '125.50',
    );
    await tester.ensureVisible(find.byTooltip('Quitar contacto').first);
    await tester.tap(find.byTooltip('Quitar contacto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updatedCustomerId, 'customer-1');
    expect(api.updatedCustomerName, 'Cliente Actualizado');
    expect(api.updatedCreditLimit, 125.50);
    expect(api.deletedContactIds, contains('contact-1'));
    expect(api.savedContactIds, contains('contact-2'));

    await tester.tap(find.text('Cliente Actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();
    expect(find.text('Escriba el motivo de desactivación.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo'),
      'Duplicado',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(api.deactivatedCustomerId, 'customer-1');
    expect(api.deactivationReason, 'Duplicado');
  });

  testWidgets('editar sin cambios cancela hacia el perfil sin advertencia', (
    tester,
  ) async {
    final api = _RecordingCustomerApi(
      initialCustomers: const [
        CustomerDto(
          id: 'customer-1',
          name: 'Cliente Actual',
          displayName: 'Actual',
          phone: '+506 1111-2222',
          email: 'actual@example.com',
          documentPreference: 'TICKET',
          isActive: true,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actual · Cliente Actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar cliente'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Salir sin guardar'), findsNothing);
    expect(find.text('Perfil de cliente'), findsOneWidget);
    expect(find.text('Actual'), findsOneWidget);
  });

  testWidgets(
    'editar con hidratación retardada no advierte al cancelar sin tocar nada',
    (tester) async {
      final api = _RecordingCustomerApi(
        hydrateDelay: const Duration(milliseconds: 50),
        initialCustomers: const [
          CustomerDto(
            id: 'customer-1',
            name: 'Cliente Actual',
            displayName: 'Actual',
            phone: '+506 1111-2222',
            email: 'actual@example.com',
            documentPreference: 'TICKET',
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Actual · Cliente Actual'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Editar'));

      // La carga del cliente llega con retardo, asi que la hidratacion cae en
      // un frame distinto al de creacion del estado. Es el caso que el fake
      // sincrono no cubria y bajo el cual se rellenaban los 11 controllers sin
      // linea base a la que comparar.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Editar cliente'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Salir sin guardar'), findsNothing);
      expect(find.text('Perfil de cliente'), findsOneWidget);
    },
  );

  testWidgets('cliente existente permite agregar contacto nuevo al editar', (
    tester,
  ) async {
    final api = _RecordingCustomerApi(
      initialCustomers: const [
        CustomerDto(
          id: 'customer-1',
          name: 'Cliente Actual',
          phone: '+506 1111-2222',
          email: 'actual@example.com',
          documentPreference: 'TICKET',
          isActive: true,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cliente Actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Agregar'));
    await tester.tap(find.widgetWithText(TextButton, 'Agregar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del contacto'),
      'Nueva Compradora',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Teléfono').last,
      '99998888',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Rol (Compras, Gerencia…)'),
      'Compras',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updatedCustomerId, 'customer-1');
    expect(api.savedContacts.single.id, isNull);
    expect(api.savedContacts.single.customerId, 'customer-1');
    expect(api.savedContacts.single.name, 'Nueva Compradora');
    expect(api.savedContacts.single.phone, '+506 9999-8888');
    expect(api.savedContacts.single.role, 'Compras');
  });

  testWidgets(
    'cliente existente sin limite de credito permite agregar contacto',
    (tester) async {
      final api = _RecordingCustomerApi(
        initialCustomers: const [
          CustomerDto(
            id: 'customer-1',
            name: 'Cliente Actual',
            phone: '+506 1111-2222',
            email: 'actual@example.com',
            creditLimit: 250,
            documentPreference: 'TICKET',
            isActive: true,
          ),
        ],
        initialContacts: const [
          CustomerContactDto(
            id: 'contact-1',
            customerId: 'customer-1',
            name: 'Contacto Existente',
            phone: '+506 8888-1111',
            role: 'Gerencia',
          ),
        ],
      );

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cliente Actual'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
      await tester.pumpAndSettle();
      await _selectCustomerType(tester, 'Crédito');
      await tester.enterText(
        find.widgetWithText(TextField, 'Días de crédito'),
        '30',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Límite de crédito'),
        '',
      );
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Agregar'));
      await tester.tap(find.widgetWithText(TextButton, 'Agregar'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del contacto').last,
        'Segundo Contacto',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Teléfono').last,
        '88882222',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Rol (Compras, Gerencia…)').last,
        'Compras',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(api.updatedCustomerId, 'customer-1');
      expect(api.updatedCreditLimit, 0);
      expect(api.savedContacts.map((contact) => contact.name), [
        'Contacto Existente',
        'Segundo Contacto',
      ]);
    },
  );

  testWidgets('cliente guarda pais CR, provincia y ciudad', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Geografía CR',
    );
    await _selectProvince(tester, 'Cartago');
    final cityField = find.widgetWithText(TextField, 'Ciudad / Distrito');
    await tester.ensureVisible(cityField);
    await tester.enterText(cityField, 'Paraíso');

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.createdCustomerName, 'Cliente Geografía CR');
    expect(api.createdCountryCode, 'CR');
    expect(api.createdProvince, 'Cartago');
    expect(api.createdCity, 'Paraíso');
  });

  testWidgets('cliente guarda politica de envio y categorias seleccionadas', (
    tester,
  ) async {
    final api = _RecordingCustomerApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre fiscal / negocio'),
      'Cliente Comercial Test',
    );

    final policyDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Política de pago de envío',
    );
    await tester.ensureVisible(policyDropdown);
    await tester.tap(policyDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cobro contra entrega').last);
    await tester.pumpAndSettle();

    final categoryChip = find.byKey(
      const ValueKey('customerCategoryChip_Mayorista'),
    );
    await tester.ensureVisible(categoryChip);
    await tester.tap(categoryChip);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
    expect(api.createdCustomerName, 'Cliente Comercial Test');
    expect(api.createdShippingPaymentPolicy, 'CASH_ON_DELIVERY');
    expect(api.createdCategoryIds, contains('cat-1'));
  });
}

Widget _app(
  _RecordingCustomerApi customerApi, {
  List<CarrierDto> carriers = const [],
  List<IdentificationTypeDto> identificationTypes = const [],
}) => ProviderScope(
  overrides: [
    customerApiProvider.overrideWithValue(customerApi),
    configurationApiProvider.overrideWithValue(
      _RecordingConfigurationApi(
        carriers: carriers,
        identificationTypes: identificationTypes,
      ),
    ),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/sales/customers',
      routes: salesRoutes,
    ),
  ),
);

Future<void> _selectCustomerType(WidgetTester tester, String label) async {
  await tester.ensureVisible(
    find.widgetWithText(DropdownButtonFormField<String>, 'Tipo de cliente'),
  );
  await tester.tap(
    find.widgetWithText(DropdownButtonFormField<String>, 'Tipo de cliente'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectProvince(WidgetTester tester, String provinceName) async {
  final dropdown = find.widgetWithText(
    DropdownButtonFormField<String>,
    'Provincia',
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(provinceName).last);
  await tester.pumpAndSettle();
}

const _identificationTypes = [
  IdentificationTypeDto(
    id: 'type-1',
    code: 'JURIDICAL_ID',
    name: 'Cédula jurídica',
    isActive: true,
    version: 1,
  ),
];

Future<void> _enableRequiresEInvoice(WidgetTester tester) async {
  await _selectDocumentPreference(tester, 'Factura electrónica');
}

Future<void> _selectIdentificationType(
  WidgetTester tester,
  String label,
) async {
  final dropdown = find.widgetWithText(
    DropdownButtonFormField<String?>,
    'Tipo de documento',
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectDocumentPreference(
  WidgetTester tester,
  String label,
) async {
  await tester.ensureVisible(
    find.widgetWithText(DropdownButtonFormField<String>, 'Documento habitual'),
  );
  await tester.tap(
    find.widgetWithText(DropdownButtonFormField<String>, 'Documento habitual'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _RecordingCustomerApi implements CustomerApi {
  _RecordingCustomerApi({
    this.initialCustomers = const [],
    this.initialContacts = const [],
    this.initialEmails = const [],
    this.hydrateDelay = Duration.zero,
  });

  final List<CustomerDto> initialCustomers;
  final List<CustomerContactDto> initialContacts;

  /// Retardo simulado de red al cargar. Hace que la hidratacion ocurra en un
  /// frame distinto al de la creacion del estado, que es lo que reproduce el
  /// aviso falso de cambios sin guardar.
  final Duration hydrateDelay;
  int createdCustomers = 0;
  String? createdCustomerName;
  String? createdPhone;
  String? createdDisplayName;
  String? createdEmail;
  String? createdAddress;
  String? createdTaxId;
  double? createdCreditLimit;
  String? createdProvince;
  String? createdGira;
  String? createdPreferredCarrierId;
  String? createdIdentificationTypeId;
  String? createdEconomicActivity;
  String? createdCustomerType;
  int? createdCreditDays;
  String? createdDocumentPreference;
  bool createdRequiresEInvoice = false;
  String createdCountryCode = 'CR';
  String? createdCity;
  String createdShippingPaymentPolicy = 'INCLUDED';
  List<String> createdCategoryIds = const [];
  String? updatedCustomerId;
  String? updatedCustomerName;
  double? updatedCreditLimit;
  String? updatedPreferredCarrierId;
  String? updatedIdentificationTypeId;
  String? updatedEconomicActivity;
  bool updatedRequiresEInvoice = false;
  String updatedCountryCode = 'CR';
  String? updatedCity;
  String updatedShippingPaymentPolicy = 'INCLUDED';
  List<String>? updatedCategoryIds;
  String? deactivatedCustomerId;
  String? deactivationReason;
  final savedContactIds = <String?>[];
  final savedContacts = <_SavedContact>[];
  final deletedContactIds = <String>[];
  final List<CustomerEmailDto> initialEmails;
  final savedEmails = <_SavedEmail>[];
  final deletedEmailIds = <String>[];

  @override
  Future<List<CustomerDto>> getCustomers() async => initialCustomers;

  @override
  Future<CustomerDto?> getCustomerById(String id) async {
    if (hydrateDelay > Duration.zero) {
      await Future<void>.delayed(hydrateDelay);
    }
    return initialCustomers.where((customer) => customer.id == id).firstOrNull;
  }

  @override
  Future<CustomerDto> createCustomer({
    required String name,
    String? displayName,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String countryCode = 'CR',
    String? province,
    String? city,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
    bool requiresEInvoice = false,
    String shippingPaymentPolicy = 'INCLUDED',
    List<String> categoryIds = const [],
  }) async {
    createdCustomers++;
    createdCustomerName = name;
    createdDisplayName = displayName;
    createdPhone = phone;
    createdEmail = email;
    createdAddress = address;
    createdTaxId = taxId;
    createdCreditLimit = creditLimit;
    createdCountryCode = countryCode;
    createdProvince = province;
    createdCity = city;
    createdGira = gira;
    createdPreferredCarrierId = preferredCarrierId;
    createdIdentificationTypeId = identificationTypeId;
    createdEconomicActivity = economicActivity;
    createdCustomerType = customerType;
    createdCreditDays = creditDays;
    createdDocumentPreference = documentPreference;
    createdRequiresEInvoice = requiresEInvoice;
    createdShippingPaymentPolicy = shippingPaymentPolicy;
    createdCategoryIds = categoryIds;
    return CustomerDto(
      id: 'customer-new',
      name: name,
      displayName: displayName,
      phone: phone,
      email: email,
      address: address,
      taxId: taxId,
      countryCode: countryCode,
      province: province,
      city: city,
      gira: gira,
      preferredCarrierId: preferredCarrierId,
      identificationTypeId: identificationTypeId,
      economicActivity: economicActivity,
      customerType: customerType,
      creditDays: creditDays,
      documentPreference: documentPreference,
      requiresEInvoice: requiresEInvoice,
      creditLimit: creditLimit ?? 0,
      shippingPaymentPolicy: shippingPaymentPolicy,
      categoryIds: categoryIds,
    );
  }

  @override
  Future<CustomerDto> updateCustomer({
    required String id,
    required String name,
    String? displayName,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String countryCode = 'CR',
    String? province,
    String? city,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
    bool requiresEInvoice = false,
    String shippingPaymentPolicy = 'INCLUDED',
    List<String>? categoryIds,
  }) async {
    updatedCustomerId = id;
    updatedCustomerName = name;
    updatedCreditLimit = creditLimit ?? 0;
    updatedPreferredCarrierId = preferredCarrierId;
    updatedIdentificationTypeId = identificationTypeId;
    updatedEconomicActivity = economicActivity;
    updatedRequiresEInvoice = requiresEInvoice;
    updatedCountryCode = countryCode;
    updatedCity = city;
    updatedShippingPaymentPolicy = shippingPaymentPolicy;
    updatedCategoryIds = categoryIds;
    return CustomerDto(
      id: id,
      name: name,
      displayName: displayName,
      phone: phone,
      email: email,
      address: address,
      taxId: taxId,
      countryCode: countryCode,
      province: province,
      city: city,
      gira: gira,
      preferredCarrierId: preferredCarrierId,
      identificationTypeId: identificationTypeId,
      economicActivity: economicActivity,
      customerType: customerType,
      creditDays: creditDays,
      documentPreference: documentPreference,
      requiresEInvoice: requiresEInvoice,
      creditLimit: creditLimit ?? 0,
      shippingPaymentPolicy: shippingPaymentPolicy,
      categoryIds: categoryIds ?? const [],
    );
  }

  @override
  Future<void> deactivateCustomer(String id, {String? reason}) async {
    deactivatedCustomerId = id;
    deactivationReason = reason;
  }

  @override
  Future<List<CustomerContactDto>> getCustomerContacts(String customerId) async =>
      initialContacts
          .where((contact) => contact.customerId == customerId)
          .toList();

  @override
  Future<CustomerContactDto> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
    DateTime? birthday,
  }) async {
    savedContactIds.add(id);
    savedContacts.add(
      _SavedContact(
        id: id,
        customerId: customerId,
        name: name,
        phone: phone,
        role: role,
        birthday: birthday,
      ),
    );
    return CustomerContactDto(
      id: id ?? 'contact-new',
      customerId: customerId,
      name: name,
      phone: phone,
      role: role,
      birthday: birthday,
    );
  }

  @override
  Future<void> deleteCustomerContact(String id) async {
    deletedContactIds.add(id);
  }

  @override
  Future<List<CustomerEmailDto>> getCustomerEmails(String customerId) async =>
      initialEmails.where((email) => email.customerId == customerId).toList();

  @override
  Future<CustomerEmailDto> saveCustomerEmail({
    String? id,
    required String customerId,
    required String email,
    CustomerEmailPurpose purpose = CustomerEmailPurpose.copy,
    String? label,
    bool isActive = true,
  }) async {
    savedEmails.add(
      _SavedEmail(
        id: id,
        customerId: customerId,
        email: email,
        purpose: purpose,
        label: label,
        isActive: isActive,
      ),
    );
    return CustomerEmailDto(
      id: id ?? 'email-new',
      customerId: customerId,
      email: email,
      purpose: purpose,
      label: label,
      isActive: isActive,
    );
  }

  @override
  Future<void> deleteCustomerEmail(String id) async {
    deletedEmailIds.add(id);
  }

  @override
  Future<List<ProductBuyerDto>> getProductBuyers(String productId) async =>
      const [];

  @override
  Future<CustomerCommercialSummaryDto> getCustomerCommercialSummary(
    String customerId,
  ) async =>
      CustomerCommercialSummaryDto.empty(customerId);

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories() async => [
    const CustomerCategoryDto(id: 'cat-1', name: 'Mayorista'),
    const CustomerCategoryDto(id: 'cat-2', name: 'Detallista'),
  ];
}

class _SavedContact {
  const _SavedContact({
    required this.id,
    required this.customerId,
    required this.name,
    required this.phone,
    required this.role,
    required this.birthday,
  });

  final String? id;
  final String customerId;
  final String name;
  final String? phone;
  final String? role;
  final DateTime? birthday;
}

class _SavedEmail {
  const _SavedEmail({
    required this.id,
    required this.customerId,
    required this.email,
    required this.purpose,
    required this.label,
    required this.isActive,
  });

  final String? id;
  final String customerId;
  final String email;
  final CustomerEmailPurpose purpose;
  final String? label;
  final bool isActive;
}

class _RecordingConfigurationApi implements ConfigurationApi {
  const _RecordingConfigurationApi({
    this.carriers = const [],
    this.identificationTypes = const [],
  });

  final List<CarrierDto> carriers;
  final List<IdentificationTypeDto> identificationTypes;

  @override
  Future<List<CarrierDto>> getCarriers() async => carriers;

  @override
  Future<List<IdentificationTypeDto>> getIdentificationTypes({
    bool includeInactive = false,
  }) async => identificationTypes;

  @override
  Future<IdentificationTypeDto> createIdentificationType(
    CreateIdentificationTypeCommand command,
  ) async => throw UnimplementedError();

  @override
  Future<IdentificationTypeDto> updateIdentificationType(
    UpdateIdentificationTypeCommand command,
  ) async => throw UnimplementedError();

  @override
  Future<BusinessSettingsDto> getBusinessSettings() async =>
      const BusinessSettingsDto(
        defaultCurrency: 'USD',
        decimalPlaces: 2,
        taxPercentage: '0',
        pricesIncludeTax: false,
        roundingMode: 'HALF_UP',
        roundingIncrement: '0.01',
        companyName: '',
        paymentMethods: '',
        version: 1,
      );

  @override
  Future<CatalogPreferencesDto> getCatalogPreferences() async =>
      const CatalogPreferencesDto(
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
        logoObjectName: null,
        logoVersion: 1,
        selectedAgentId: null,
        version: 1,
      );

  @override
  Future<List<PackagingPresentationDto>> getPackagingPresentations() async =>
      const [];

  @override
  Future<BusinessSettingsDto> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  ) async => getBusinessSettings();

  @override
  Future<CatalogPreferencesDto> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) async => getCatalogPreferences();

  @override
  Future<CatalogPreferencesDto> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  ) async => getCatalogPreferences();

  @override
  Future<PackagingPresentationDto> createPackagingPresentation(
    CreatePackagingPresentationCommand command,
  ) async => PackagingPresentationDto(
    id: command.commandId,
    name: command.name,
    sortOrder: 0,
    isActive: true,
    version: 1,
  );

  @override
  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  ) async => PackagingPresentationDto(
    id: command.id,
    name: command.name,
    sortOrder: 0,
    isActive: true,
    version: command.expectedVersion + 1,
  );

  @override
  Future<PackagingPresentationDto> deactivatePackagingPresentation(
    DeactivatePackagingPresentationCommand command,
  ) async => PackagingPresentationDto(
    id: command.id,
    name: 'Presentación',
    sortOrder: 0,
    isActive: false,
    version: command.expectedVersion + 1,
  );

  @override
  Future<CarrierDto> saveCarrier(SaveCarrierCommand command) async =>
      CarrierDto(
        id: command.id ?? command.commandId,
        name: command.name,
        phone: command.phone,
        address: command.address,
        contactName: command.contactName,
        notes: command.notes,
        isActive: true,
        version: (command.expectedVersion ?? 0) + 1,
      );

  @override
  Future<CatalogLogoReferenceDto> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  ) async => CatalogLogoReferenceDto(
    objectName: 'catalog-logo/${command.operationId}',
    version: command.expectedVersion + 1,
  );

  @override
  Future<Uint8List?> downloadCatalogLogo() async => null;

  @override
  Future<List<CountryDto>> getCountries() async => const [
    CountryDto(code: 'CR', name: 'Costa Rica'),
  ];

  @override
  Future<List<AdministrativeAreaDto>> getAdministrativeAreas({
    String countryCode = 'CR',
  }) async => const [
    AdministrativeAreaDto(
      id: 'CR-SJ',
      code: 'SJ',
      countryCode: 'CR',
      name: 'San José',
    ),
    AdministrativeAreaDto(
      id: 'CR-AL',
      code: 'AL',
      countryCode: 'CR',
      name: 'Alajuela',
    ),
    AdministrativeAreaDto(
      id: 'CR-CA',
      code: 'CA',
      countryCode: 'CR',
      name: 'Cartago',
    ),
    AdministrativeAreaDto(
      id: 'CR-HE',
      code: 'HE',
      countryCode: 'CR',
      name: 'Heredia',
    ),
    AdministrativeAreaDto(
      id: 'CR-GU',
      code: 'GU',
      countryCode: 'CR',
      name: 'Guanacaste',
    ),
    AdministrativeAreaDto(
      id: 'CR-PU',
      code: 'PU',
      countryCode: 'CR',
      name: 'Puntarenas',
    ),
    AdministrativeAreaDto(
      id: 'CR-LI',
      code: 'LI',
      countryCode: 'CR',
      name: 'Limón',
    ),
  ];

  @override
  Future<List<CityDto>> getCities({
    String countryCode = 'CR',
    String? provinceName,
  }) async => const [
    CityDto(
      id: '1',
      countryCode: 'CR',
      provinceName: 'San José',
      name: 'San José Central',
    ),
    CityDto(
      id: '2',
      countryCode: 'CR',
      provinceName: 'San José',
      name: 'Escazú',
    ),
  ];
}
