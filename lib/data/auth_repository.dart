import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase Auth, used for Google sign-in.
class AuthRepository {
  const AuthRepository();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<bool> signInWithGoogle() => _auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'io.supabase.qhealth://login-callback',
  );

  Future<void> signOut() => _auth.signOut();
}
