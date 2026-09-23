import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const RingLinkApp(configurationError: true));
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  runApp(const RingLinkApp());
}
