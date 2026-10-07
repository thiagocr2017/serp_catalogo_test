import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  Future<void> signInWithPassword(String email, String password);
  Future<void> signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw StateError('authRepositoryProvider must be overridden in main.dart');
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final subscription = repository.authStateChanges.listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(subscription.cancel);
  return repository.currentUser;
});
