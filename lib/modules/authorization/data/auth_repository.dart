import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/auth_api.dart';

class SupabaseAuthRepository implements AuthRepository {
  final GoTrueClient _auth;
  SupabaseAuthRepository(this._auth);

  @override
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signInWithPassword(String email, String password) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
