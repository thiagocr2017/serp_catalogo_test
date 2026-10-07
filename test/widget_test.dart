import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serp/main.dart';
import 'package:serp/modules/authorization/authorization_module.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user});

  final User? user;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => user;

  @override
  Future<void> signInWithPassword(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('redirects to /login when unauthenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(user: null),
          ),
        ],
        child: const SerpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar Sesión'), findsWidgets);
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('shows the product module shell when authenticated', (
    tester,
  ) async {
    final user = User(
      id: 'fake-user-id',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(user: user),
          ),
        ],
        child: const SerpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Productos'), findsWidgets);
    expect(find.text('Nuevo producto'), findsOneWidget);
  });
}
