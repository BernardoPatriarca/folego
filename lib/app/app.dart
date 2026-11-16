// Raiz do app: tema, locale pt_BR e rotas. Abre direto, sem PIN.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/providers.dart';
import 'router.dart';
import 'theme.dart';

class FolegoApp extends ConsumerStatefulWidget {
  const FolegoApp({super.key});

  @override
  ConsumerState<FolegoApp> createState() => _FolegoAppState();
}

class _FolegoAppState extends ConsumerState<FolegoApp> {
  late final GoRouter _router = buildRouter();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Atualiza "hoje" e as listas ao voltar ao app (pode ter virado o dia).
    _lifecycle = AppLifecycleListener(
      onShow: () => ref.read(dataRevisionProvider.notifier).bump(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fôlego',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    );
  }
}
