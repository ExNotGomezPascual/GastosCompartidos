enum SplitType {
  equal('Partes iguales'),
  exact('Montos'),
  percent('Porcentaje');

  const SplitType(this.label);
  final String label;

  static SplitType parse(String s) =>
      SplitType.values.firstWhere((t) => t.name == s, orElse: () => SplitType.equal);
}

class SplitResult {
  const SplitResult(this.shares, this.error);

  /// memberId → parte en unidades mínimas.
  final Map<int, int> shares;
  final String? error;
  bool get ok => error == null;
}

/// Calcula cuánto le toca a cada integrante.
///
/// * [memberIds]: participantes, en el orden en que reciben los centavos sobrantes.
/// * [inputs]: para [SplitType.exact] el monto de cada uno; para
///   [SplitType.percent] puntos básicos (100 % = 10000). Se ignora en partes iguales.
SplitResult computeShares({
  required int amount,
  required SplitType type,
  required List<int> memberIds,
  Map<int, int> inputs = const {},
}) {
  if (amount <= 0) return const SplitResult({}, 'Escribe un monto mayor que cero');
  switch (type) {
    case SplitType.equal:
      if (memberIds.isEmpty) {
        return const SplitResult({}, 'Elige al menos una persona');
      }
      final base = amount ~/ memberIds.length;
      var rest = amount - base * memberIds.length;
      final out = <int, int>{};
      for (final id in memberIds) {
        out[id] = base + (rest > 0 ? 1 : 0);
        if (rest > 0) rest--;
      }
      return SplitResult(out, null);
    case SplitType.exact:
      final out = <int, int>{};
      var sum = 0;
      for (final id in memberIds) {
        final v = inputs[id] ?? 0;
        if (v < 0) return const SplitResult({}, 'Los montos no pueden ser negativos');
        if (v > 0) out[id] = v;
        sum += v;
      }
      if (out.isEmpty) return const SplitResult({}, 'Asigna el monto de al menos una persona');
      if (sum != amount) {
        return SplitResult(out, sum < amount ? 'Falta repartir' : 'Te pasaste del total');
      }
      return SplitResult(out, null);
    case SplitType.percent:
      final ids = [for (final id in memberIds) if ((inputs[id] ?? 0) > 0) id];
      if (ids.isEmpty) return const SplitResult({}, 'Asigna el porcentaje de al menos una persona');
      final total = ids.fold<int>(0, (s, id) => s + inputs[id]!);
      if (total != 10000) {
        return SplitResult({}, total < 10000 ? 'Falta porcentaje' : 'Suma más de 100 %');
      }
      final out = <int, int>{};
      var assigned = 0;
      for (final id in ids) {
        final v = amount * inputs[id]! ~/ 10000;
        out[id] = v;
        assigned += v;
      }
      var rest = amount - assigned;
      var i = 0;
      while (rest > 0) {
        out[ids[i % ids.length]] = out[ids[i % ids.length]]! + 1;
        rest--;
        i++;
      }
      return SplitResult(out, null);
  }
}
