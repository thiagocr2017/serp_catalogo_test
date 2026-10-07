import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/authorization/authorization_module.dart';
import 'package:serp/modules/authorization/presentation/controllers/login_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepo implements AuthRepository {
  _MockAuthRepo({this.onSignIn});

  final Future<void> Function(String email, String password)? onSignIn;
  int signInCalls = 0;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signInWithPassword(String email, String password) async {
    signInCalls++;
    if (onSignIn != null) {
      await onSignIn!(email, password);
    }
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  group('LoginController', () {
    test('initial state is AsyncData(null)', () {
      final repo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(loginControllerProvider);
      expect(state, const AsyncData<void>(null));
    });

    test('successful login sets AsyncLoading then AsyncData', () async {
      final repo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final states = <AsyncValue<void>>[];
      container.listen(loginControllerProvider, (prev, next) {
        states.add(next);
      });

      await container
          .read(loginControllerProvider.notifier)
          .login('user@test.com', 'password123');

      expect(repo.signInCalls, 1);
      expect(states.any((s) => s is AsyncLoading), isTrue);
      expect(container.read(loginControllerProvider), const AsyncData<void>(null));
    });

    test('failed login captures error into AsyncError', () async {
      final repo = _MockAuthRepo(
        onSignIn: (_, _) async => throw const AuthException('Invalid login credentials'),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(loginControllerProvider.notifier)
          .login('user@test.com', 'wrong-pass');

      final state = container.read(loginControllerProvider);
      expect(state, isA<AsyncError>());
      expect((state as AsyncError).error, isA<AuthException>());
    });

    test('ignores concurrent login calls when already loading', () async {
      final completer = Completer<void>();
      final repo = _MockAuthRepo(
        onSignIn: (_, _) => completer.future,
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final future1 = container
          .read(loginControllerProvider.notifier)
          .login('user@test.com', 'pass');

      // Immediate second call while first is in-flight
      final future2 = container
          .read(loginControllerProvider.notifier)
          .login('user@test.com', 'pass');

      expect(container.read(loginControllerProvider).isLoading, isTrue);

      completer.complete();
      await Future.wait([future1, future2]);

      expect(repo.signInCalls, 1);
    });
  });
}
