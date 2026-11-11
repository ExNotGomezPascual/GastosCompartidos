import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/repository.dart';
import '../voice/expense_extractor.dart';
import '../voice/parsed_expense.dart';

enum VoiceStatus { idle, listening, processing, done, error }

class VoiceState extends Equatable {
  const VoiceState({
    required this.groupId,
    this.status = VoiceStatus.idle,
    this.text = '',
    this.parsed,
    this.message,
    this.level = 0,
  });

  final int groupId;
  final VoiceStatus status;
  final String text;
  final ParsedExpense? parsed;
  final String? message;
  final double level;

  VoiceState copyWith({
    int? groupId,
    VoiceStatus? status,
    String? text,
    ParsedExpense? parsed,
    String? message,
    double? level,
    bool clearParsed = false,
    bool clearMessage = false,
  }) =>
      VoiceState(
        groupId: groupId ?? this.groupId,
        status: status ?? this.status,
        text: text ?? this.text,
        parsed: clearParsed ? null : (parsed ?? this.parsed),
        message: clearMessage ? null : (message ?? this.message),
        level: level ?? this.level,
      );

  @override
  List<Object?> get props => [groupId, status, text, identityHashCode(parsed), message, level];
}

class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit(this.repo, int groupId, {SpeechToText? speech, ExpenseExtractor? extractor})
      : _speech = speech ?? SpeechToText(),
        _extractor = extractor ?? ExpenseExtractor(),
        super(VoiceState(groupId: groupId));

  final Repository repo;
  final SpeechToText _speech;
  final ExpenseExtractor _extractor;
  bool _ready = false;
  String? _localeId;

  bool get usesAi => _extractor.usesAi;

  void changeGroup(int id) {
    emit(state.copyWith(groupId: id));
    if (state.status == VoiceStatus.done && state.text.isNotEmpty) _process(state.text);
  }

  Future<void> toggle() async {
    if (state.status == VoiceStatus.listening) {
      await _speech.stop();
      return;
    }
    if (state.status == VoiceStatus.processing) return;
    await _start();
  }

  Future<void> _start() async {
    if (!_ready) {
      _ready = await _speech.initialize(onError: _onError, onStatus: _onStatus);
      if (!_ready) {
        emit(state.copyWith(
          status: VoiceStatus.error,
          message: 'No se pudo usar el micrófono. Revisa el permiso de micrófono y que el teléfono tenga '
              'el reconocimiento de voz de Google.',
        ));
        return;
      }
      final locales = await _speech.locales();
      String? pick(bool Function(String) f) =>
          locales.map((l) => l.localeId).where(f).firstOrNull;
      _localeId = pick((l) => l.replaceAll('-', '_').toLowerCase() == 'es_co') ??
          pick((l) => l.toLowerCase().startsWith('es_419') || l.toLowerCase().startsWith('es-419')) ??
          pick((l) => l.toLowerCase().startsWith('es'));
    }
    emit(state.copyWith(status: VoiceStatus.listening, text: '', clearParsed: true, clearMessage: true, level: 0));
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: (l) => emit(state.copyWith(level: l)),
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    if (isClosed) return;
    emit(state.copyWith(text: r.recognizedWords));
    if (r.finalResult) _process(r.recognizedWords);
  }

  void _onStatus(String s) {
    if (isClosed) return;
    if ((s == 'done' || s == 'notListening') &&
        state.status == VoiceStatus.listening &&
        state.text.trim().isEmpty) {
      emit(state.copyWith(status: VoiceStatus.idle, message: 'No te escuché. Toca el micrófono e intenta de nuevo.'));
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (isClosed) return;
    final msg = switch (e.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => 'No te entendí. Toca el micrófono e intenta de nuevo.',
      'error_network' || 'error_network_timeout' || 'error_server' =>
        'Sin conexión para el dictado. Conéctate o descarga el español sin conexión en los ajustes de voz de Google.',
      'error_permission' || 'error_insufficient_permissions' =>
        'La app necesita permiso de micrófono para registrar por voz.',
      'error_busy' => 'El micrófono está ocupado. Intenta de nuevo en un momento.',
      _ => 'No se pudo escuchar (${e.errorMsg}). Intenta de nuevo.',
    };
    if (state.text.trim().isNotEmpty && state.status == VoiceStatus.listening) {
      _process(state.text);
      return;
    }
    emit(state.copyWith(status: VoiceStatus.error, message: msg));
  }

  Future<void> _process(String text) async {
    if (text.trim().isEmpty) {
      emit(state.copyWith(status: VoiceStatus.idle));
      return;
    }
    emit(state.copyWith(status: VoiceStatus.processing, text: text));
    final d = await repo.groupDetail(state.groupId);
    if (d == null || isClosed) return;
    final members = [for (final m in d.members) VoiceMember(m.id, m.name, isMe: m.isMe)];
    final parsed = await _extractor.extract(
      text: text,
      members: members,
      currencyName: '${d.currency.name} (${d.currency.code})',
      currencyFactor: d.currency.factor,
    );
    if (isClosed) return;
    emit(state.copyWith(status: VoiceStatus.done, parsed: parsed));
  }

  @override
  Future<void> close() async {
    await _speech.cancel();
    return super.close();
  }
}
