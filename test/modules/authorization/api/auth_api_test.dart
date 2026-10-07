import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/authorization/authorization_module.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo();

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

  void emitAuthState(AuthChangeEvent event, User? user) {
    currentUser = user;
    _controller.add(
      AuthState(
        event,
        user != null
            ? Session(
                accessToken: 'token',
                tokenType: 'bearer',
                user: user,
              )
            : null,
      ),
    );
  }

  void dispose() {
    _controller.close();
  }
}

User _buildUser(String id) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  group('Auth API and providers', () {
    late _FakeAuthRepo repo;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeAuthRepo();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      repo.dispose();
    });

    test('currentUserProvider initially returns null when no user exists', () {
      final user = container.read(currentUserProvider);
      expect(user, isNull);
    });

    test('currentUserProvider reacts dynamically to auth state changes', () async {
      final sub = container.listen(currentUserProvider, (_, _) {});
      addTearDown(sub.close);

      expect(container.read(currentUserProvider), isNull);

      final loggedInUser = _buildUser('user-123');
      repo.emitAuthState(AuthChangeEvent.signedIn, loggedInUser);

      await pumpEventQueue();

      expect(container.read(currentUserProvider), equals(loggedInUser));

      // Sign out
      await repo.signOut();
      await pumpEventQueue();

      expect(container.read(currentUserProvider), isNull);
    });

    test('authStateChangesProvider streams auth state changes', () async {
      final states = <AuthState>[];
      final subscription = container.listen(
        authStateChangesProvider,
        (prev, next) {
          next.whenData(states.add);
        },
      );

      final user = _buildUser('user-456');
      repo.emitAuthState(AuthChangeEvent.signedIn, user);
      await pumpEventQueue();

      expect(states, hasLength(1));
      expect(states.first.event, AuthChangeEvent.signedIn);

      subscription.close();
    });
  });
}
