import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String role,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
        'phone': phone.trim(),
        'account_role': role,
      },
    );
  }

  Future<void> sendPhoneOtp(String phone) {
    return _client.auth.signInWithOtp(phone: phone.trim());
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      phone: phone.trim(),
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
