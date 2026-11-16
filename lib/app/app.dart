// Raiz do app: tema, locale pt_BR, rotas e a "porta" do PIN.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/providers.dart';
import '../core/widgets/common.dart';
import '../features/auth/lock_controller.dart';
import '../features/auth/unlock_page.dart';
import '../features/onboarding/onboarding_page.dart';
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
    ref.read(lockControllerProvider.notifier).init();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(lockControllerProvider.notifier).onBackground(),
      onShow: () {
        ref.read(lockControllerProvider.notifier).onForeground();
        // Atualiza "hoje" e as listas ao voltar (pode ter virado o dia).
        ref.read(dataRevisionProvider.notifier).bump();
      },
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
      builder: (context, child) => _LockGate(child: child!),
    );
  }
}

/// Mostra onboarding ou PIN por cima do app. O app fica montado embaixo
/// (Offstage), então a navegação não se perde ao bloquear.
class _LockGate extends ConsumerWidget {
  const _LockGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lockControllerProvider);
    final cover = switch (state) {
      AppLockState.loading =>
        const ColoredBox(color: FolegoColors.background, child: LoadingView()),
      AppLockState.onboarding => const _OwnNavigator(child: OnboardingPage()),
      AppLockState.locked => const _OwnNavigator(child: UnlockPage()),
      AppLockState.unlocked => null,
    };
    return Stack(
      children: [
        Offstage(
          offstage: cover != null,
          child: TickerMode(enabled: cover == null, child: child),
        ),
        ?cover,
      ],
    );
  }
}

/// Navigator próprio para telas que ficam fora do go_router (diálogos e
/// seletores de data precisam de um Navigator acima deles).
class _OwnNavigator extends StatelessWidget {
  const _OwnNavigator({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
      ),
    );
  }
}
