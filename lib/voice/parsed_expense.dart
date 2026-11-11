class VoiceMember {
  const VoiceMember(this.id, this.name, {this.isMe = false});
  final int id;
  final String name;
  final bool isMe;
}

enum ParseSource { gemini, rules }

class ParsedExpense {
  const ParsedExpense({
    this.amount,
    this.concept,
    this.category,
    this.payerId,
    this.participantIds,
    this.splitCount,
    this.source = ParseSource.rules,
  });

  /// Monto en unidades mínimas de la moneda del grupo.
  final int? amount;
  final String? concept;
  final String? category;
  final int? payerId;
  final List<int>? participantIds;

  /// Número de personas que se dijo en voz alta ("entre los cuatro").
  final int? splitCount;
  final ParseSource source;

  /// Completa los campos vacíos de este resultado con los de [other].
  ParsedExpense fillFrom(ParsedExpense other) => ParsedExpense(
        amount: amount ?? other.amount,
        concept: (concept?.isNotEmpty ?? false) ? concept : other.concept,
        category: category ?? other.category,
        payerId: payerId ?? other.payerId,
        participantIds: (participantIds?.isNotEmpty ?? false)
            ? participantIds
            : other.participantIds,
        splitCount: splitCount ?? other.splitCount,
        source: source,
      );
}

String normalize(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}
