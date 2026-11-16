// Rotas: 5 abas (Hoje · Lançar · Corpo · Evolução · Mais) e telas cheias
// empilhadas por cima da barra de abas.
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/csv_import.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import '../features/body/assessment_detail_page.dart';
import '../features/body/assessment_form_page.dart';
import '../features/body/body_goals_page.dart';
import '../features/body/body_page.dart';
import '../features/body/compare_page.dart';
import '../features/cardio/cardio_form.dart';
import '../features/catalog/catalog_pages.dart';
import '../features/logging/log_page.dart';
import '../features/progress/progress_page.dart';
import '../features/settings/backup_page.dart';
import '../features/settings/csv_preview_page.dart';
import '../features/settings/more_page.dart';
import '../features/settings/settings_pages.dart';
import '../features/statement/statement_pages.dart';
import '../features/today/today_page.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/hoje',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            for (final (path, page) in const [
              ('/hoje', TodayPage()),
              ('/lancar', LogPage()),
              ('/corpo', BodyPage()),
              ('/evolucao', ProgressPage()),
              ('/mais', MorePage()),
            ])
              StatefulShellBranch(routes: [
                GoRoute(path: path, builder: (_, _) => page),
              ]),
          ],
        ),
        _full('/cardio',
            (s) => CardioFormPage(date: s.extra is DateTime ? s.extra as DateTime : null)),
        _full('/cardio/editar',
            (s) => CardioFormPage(existing: s.extra as CardioView?)),
        _full('/avaliacao/nova', (_) => const AssessmentFormPage()),
        _full('/avaliacao/:id',
            (s) => AssessmentDetailPage(id: int.parse(s.pathParameters['id']!))),
        _full('/avaliacao/:id/editar',
            (s) => AssessmentFormPage(editId: int.parse(s.pathParameters['id']!))),
        _full('/comparar', (_) => const ComparePage()),
        _full('/extrato', (_) => const StatementListPage()),
        _full('/extrato/:inicio',
            (s) => StatementDetailPage(start: fromIsoDate(s.pathParameters['inicio']!))),
        _full('/mais/perfil', (_) => const ProfilePage()),
        _full('/mais/metas-corporais', (_) => const BodyGoalsPage()),
        _full('/mais/exercicios', (_) => const ExercisesPage()),
        _full('/mais/medidas', (_) => const MeasureTypesPage()),
        _full('/mais/regra', (_) => const GoldenRulePage()),
        _full('/mais/semana', (_) => const WeekCardioPage()),
        _full('/mais/backup', (_) => const BackupPage()),
        _full('/mais/csv',
            (s) => CsvPreviewPage(result: s.extra! as CsvParseResult)),
        _full('/mais/sobre', (_) => const AboutPage()),
      ],
    );

GoRoute _full(String path, Widget Function(GoRouterState) build) => GoRoute(
      path: path,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, state) => build(state),
    );
