import 'package:flutter_test/flutter_test.dart';

import 'package:ringlink/core/config/app_config.dart';

void main() {
  test('configuration is not considered valid with placeholder Supabase values', () {
    expect(AppConfig.isConfigured, isFalse);
  });

  test('RingLink defaults to a 1.5 km discovery radius', () {
    expect(AppConfig.defaultRadiusMeters, 1500.0);
  });
}
