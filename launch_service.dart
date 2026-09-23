import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LaunchService {
  static Future<bool> call(String phone) {
    return launchUrl(Uri(scheme: 'tel', path: phone));
  }

  static Future<void> callPhone(BuildContext context, String phone) async {
    final launched = await call(phone);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The phone dialer could not be opened.')),
      );
    }
  }

  static Future<bool> openWeb(String url) {
    return launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}
