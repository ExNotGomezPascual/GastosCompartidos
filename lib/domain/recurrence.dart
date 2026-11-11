enum Frequency {
  weekly('Semanal'),
  biweekly('Quincenal'),
  monthly('Mensual'),
  yearly('Anual');

  const Frequency(this.label);
  final String label;

  static Frequency parse(String s) =>
      Frequency.values.firstWhere((f) => f.name == s, orElse: () => Frequency.monthly);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Siguiente fecha de un gasto recurrente. [anchorDay] es el día del mes
/// original, para que un gasto del 31 caiga el 30 o 28 sin quedarse ahí.
DateTime nextOccurrence(DateTime from, Frequency f, int anchorDay) {
  final d = dateOnly(from);
  switch (f) {
    case Frequency.weekly:
      return DateTime(d.year, d.month, d.day + 7);
    case Frequency.biweekly:
      return DateTime(d.year, d.month, d.day + 14);
    case Frequency.monthly:
      final y = d.month == 12 ? d.year + 1 : d.year;
      final m = d.month == 12 ? 1 : d.month + 1;
      final day = anchorDay.clamp(1, _daysInMonth(y, m));
      return DateTime(y, m, day);
    case Frequency.yearly:
      final day = anchorDay.clamp(1, _daysInMonth(d.year + 1, d.month));
      return DateTime(d.year + 1, d.month, day);
  }
}

/// Fechas pendientes de generar hasta [today] inclusive, empezando en [next].
List<DateTime> dueDates(DateTime next, Frequency f, int anchorDay, DateTime today,
    {int max = 60}) {
  final out = <DateTime>[];
  var cur = dateOnly(next);
  final t = dateOnly(today);
  while (!cur.isAfter(t) && out.length < max) {
    out.add(cur);
    cur = nextOccurrence(cur, f, anchorDay);
  }
  return out;
}
