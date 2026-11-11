import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_cubits.dart';
import '../state/voice_cubit.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../voice/parsed_expense.dart';
import 'expense_form_screen.dart';
import 'home_screen.dart';

/// Pantalla 4 del recorrido: Registro por voz.
class VoiceScreen extends StatelessWidget {
  const VoiceScreen({super.key, required this.groupId, this.lockGroup = false});
  final int groupId;
  final bool lockGroup;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VoiceCubit(context.read<Repository>(), groupId),
      child: _VoiceView(lockGroup: lockGroup),
    );
  }
}

class _VoiceView extends StatelessWidget {
  const _VoiceView({required this.lockGroup});
  final bool lockGroup;

  Future<void> _pickGroup(BuildContext context, List<GroupOverview> groups, int current) async {
    final id = await showAppSheet<int>(
      context,
      title: '¿En qué grupo?',
      builder: (ctx) => Column(children: [
        for (final g in groups)
          Tap(
            onTap: () => Navigator.pop(ctx, g.group.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(children: [
                Expanded(child: Text(g.group.name, style: bold(16))),
                if (g.group.id == current) const Ico(AppIcon.check, size: 18, color: AppColors.accent),
              ]),
            ),
          ),
      ]),
    );
    if (id != null && context.mounted) context.read<VoiceCubit>().changeGroup(id);
  }

  Future<void> _review(BuildContext context, VoiceState s) async {
    final saved = await Navigator.of(context).push<ExpenseSaved>(MaterialPageRoute(
      builder: (_) => ExpenseFormScreen(groupId: s.groupId, parsed: s.parsed, transcript: s.text),
    ));
    if (saved != null && context.mounted) Navigator.of(context).pop(saved);
  }

  Future<void> _manual(BuildContext context, int groupId) async {
    final saved = await Navigator.of(context).push<ExpenseSaved>(
        MaterialPageRoute(builder: (_) => ExpenseFormScreen(groupId: groupId)));
    if (saved != null && context.mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupsCubit>().state.groups;
    return BlocBuilder<VoiceCubit, VoiceState>(
      builder: (context, s) {
        final cubit = context.read<VoiceCubit>();
        final group = groups.where((g) => g.group.id == s.groupId).firstOrNull;
        final listening = s.status == VoiceStatus.listening;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(children: [
                ScreenHeader(
                  title: 'Nuevo gasto',
                  icon: AppIcon.close,
                  centered: true,
                  trailing: Tap(
                    radius: 999,
                    onTap: lockGroup || groups.length < 2 ? null : () => _pickGroup(context, groups, s.groupId),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 130),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(group?.group.name ?? '', style: bold(13, color: AppColors.accent), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(child: _center(context, s, group)),
                  ),
                ),
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(alignment: Alignment.center, children: [
                    if (listening) const _Pulse(),
                    Material(
                      color: AppColors.accent,
                      shape: const CircleBorder(),
                      elevation: 0,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: cubit.toggle,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .3), blurRadius: 30, offset: const Offset(0, 10))],
                          ),
                          alignment: Alignment.center,
                          child: s.status == VoiceStatus.processing
                              ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: AppColors.bg, strokeWidth: 3))
                              : Ico(listening ? AppIcon.check : AppIcon.mic, size: 38, color: AppColors.bg),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                if (s.status == VoiceStatus.done) ...[
                  AppButton('Revisar y guardar', kind: ButtonKind.light, height: 54, onTap: () => _review(context, s)),
                  const SizedBox(height: 10),
                  Text('Toca el micrófono para grabar de nuevo', style: sans(13, color: AppColors.muted)),
                ] else if (listening)
                  Text('Toca para terminar', style: sans(13, color: AppColors.muted))
                else if (s.status != VoiceStatus.processing)
                  AppButton('Prefiero escribirlo', kind: ButtonKind.ghost, height: 44, onTap: () => _manual(context, s.groupId)),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _center(BuildContext context, VoiceState s, GroupOverview? group) {
    switch (s.status) {
      case VoiceStatus.idle:
      case VoiceStatus.error:
        return Column(children: [
          Text('Toca el micrófono y di el gasto', textAlign: TextAlign.center, style: bold(24)),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text('Por ejemplo: “Pagué 28.000 de gas para todos”',
                textAlign: TextAlign.center, style: sans(15, color: AppColors.muted, height: 1.4)),
          ),
          if (s.message != null) ...[
            const SizedBox(height: 20),
            InfoBanner(icon: AppIcon.alert, color: AppColors.coral, text: s.message!),
          ],
        ]);
      case VoiceStatus.listening:
        return Column(children: [
          MonoLabel('Escuchando…', color: AppColors.accent, size: 13),
          const SizedBox(height: 16),
          const _Wave(),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(s.text.isEmpty ? '…' : '“${s.text}…”',
                textAlign: TextAlign.center, style: sans(20, height: 1.4)),
          ),
        ]);
      case VoiceStatus.processing:
        return Column(children: [
          MonoLabel(context.read<VoiceCubit>().usesAi ? 'Analizando con IA…' : 'Analizando…', color: AppColors.violet, size: 13),
          const SizedBox(height: 16),
          Text('“${s.text}”', textAlign: TextAlign.center, style: bold(22, height: 1.4)),
        ]);
      case VoiceStatus.done:
        final p = s.parsed!;
        final cur = group?.currency ?? currencyOf('COP');
        final people = p.participantIds?.length ?? group?.memberCount ?? 0;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('“${s.text}”', textAlign: TextAlign.center, style: bold(22, height: 1.4)),
          const SizedBox(height: 18),
          Box(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              DetailRow(label: 'Monto', value: p.amount == null ? 'Sin detectar' : formatMoney(p.amount!, cur), padding: 12,
                  valueColor: p.amount == null ? AppColors.coral : AppColors.text),
              DetailRow(
                label: 'Concepto',
                value: [p.concept ?? 'Sin detectar', ?p.category].join(' · '),
                padding: 12,
              ),
              DetailRow(label: 'Dividir entre', value: '$people ${people == 1 ? 'persona' : 'personas'}', divider: false, padding: 12),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            p.source == ParseSource.gemini ? 'Analizado con IA (Gemini)' : 'Analizado sin IA: revisa los datos',
            textAlign: TextAlign.center,
            style: sans(12, color: AppColors.muted),
          ),
        ]);
    }
  }
}

class _Wave extends StatefulWidget {
  const _Wave();

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  static const _heights = [18.0, 34, 48, 28, 56, 40, 22, 50, 30, 44, 20, 36, 16];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _heights.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Container(
                  width: 5,
                  height: _heights[i] * (.25 + .75 * (.5 + .5 * math.sin((_c.value * 2 * math.pi) - i * .55))),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Transform.scale(
          scale: 1 + .7 * t,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: .5 * (1 - t)),
            ),
          ),
        );
      },
    );
  }
}
