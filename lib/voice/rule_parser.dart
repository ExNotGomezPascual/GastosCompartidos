import '../domain/categories.dart';
import 'parsed_expense.dart';

/// Analizador por reglas para frases en español de Colombia, por ejemplo
/// "Pagué 120 mil de mercado entre los cuatro" o "Juan pagó 50 lucas del internet".
class RuleParser {
  static const _units = <String, int>{
    'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5,
    'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10, 'once': 11,
    'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15, 'dieciseis': 16,
    'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19, 'veinte': 20,
    'veintiun': 21, 'veintiuno': 21, 'veintiuna': 21, 'veintidos': 22,
    'veintitres': 23, 'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26,
    'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29, 'treinta': 30,
    'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60, 'setenta': 70,
    'ochenta': 80, 'noventa': 90, 'cien': 100, 'ciento': 100,
    'doscientos': 200, 'doscientas': 200, 'trescientos': 300, 'trescientas': 300,
    'cuatrocientos': 400, 'cuatrocientas': 400, 'quinientos': 500,
    'quinientas': 500, 'seiscientos': 600, 'seiscientas': 600,
    'setecientos': 700, 'setecientas': 700, 'ochocientos': 800,
    'ochocientas': 800, 'novecientos': 900, 'novecientas': 900,
  };
  static const _thousand = {'mil', 'luca', 'lucas', 'k'};
  static const _million = {'millon', 'millones', 'palo', 'palos'};
  static const _countWords = <String, int>{
    'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7,
    'ocho': 8, 'nueve': 9, 'diez': 10,
  };
  static const _meVerbs = {
    'pague', 'pagamos', 'puse', 'compre', 'gaste', 'invite', 'cancele', 'aporte',
  };
  static const _otherVerbs = {'pago', 'puso', 'compro', 'gasto', 'invito', 'cancelo', 'aporto'};
  static const _allWords = {'todos', 'todas', 'nosotros', 'nosotras'};
  static const _meWords = {'yo', 'mi', 'conmigo', 'nosotros', 'nosotras'};
  static const _stop = {
    'de', 'del', 'el', 'la', 'los', 'las', 'en', 'un', 'una', 'unos', 'unas',
    'por', 'pesos', 'peso', 'y', 'yo', 'que', 'lo', 'al', 'a', 'mi', 'se', 'me',
    'hoy', 'ayer', 'apto', 'apartamento', 'casa', 'dolares', 'euros', 'total',
    'fue', 'fueron', 'costo', 'vale', 'valio', 'gaste', 'son', 'es', 'esto',
    'ese', 'eso', 'este', 'esta', 'para', 'entre', 'con',
  };

