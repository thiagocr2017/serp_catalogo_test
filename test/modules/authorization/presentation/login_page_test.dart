import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/authorization/authorization_module.dart';
import 'package:serp/modules/authorization/presentation/pages/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository implements AuthRepository {
  _MockAuthRepository({this.onSignIn});

  final Future<void> Function(String email, String password)? onSignIn;
  final List<List<String>> signIns = [];

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signInWithPassword(String email, String password) async {
    signIns.add([email, password]);
    if (onSignIn != null) {
      await onSignIn!(email, password);
    }
  }

  @override
  Future<void> signOut() async {}
}

Widget _buildTestApp(AuthRepository authRepository) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
    ],
    child: const MaterialApp(
      home: LoginPage(),
    ),
  );
}

void main() {
  testWidgets('formulario vacio muestra validaciones y no envia peticion', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(FilledButton, 'Iniciar Sesión');
    expect(submitButton, findsOneWidget);

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Campo requerido'), findsNWidgets(2));
    expect(mockAuth.signIns, isEmpty);
  });

  testWidgets('correo o clave solo con espacios es rechazado como campo requerido', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, '   ');
    await tester.enterText(textFields.last, '   ');

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Campo requerido'), findsNWidgets(2));
    expect(mockAuth.signIns, isEmpty);
  });

  testWidgets('correo malformado es rechazado', (tester) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'invalid-email');
    await tester.enterText(textFields.last, 'password123');

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo inválido'), findsOneWidget);
    expect(mockAuth.signIns, isEmpty);
  });

  testWidgets('credenciales validas ejecutan signInWithPassword', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'user@example.com');
    await tester.enterText(textFields.last, 'password123');

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(mockAuth.signIns.length, 1);
    expect(mockAuth.signIns.first, ['user@example.com', 'password123']);
  });

  testWidgets('presionar Enter en contraseña envia el formulario', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'user@example.com');
    await tester.enterText(textFields.last, 'password123');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(mockAuth.signIns.length, 1);
    expect(mockAuth.signIns.first, ['user@example.com', 'password123']);
  });

  testWidgets('error de inicio de sesion muestra snackbar', (tester) async {
    final mockAuth = _MockAuthRepository(
      onSignIn: (email, password) async {
        throw const AuthException('Invalid login credentials');
      },
    );
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'user@example.com');
    await tester.enterText(textFields.last, 'wrong-password');

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Error de inicio de sesión: Invalid login credentials'), findsOneWidget);
  });

  testWidgets('correo con mayusculas y espacios es normalizado a minusculas', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, '  User.Test@Example.COM  ');
    await tester.enterText(textFields.last, 'SecretPass123');

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(mockAuth.signIns.length, 1);
    expect(mockAuth.signIns.first, ['user.test@example.com', 'SecretPass123']);
  });

  testWidgets('alternar visibilidad de contraseña conmuta obscureText', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final passwordField = find.byType(TextField).last;
    expect((tester.widget(passwordField) as TextField).obscureText, isTrue);

    final visibilityToggle = find.byTooltip('Mostrar contraseña');
    expect(visibilityToggle, findsOneWidget);

    await tester.tap(visibilityToggle);
    await tester.pumpAndSettle();

    final updatedField = find.byType(TextField).last;
    expect((tester.widget(updatedField) as TextField).obscureText, isFalse);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });

  testWidgets('mientras autentica muestra indicador de carga y deshabilita campos y boton', (
    tester,
  ) async {
    final completer = Completer<void>();
    final mockAuth = _MockAuthRepository(
      onSignIn: (email, password) => completer.future,
    );
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'user@example.com');
    await tester.enterText(textFields.last, 'password123');

    final submitButton = find.widgetWithText(FilledButton, 'Iniciar Sesión');
    await tester.tap(submitButton);
    await tester.pump(); // Start async call without completing future

    // Progress indicator visible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Button disabled (onPressed is null)
    final buttonWidget = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(buttonWidget.onPressed, isNull);

    // Inputs disabled
    final emailWidget = tester.widget<TextFormField>(textFields.first);
    final passWidget = tester.widget<TextFormField>(textFields.last);
    expect(emailWidget.enabled, isFalse);
    expect(passWidget.enabled, isFalse);

    // Tapping submit again does nothing
    await tester.tap(find.byType(FilledButton));
    expect(mockAuth.signIns.length, 1);

    // Complete future
    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('error generico no AuthException muestra snackbar con mensaje', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository(
      onSignIn: (email, password) async {
        throw Exception('Servidor no disponible');
      },
    );
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'user@example.com');
    await tester.enterText(textFields.last, 'pass');

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Error de inicio de sesión: Exception: Servidor no disponible'), findsOneWidget);
  });

  testWidgets('renderiza sin overflow en viewports compactos y permite scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Iniciar Sesión'), findsWidgets);
  });

  testWidgets('presionar Enter en email avanza el foco al campo de contraseña', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'user@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    // The password field should now be focused
    final passwordEditable = find.descendant(
      of: textFields.last,
      matching: find.byType(EditableText),
    );
    final editableTextWidget = tester.widget<EditableText>(passwordEditable);
    expect(editableTextWidget.focusNode.hasFocus, isTrue);
  });

  testWidgets('campos de login declaran autofillHints para email y password', (
    tester,
  ) async {
    final mockAuth = _MockAuthRepository();
    await tester.pumpWidget(_buildTestApp(mockAuth));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    final emailTextField = tester.widget<TextField>(textFields.first);
    final passwordTextField = tester.widget<TextField>(textFields.last);

    expect(emailTextField.autofillHints, contains(AutofillHints.email));
    expect(passwordTextField.autofillHints, contains(AutofillHints.password));
  });

  testWidgets('errores consecutivos reemplazan snackbar anterior inmediatamente', (
    tester,
  ) async {
    var errorCount = 0;
    final mockAuth = _MockAuthRepository(
      onSignIn: (email, password) async {
        errorCount++;
        throw AuthException('Error intento $errorCount');
      },
    );
    await tester.pumpWidget(_buildTestApp(mockAuth));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'user@example.com');
    await tester.enterText(textFields.last, 'pass');

    // First failed attempt
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error intento 1'), findsOneWidget);

    // Second failed attempt
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error intento 2'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
