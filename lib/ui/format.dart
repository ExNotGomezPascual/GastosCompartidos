import 'package:intl/intl.dart';

String _clean(String s) => s.replaceAll('.', '');

String monthName(DateTime d) => _clean(DateFormat('MMMM', 'es_CO').format(d));

/// "Hoy", "Ayer" o "1 nov".
String shortDate(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff == -1) return 'Mañana';
  final f = day.year == today.year ? 'd MMM' : 'd MMM y';
  return _clean(DateFormat(f, 'es_CO').format(day));
}

/// "Hoy, 3 nov".
String longDate(DateTime d, {DateTime? now}) {
  final s = shortDate(d, now: now);
  final plain = _clean(DateFormat('d MMM', 'es_CO').format(d));
  return (s == 'Hoy' || s == 'Ayer' || s == 'Mañana') ? '$s, $plain' : s;
}

String greeting(DateTime now) {
  if (now.hour < 12) return 'Buenos días';
  if (now.hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

String timeAgo(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  return shortDate(d, now: n);
}
