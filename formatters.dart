import 'package:intl/intl.dart';

class Formatters {
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String time(Object? value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('HH:mm').format(parsed.toLocal());
  }

  static String dateTime(Object? value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('dd MMM, HH:mm').format(parsed.toLocal());
  }
}
