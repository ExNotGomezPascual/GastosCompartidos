import '../core/config.dart';
import 'gemini_extractor.dart';
import 'parsed_expense.dart';
import 'rule_parser.dart';

/// Primero intenta Gemini (si hay clave e internet); si falla, usa reglas.
/// Los campos que Gemini no entregue se completan con las reglas.
class ExpenseExtractor {
  ExpenseExtractor({GeminiExtractor? gemini, RuleParser? rules})
      : _gemini = gemini ??
            (AppConfig.hasGemini
                ? GeminiExtractor(
                    apiKey: AppConfig.geminiApiKey, model: AppConfig.geminiModel)
                : null),
        _rules = rules ?? RuleParser();

  final GeminiExtractor? _gemini;
  final RuleParser _rules;

  bool get usesAi => _gemini != null;

  Future<ParsedExpense> extract({
    required String text,
    required List<VoiceMember> members,
    required String currencyName,
    required int currencyFactor,
  }) async {
    final byRules = _rules.parse(text, members, currencyFactor);
    final g = _gemini;
    if (g == null) return byRules;
    try {
      final byAi = await g.extract(
        text: text,
        members: members,
        currencyName: currencyName,
        currencyFactor: currencyFactor,
      );
      if (byAi == null) return byRules;
      return byAi.fillFrom(byRules);
    } catch (_) {
      return byRules;
    }
  }
}