  ParsedExpense parse(String text, List<VoiceMember> members, int currencyFactor) {
    final original = text
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'^[^\w\d$áéíóúñÁÉÍÓÚÑ]+|[^\w\d.,áéíóúñÁÉÍÓÚÑ]+$'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    final norm = [
      for (final w in original) normalize(w).replaceAll(RegExp(r'[.,]+$'), ''),
    ];
    final used = List<bool>.filled(norm.length, false);

    final me = members.where((m) => m.isMe).firstOrNull;
    int? memberAt(int i) {
      if (i < 0 || i >= norm.length) return null;
      for (final m in members) {
        final first = normalize(m.name).split(' ').first;
        if (first.isNotEmpty && norm[i] == first) return m.id;
      }
      if (norm[i] == 'tu' && me != null) return me.id;
      return null;
    }

    // --- Quién pagó ---
    int? payerId;
    for (var i = 0; i < norm.length && payerId == null; i++) {
      if (_meVerbs.contains(norm[i])) {
        payerId = me?.id;
        used[i] = true;
        if (i > 0 && norm[i - 1] == 'yo') used[i - 1] = true;
      } else if (_otherVerbs.contains(norm[i])) {
        final before = memberAt(i - 1);
        final after = memberAt(i + 1);
        final id = before ?? after;
        if (id != null) {
          payerId = id;
          used[i] = true;
          used[before != null ? i - 1 : i + 1] = true;
        }
      }
    }

    // --- Entre quiénes ---
    List<int>? participants;
    int? splitCount;
    var segStart = -1;
    for (var i = 0; i < norm.length && segStart < 0; i++) {
      final w = norm[i];
      final isDivide = w.startsWith('divid');
      if (w != 'entre' && w != 'con' && w != 'para' && !isDivide) continue;
      // Mira las siguientes 3 palabras.
      for (var j = i + 1; j < norm.length && j <= i + 3; j++) {
        final n = norm[j];
        if (_allWords.contains(n) ||
            _countWords.containsKey(n) ||
            RegExp(r'^\d+$').hasMatch(n) ||
            memberAt(j) != null ||
            _meWords.contains(n)) {
          segStart = i;
          break;
        }
        if (!{'los', 'las', 'en', 'entre', 'mis', 'el'}.contains(n)) break;
      }
    }
    if (segStart >= 0) {
      final seg = <int>[];
      var includeMe = norm[segStart] == 'con';
      var all = false;
      for (var j = segStart; j < norm.length; j++) {
        final n = norm[j];
        if (_allWords.contains(n)) all = true;
        if (_countWords.containsKey(n)) splitCount ??= _countWords[n];
        if (RegExp(r'^\d+$').hasMatch(n) && int.parse(n) <= 30) {
          splitCount ??= int.parse(n);
        }
        if (_meWords.contains(n) && n != 'mi') includeMe = true;
        final id = memberAt(j);
        if (id != null && !seg.contains(id)) seg.add(id);
        used[j] = true;
        // Corta el segmento si arranca otra idea con monto.
        if (RegExp(r'^\$?\d').hasMatch(original[j]) && int.tryParse(n) == null) {
          used[j] = false;
          break;
        }
      }
      if (all) {
        participants = members.map((m) => m.id).toList();
      } else if (seg.isNotEmpty) {
        if (includeMe) {
          final payer = payerId ?? me?.id;
          if (payer != null && !seg.contains(payer)) seg.insert(0, payer);
        }
        participants = seg;
      } else if (splitCount != null) {
        if (splitCount >= members.length) {
          participants = members.map((m) => m.id).toList();
        } else {
          final payer = payerId ?? me?.id;
          participants = [
            ?payer,
            for (final m in members)
              if (m.id != payer) m.id,
          ].take(splitCount).toList();
        }
      }
    }

    // --- Monto ---
    double? best;
    var bestRun = <int>[];
    var i = 0;
    while (i < norm.length) {
      if (used[i]) {
        i++;
        continue;
      }
      final run = <int>[];
      double total = 0;
      double current = 0;
      var hasValue = false;
      var onlyArticle = true;
      var j = i;
      String? prevDigits;
      while (j < norm.length && !used[j]) {
        final w = norm[j];
        final lit = _literal(original[j]);
        if (lit != null) {
          if (prevDigits != null && RegExp(r'^\d{3}$').hasMatch(w)) {
            current = current * 1000 + lit;
          } else {
            current += lit;
          }
          prevDigits = w;
          hasValue = true;
          onlyArticle = false;
        } else if (_units.containsKey(w)) {
          current += _units[w]!;
          hasValue = true;
          if (!{'un', 'una', 'uno'}.contains(w)) onlyArticle = false;
          prevDigits = null;
        } else if (_thousand.contains(w) && (hasValue || w == 'mil')) {
          total += (current == 0 ? 1 : current) * 1000;
          current = 0;
          hasValue = true;
          onlyArticle = false;
          prevDigits = null;
        } else if (_million.contains(w) && hasValue) {
          total += (current == 0 ? 1 : current) * 1000000;
          current = 0;
          onlyArticle = false;
          prevDigits = null;
        } else if (w == 'y' && hasValue) {
          prevDigits = null;
        } else {
          break;
        }
        run.add(j);
        j++;
      }
      if (run.isEmpty) {
        i++;
        continue;
      }
      final value = total + current;
      if (hasValue && !onlyArticle && value > 0 && (best == null || value > best)) {
        best = value;
        bestRun = run;
      }
      i = j;
    }
    for (final k in bestRun) {
      used[k] = true;
    }
    final amount = best == null ? null : (best * currencyFactor).round();

    // --- Concepto y categoría ---
    String? category;
    for (var k = 0; k < norm.length && category == null; k++) {
      if (memberAt(k) != null) continue;
      for (final e in categoryKeywords.entries) {
        if (e.value.contains(norm[k])) {
          category = e.key;
          break;
        }
      }
    }
    final conceptWords = <String>[];
    for (var k = 0; k < norm.length; k++) {
      if (used[k] || _stop.contains(norm[k]) || memberAt(k) != null) {
        if (conceptWords.isNotEmpty) break;
        continue;
      }
      if (_literal(original[k]) != null) {
        if (conceptWords.isNotEmpty) break;
        continue;
      }
      conceptWords.add(original[k].replaceAll(RegExp(r'[.,;:!?¡¿"“”]'), ''));
      if (conceptWords.length == 3) break;
    }
    var concept = conceptWords.join(' ').trim();
    if (concept.isNotEmpty) {
      concept = concept[0].toUpperCase() + concept.substring(1).toLowerCase();
    }

    return ParsedExpense(
      amount: amount,
      concept: concept.isEmpty ? null : concept,
      category: category ?? (concept.isEmpty ? null : 'Otros'),
      payerId: payerId ?? me?.id,
      participantIds: participants ?? members.map((m) => m.id).toList(),
      splitCount: splitCount,
      source: ParseSource.rules,
    );
  }

  /// Número escrito con cifras: `28.000`, `28,000`, `$120000`, `12,50`.
  static double? _literal(String raw) {
    if (!RegExp(r'^[\$]?[\d.,]+$').hasMatch(raw.trim())) return null;
    final s = raw.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(RegExp(r'[.,]+$'), '');
    if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;
    if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) {
      return double.parse(s.replaceAll(RegExp(r'[.,]'), ''));
    }
    if (RegExp(r'^\d+[.,]\d{1,2}$').hasMatch(s)) {
      return double.parse(s.replaceAll(',', '.'));
    }
    if (RegExp(r'^\d+$').hasMatch(s)) return double.parse(s);
    return null;
  }
}
