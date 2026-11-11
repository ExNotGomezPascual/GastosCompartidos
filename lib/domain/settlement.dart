class Transfer {
  const Transfer(this.fromId, this.toId, this.amount);
  final int fromId;
  final int toId;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Transfer &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(fromId, toId, amount);

  @override
  String toString() => 'Transfer($fromId → $toId: $amount)';
}

class LedgerExpense {
  const LedgerExpense(this.payerId, this.amount, this.shares);
  final int payerId;
  final int amount;

  /// memberId → parte.
  final Map<int, int> shares;
}

class LedgerPayment {
  const LedgerPayment(this.fromId, this.toId, this.amount);
  final int fromId;
  final int toId;
  final int amount;
}

/// Saldo de cada integrante: positivo = le deben, negativo = debe.
Map<int, int> computeBalances(
  List<int> memberIds,
  List<LedgerExpense> expenses,
  List<LedgerPayment> payments,
) {
  final b = {for (final id in memberIds) id: 0};
  for (final e in expenses) {
    b[e.payerId] = (b[e.payerId] ?? 0) + e.amount;
    e.shares.forEach((m, s) => b[m] = (b[m] ?? 0) - s);
  }
  for (final p in payments) {
    b[p.fromId] = (b[p.fromId] ?? 0) + p.amount;
    b[p.toId] = (b[p.toId] ?? 0) - p.amount;
  }
  return b;
}

/// Liquidación con el menor número de pagos (heurística voraz: el que más
/// debe le paga al que más le deben). [order] desempata para que el
/// resultado sea estable.
List<Transfer> minimalTransfers(Map<int, int> balances, {List<int>? order}) {
  final ord = order ?? balances.keys.toList();
  int rank(int id) {
    final i = ord.indexOf(id);
    return i < 0 ? ord.length + id : i;
  }

  final debt = <int, int>{};
  final credit = <int, int>{};
  balances.forEach((id, v) {
    if (v < 0) debt[id] = -v;
    if (v > 0) credit[id] = v;
  });
  final out = <Transfer>[];
  int pick(Map<int, int> m) {
    final ids = m.keys.toList()
      ..sort((a, b) {
        final c = m[b]!.compareTo(m[a]!);
        return c != 0 ? c : rank(a).compareTo(rank(b));
      });
    return ids.first;
  }

  while (debt.isNotEmpty && credit.isNotEmpty) {
    final d = pick(debt);
    final c = pick(credit);
    final amt = debt[d]! < credit[c]! ? debt[d]! : credit[c]!;
    out.add(Transfer(d, c, amt));
    debt[d] = debt[d]! - amt;
    credit[c] = credit[c]! - amt;
    if (debt[d] == 0) debt.remove(d);
    if (credit[c] == 0) credit.remove(c);
  }
  return out;
}

/// Cuántas transferencias harían falta sin simplificar: una por cada par de
/// personas con deuda neta entre sí.
int naiveTransferCount(List<LedgerExpense> expenses, List<LedgerPayment> payments) {
  final owe = <(int, int), int>{};
  void add(int from, int to, int v) {
    if (from == to) return;
    final key = from < to ? (from, to) : (to, from);
    final signed = from < to ? v : -v;
    owe[key] = (owe[key] ?? 0) + signed;
  }

  for (final e in expenses) {
    e.shares.forEach((m, s) => add(m, e.payerId, s));
  }
  for (final p in payments) {
    add(p.fromId, p.toId, -p.amount);
  }
  return owe.values.where((v) => v != 0).length;
}
