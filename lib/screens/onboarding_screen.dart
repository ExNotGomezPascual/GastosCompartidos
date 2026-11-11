import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/app_cubits.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Pantalla 1 del recorrido: Bienvenida.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _phoneValue {
    final d = _phone.text.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : '+57 $d';
  }

  Future<void> _go({bool sample = false}) async {
    final name = _name.text.trim().isEmpty && sample ? 'Sofía' : _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    await context.read<AppCubit>().completeOnboarding(name, _phoneValue, withSample: sample);
  }

  @override
  Widget build(BuildContext context) {
    Widget benefit(AppIcon icon, Color color, String text) => Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Ico(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: sans(16, height: 1.4))),
        ]);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  MonoLabel('Gastos Compartidos', color: AppColors.accent, size: 13),
                  const SizedBox(height: 14),
                  Text('Cuentas claras en tu grupo, sin la pena de cobrar', style: bold(34, height: 1.12)),
                  const SizedBox(height: 28),
                  benefit(AppIcon.mic, AppColors.violet, 'Registra un gasto hablando, en segundos'),
                  const SizedBox(height: 16),
                  benefit(AppIcon.swap, AppColors.accent, 'La app calcula quién le debe a quién'),
                  const SizedBox(height: 16),
                  benefit(AppIcon.bell, AppColors.coral, 'La app redacta los recordatorios por ti'),
                  const SizedBox(height: 40),
                  Text('¿Cómo te llamas?', style: sans(14, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: bold(17),
                    decoration: const InputDecoration(hintText: 'Tu nombre'),
                  ),
                  const SizedBox(height: 14),
                  Text('Tu número de celular (opcional)', style: sans(14, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
                    style: sans(17),
                    decoration: InputDecoration(
                      hintText: '300 412 8890',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('+57', style: bold(17)),
                          const SizedBox(width: 12),
                          Container(width: 1, height: 24, color: AppColors.border),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton('Continuar', onTap: () => _go(), enabled: _name.text.trim().isNotEmpty && !_busy),
                  const SizedBox(height: 12),
                  Text('Tus datos se guardan solo en este teléfono.',
                      textAlign: TextAlign.center, style: sans(13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  AppButton('Explorar con datos de ejemplo', kind: ButtonKind.ghost, height: 48, onTap: () => _go(sample: true), enabled: !_busy),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
