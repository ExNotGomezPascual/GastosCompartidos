import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/app_cubits.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import 'groups_tab.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'settle_tab.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<AppCubit>().runMaintenance();
  }

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<TabCubit>().state;
    final bottom = MediaQuery.of(context).padding.bottom;
    Widget item(int i, AppIcon icon, String label) {
      final on = i == tab;
      return Expanded(
        child: InkWell(
          onTap: () => context.read<TabCubit>().go(i),
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Ico(icon, size: 24, color: on ? AppColors.accent : AppColors.muted),
              const SizedBox(height: 4),
              Text(label,
                  style: sans(12, weight: on ? FontWeight.w700 : FontWeight.w400, color: on ? AppColors.accent : AppColors.muted)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: tab, children: const [
        HomeScreen(),
        GroupsTab(),
        SettleTab(),
        ProfileScreen(),
      ]),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: AppColors.navBg,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(children: [
            item(0, AppIcon.homeTab, 'Inicio'),
            item(1, AppIcon.users, 'Grupos'),
            item(2, AppIcon.swap, 'Saldar'),
            item(3, AppIcon.user, 'Perfil'),
          ]),
        ),
      ),
    );
  }
}
