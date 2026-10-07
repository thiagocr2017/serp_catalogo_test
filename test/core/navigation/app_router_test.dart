import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/navigation/app_router.dart';
import 'package:serp/modules/authorization/authorization_module.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestAuthRepo implements AuthRepository {
  _TestAuthRepo();

  final _controller = StreamController<AuthState>.broadcast();

  @override
  User? currentUser;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<void> signInWithPassword(String email, String password) async {}

  @override
  Future<void> signOut() async {
    currentUser = null;
    _controller.add(
      AuthState(AuthChangeEvent.signedOut, null),
    );
  }

  void login(User user) {
    currentUser = user;
    _controller.add(
      AuthState(
        AuthChangeEvent.signedIn,
        Session(
          accessToken: 'tok',
          tokenType: 'bearer',
          user: user,
        ),
      ),
    );
  }

  void dispose() {
    _controller.close();
  }
}

User _fakeUser() {
  return User(
    id: 'test-user-id',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  group('appRouterProvider route guards', () {
    late _TestAuthRepo repo;

    setUp(() {
      repo = _TestAuthRepo();
    });

    tearDown(() {
      repo.dispose();
    });

    testWidgets('redirects to /login when user is unauthenticated', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.text('Iniciar Sesión'), findsWidgets);
    });

    testWidgets('redirects from /login to /products when user is authenticated', (
      tester,
    ) async {
      repo.currentUser = _fakeUser();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/products');
    });

    testWidgets('redirects to /login when user logs out in real time', (
      tester,
    ) async {
      repo.currentUser = _fakeUser();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/products');

      // Now trigger sign out
      await repo.signOut();
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/login');
    });

    testWidgets('redirects authenticated user attempting to access /login or /login/ or /', (
      tester,
    ) async {
      repo.currentUser = _fakeUser();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/products');

      // Test going to /login
      router.go('/login');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/products');

      // Test going to /login/
      router.go('/login/');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/products');

      // Test going to root /
      router.go('/');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/products');
    });

    testWidgets('redirects unauthenticated user accessing deep protected route to /login', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/inventory/transfers');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.text('Iniciar Sesión'), findsWidgets);
    });

    testWidgets('normalizes unauthenticated access to /login/ to canonical /login', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/login/');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.text('Iniciar Sesión'), findsWidgets);
    });

    testWidgets('normalizes authenticated route with trailing slash to canonical path', (
      tester,
    ) async {
      repo.currentUser = _fakeUser();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/products/');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/products');
    });

    testWidgets('safely disposes appRouterProvider without ValueNotifier errors', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.dispose();
      // Emitting auth state after disposal should not throw
      repo.login(_fakeUser());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
