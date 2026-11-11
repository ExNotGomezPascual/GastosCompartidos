import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/database.dart';
import 'data/repository.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'state/app_cubits.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  Intl.defaultLocale = 'es_CO';
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.navBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(GastosApp(repo: Repository(AppDatabase())));
}

class GastosApp extends StatelessWidget {
  const GastosApp({super.key, required this.repo});
  final Repository repo;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AppCubit(repo)),
          BlocProvider(create: (_) => GroupsCubit(repo)),
          BlocProvider(create: (_) => NoticesCubit(repo)),
          BlocProvider(create: (_) => TabCubit()),
        ],
        child: MaterialApp(
          title: 'Gastos Compartidos',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: const Locale('es', 'CO'),
          supportedLocales: const [Locale('es', 'CO'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BlocBuilder<AppCubit, AppState>(
            buildWhen: (a, b) => a.loading != b.loading || a.onboarded != b.onboarded,
            builder: (context, s) {
              if (s.loading) return const Scaffold(body: SizedBox.shrink());
              return s.onboarded ? const ShellScreen() : const OnboardingScreen();
            },
          ),
        ),
      ),
    );
  }
}
