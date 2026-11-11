import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_compartidos/core/money.dart';
import 'package:gastos_compartidos/domain/recurrence.dart';
import 'package:gastos_compartidos/domain/settlement.dart';
import 'package:gastos_compartidos/domain/split.dart';

void main() {
  const cop = Currency('COP', r'$', 0, 'Peso colombiano');
  const usd = Currency('USD', r'US$', 2, 'Dólar');

  group('dinero', () {
    test('formatea pesos y dólares', () {
      expect(formatMoney(28000, cop), r'$28.000');
      expect(formatMoney(124000, cop, signed: true), r'+$124.000');
      expect(formatMoney(-45000, cop), r'-$45.000');
      expect(formatMoney(1250, usd), r'US$12,50');
    });

    test('lee lo que escribe el usuario', () {
      expect(parseMoney('28.000', cop), 28000);
      expect(parseMoney(r'$ 120000', cop), 120000);
      expect(parseMoney('12,5', usd), 1250);
      expect(parseMoney('1.234,56', usd), 123456);
      expect(parseMoney('', cop), isNull);
      expect(parsePercent('33,33'), 3333);
      expect(formatPercent(2500), '25');
    });
  });

  group('división', () {
    test('partes iguales reparte el sobrante', () {
      final r = computeShares(amount: 100, type: SplitType.equal, memberIds: [1, 2, 3]);
      expect(r.ok, isTrue);
      expect(r.shares, {1: 34, 2: 33, 3: 33});
    });

    test('montos exactos deben sumar el total', () {
      final bad = computeShares(
          amount: 100, type: SplitType.exact, memberIds: [1, 2], inputs: {1: 60, 2: 30});
      expect(bad.ok, isFalse);
      final ok = computeShares(
          amount: 100, type: SplitType.exact, memberIds: [1, 2], inputs: {1: 70, 2: 30});
      expect(ok.shares, {1: 70, 2: 30});
    });

    test('porcentajes suman 100 % y cuadran al centavo', () {
      final r = computeShares(
          amount: 1000,
          type: SplitType.percent,
          memberIds: [1, 2, 3],
          inputs: {1: 3333, 2: 3333, 3: 3334});
      expect(r.ok, isTrue);
      expect(r.shares.values.reduce((a, b) => a + b), 1000);
      expect(computeShares(
              amount: 1000, type: SplitType.percent, memberIds: [1, 2], inputs: {1: 5000})
          .ok, isFalse);
    });

    test('sin personas o sin monto es inválido', () {
      expect(computeShares(amount: 100, type: SplitType.equal, memberIds: []).ok, isFalse);
      expect(computeShares(amount: 0, type: SplitType.equal, memberIds: [1]).ok, isFalse);
    });
  });

  group('liquidación mínima (datos del mockup)', () {
    // S = Tú, M = Mateo, V = Valentina, J = Juan
    const s = 1, m = 2, v = 3, j = 4;
    final ids = [s, m, v, j];
    Map<int, int> eq(int amt) =>
        computeShares(amount: amt, type: SplitType.equal, memberIds: ids).shares;
    final expenses = [
      LedgerExpense(s, 28000, eq(28000)),
      LedgerExpense(j, 62000, eq(62000)),
      LedgerExpense(m, 184000, eq(184000)),
      LedgerExpense(v, 50000, eq(50000)),
      LedgerExpense(s, 236000, eq(236000)),
    ];

    test('saldos', () {
      final b = computeBalances(ids, expenses, []);
      expect(b, {s: 124000, m: 44000, v: -90000, j: -78000});
    });

    test('3 pagos en lugar de 6', () {
      final b = computeBalances(ids, expenses, []);
      final t = minimalTransfers(b, order: ids);
      expect(t, [
        const Transfer(v, s, 90000),
        const Transfer(j, m, 44000),
        const Transfer(j, s, 34000),
      ]);
      expect(naiveTransferCount(expenses, []), 6);
    });

    test('un pago parcial y uno completo actualizan el saldo', () {
      final payments = [const LedgerPayment(v, s, 90000), const LedgerPayment(j, s, 10000)];
      final b = computeBalances(ids, expenses, payments);
      expect(b, {s: 24000, m: 44000, v: 0, j: -68000});
      final t = minimalTransfers(b, order: ids);
      expect(t.fold<int>(0, (a, x) => a + x.amount), 68000);
      expect(t.length, 2);
    });

    test('grupo saldado no genera pagos', () {
      expect(minimalTransfers({1: 0, 2: 0}), isEmpty);
    });
  });

  group('recurrencia', () {
    test('mensual respeta el día original', () {
      final jan31 = DateTime(2026, 1, 31);
      final feb = nextOccurrence(jan31, Frequency.monthly, 31);
      expect(feb, DateTime(2026, 2, 28));
      expect(nextOccurrence(feb, Frequency.monthly, 31), DateTime(2026, 3, 31));
      expect(nextOccurrence(DateTime(2026, 12, 5), Frequency.monthly, 5), DateTime(2027, 1, 5));
    });

    test('semanal, quincenal y anual', () {
      final d = DateTime(2026, 11, 3);
      expect(nextOccurrence(d, Frequency.weekly, 3), DateTime(2026, 11, 10));
      expect(nextOccurrence(d, Frequency.biweekly, 3), DateTime(2026, 11, 17));
      expect(nextOccurrence(DateTime(2028, 2, 29), Frequency.yearly, 29), DateTime(2029, 2, 28));
    });

    test('fechas pendientes hasta hoy', () {
      final due = dueDates(DateTime(2026, 10, 1), Frequency.monthly, 1, DateTime(2026, 11, 10));
      expect(due, [DateTime(2026, 10, 1), DateTime(2026, 11, 1)]);
      expect(dueDates(DateTime(2026, 12, 1), Frequency.monthly, 1, DateTime(2026, 11, 10)), isEmpty);
    });
  });
}
