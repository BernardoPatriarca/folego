// Backup (exportar/importar JSON) e importação de avaliações por CSV.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/csv_import.dart';
import 'backup_service.dart';
import 'config_repository.dart';

final lastBackupProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(dataRevisionProvider);
  final v = await ref
      .watch(configRepositoryProvider)
      .get(ConfigRepository.keyLastBackup);
  return v == null ? null : DateTime.tryParse(v);
});

/// Lê um arquivo escolhido pelo usuário como texto UTF-8.
Future<(String name, String content)?> pickTextFile() async {
  final file = await FilePicker.pickFile(type: FileType.any);
  if (file == null) return null;
  final bytes = await file.xFile.readAsBytes();
  return (file.name, utf8.decode(bytes, allowMalformed: true));
}

Future<void> shareTextFile(String fileName, String content,
    {required String mime, String? subject}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(content, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: mime, name: fileName)],
    subject: subject,
  ));
}

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on BackupException catch (e) {
      if (mounted) showMessage(context, e.message, icon: Icons.error_outline);
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Não foi possível concluir: $e',
            icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
        final now = DateTime.now();
        final json = await ref.read(backupServiceProvider).exportJson(now: now);
        await shareTextFile(BackupService.fileName(now), json,
            mime: 'application/json', subject: 'Backup do Fôlego');
        await ref
            .read(configRepositoryProvider)
            .set(ConfigRepository.keyLastBackup, now.toIso8601String());
        ref.bumpData();
      });

  Future<void> _import() => _run(() async {
        final picked = await pickTextFile();
        if (picked == null || !mounted) return;
        final service = ref.read(backupServiceProvider);
        final data = service.decode(picked.$2);
        final summary = service.validate(data);
        final c = summary.counts;
        final first = await confirmDialog(
          context,
          title: 'Importar backup?',
          message: '${picked.$1}\n'
              '${summary.exportedAt == null ? '' : 'Exportado em ${fmtDate(summary.exportedAt!)}.\n'}'
              '${c['treino_dia']} dias de treino, ${c['meta']} metas, '
              '${c['cardio']} cardios, ${c['avaliacao_corporal']} avaliações, '
              '${c['recorde']} recordes.\n\n'
              'TODOS os dados atuais serão substituídos.',
          confirmLabel: 'Continuar',
        );
        if (!first || !mounted) return;
        final second = await confirmDialog(
          context,
          title: 'Tem certeza?',
          message: 'Esta ação não pode ser desfeita. Se quiser, exporte um '
              'backup do estado atual antes.',
          confirmLabel: 'Substituir tudo',
        );
        if (!second) return;
        await service.importData(data);
        ref.bumpData();
        if (mounted) {
          showMessage(context, 'Backup importado.', icon: Icons.check_circle);
        }
      });

  Future<void> _template() => _run(() async {
        await shareTextFile('folego-modelo-avaliacoes.csv',
            '﻿${csvTemplate()}',
            mime: 'text/csv', subject: 'Modelo CSV do Fôlego');
      });

  Future<void> _importCsv() => _run(() async {
        final picked = await pickTextFile();
        if (picked == null || !mounted) return;
        final types = await ref.read(catalogRepositoryProvider).measureTypes();
        final result =
            parseAssessmentCsv(picked.$2, types.map((t) => t.name).toSet());
        if (!mounted) return;
        if (result.fatal != null) {
          showMessage(context, result.fatal!, icon: Icons.error_outline);
          return;
        }
        context.push('/mais/csv', extra: result);
      });

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastBackupProvider).value;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('BACKUP E IMPORTAÇÃO')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              const SectionTitle('Backup completo'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Gera folego-backup-AAAA-MM-DD.json com todos os dados '
                      'e abre o compartilhamento do Android: '
                      'salve no Drive ou mande para você mesmo.',
                      style: t.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      last == null
                          ? 'Nenhum backup exportado ainda.'
                          : 'Último backup: ${fmtDate(last)}',
                      style: t.bodySmall?.copyWith(
                          color: last == null ||
                                  DateTime.now().difference(last).inDays > 30
                              ? FolegoColors.bold
                              : FolegoColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Exportar backup'),
                      onPressed: _export,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restore),
                      label: const Text('Importar backup (substitui tudo)'),
                      onPressed: _import,
                    ),
                  ],
                ),
              ),
              const SectionTitle('Histórico corporal por CSV'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Separador ponto e vírgula (;). Decimal com vírgula ou '
                      'ponto. Data em DD/MM/AAAA ou AAAA-MM-DD. Campos vazios '
                      'são ignorados.\n\n'
                      'Depois das colunas do modelo, acrescente colunas com o '
                      'nome exato de uma medida (ex.: Cintura, Braço direito '
                      'contraído). Você vê uma pré-visualização antes de gravar.',
                      style: t.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Baixar modelo CSV'),
                      onPressed: _template,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('Importar avaliações (CSV)'),
                      onPressed: _importCsv,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'O Fôlego não tem acesso à internet: os arquivos só saem do '
                'celular quando você compartilha.',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
