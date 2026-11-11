import 'package:intl/intl.dart';

class Currency {
  const Currency(this.code, this.symbol, this.decimals, this.name);

  final String code;
  final String symbol;

  /// Cuántos decimales usa la moneda (los montos se guardan en unidades mínimas).
  final int decimals;
  final String name;

  int get factor {
    var f = 1;
    for (var i = 0; i < decimals; i++) {
      f *= 10;
    }
    return f;
  }
}

const currencies = <Currency>[
  Currency('COP', r'$', 0, 'Peso colombiano'),
  Currency('USD', r'US$', 2, 'Dólar estadounidense'),
  Currency('EUR', '€', 2, 'Euro'),
  Currency('MXN', r'MX$', 2, 'Peso mexicano'),
  Currency('PEN', 'S/', 2, 'Sol peruano'),
  Currency('CLP', r'CLP$', 0, 'Peso chileno'),
  Currency('ARS', r'AR$', 2, 'Peso argentino'),
  Currency('BRL', r'R$', 2, 'Real brasileño'),
];

Currency currencyOf(String code) =>
    currencies.firstWhere((c) => c.code == code, orElse: () => currencies.first);

/// Formatea un monto en unidades mínimas: `$28.000`, `US$12,50`.
/// Con [signed] antepone `+` a los positivos.
String formatMoney(int minor, Currency c, {bool signed = false}) {
  final negative = minor < 0;
  final value = minor.abs() / c.factor;
  final f = NumberFormat.decimalPatternDigits(
      locale: 'es_CO', decimalDigits: c.decimals);
  final sign = negative ? '-' : (signed && minor > 0 ? '+' : '');
  return '$sign${c.symbol}${f.format(value)}';
}

/// Texto editable de un monto, sin símbolo: `28000`, `12,50`.
String moneyInputText(int minor, Currency c) {
  if (c.decimals == 0) return '$minor';
  final v = minor / c.factor;
  return v.toStringAsFixed(c.decimals).replaceAll('.', ',');
}

/// Convierte lo que escribe el usuario en unidades mínimas.
/// Acepta `28.000`, `28000`, `12,50` y `12.5` (si la moneda tiene decimales).
int? parseMoney(String raw, Currency c) {
  var s = raw.trim().replaceAll(RegExp(r'[^\d.,]'), '');
  if (s.isEmpty) return null;
  if (c.decimals == 0) {
    final digits = s.replaceAll(RegExp(r'[.,]'), '');
    return int.tryParse(digits);
  }
  // La última coma o punto seguido de 1-2 dígitos es el separador decimal.
  final m = RegExp(r'^(.*?)[.,](\d{1,2})$').firstMatch(s);
  String intPart;
  var dec = '';
  if (m != null) {
    intPart = m.group(1)!;
    dec = m.group(2)!;
  } else {
    intPart = s;
  }
  intPart = intPart.replaceAll(RegExp(r'[.,]'), '');
  if (intPart.isEmpty) intPart = '0';
  final i = int.tryParse(intPart);
  if (i == null) return null;
  final d = int.parse(dec.padRight(c.decimals, '0').substring(0, c.decimals));
  return i * c.factor + d;
}

/// Porcentaje en puntos básicos (100 % = 10000) a texto: `25`, `33,33`.
String formatPercent(int bp) {
  if (bp % 100 == 0) return '${bp ~/ 100}';
  return (bp / 100).toStringAsFixed(2).replaceAll('.', ',');
}

int? parsePercent(String raw) {
  final s = raw.trim().replaceAll('%', '').replaceAll(',', '.');
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}
