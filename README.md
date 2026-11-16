# Fôlego — o Lastro do seu corpo

App Android pessoal para acompanhar a saúde física, irmão do **Lastro**.
O treino funciona como um extrato: de manhã você **planeja** as metas do dia,
depois **lança** o que fez e o esforço, registra o **cardio** com os números
do relógio e as **avaliações corporais**. O app mostra a **evolução**,
**recordes**, **sequência** e um **extrato semanal**.

- 100% offline e local (SQLite). Sem backend, login, analytics nem permissão
  de internet no APK de release.
- Protegido por PIN (SHA-256 + salt no cofre seguro do Android), com
  `FLAG_SECURE` e bloqueio após 2 min em segundo plano.
- Os dados só saem do celular pelo backup JSON que você exporta.

## Comandos

```bash
flutter pub get
flutter analyze                 # zero erros e avisos
flutter test                    # domínio, repositórios e widgets
flutter run                     # emulador ou celular via USB
flutter build apk --release     # APK universal
flutter build apk --release --split-per-abi   # um APK por arquitetura

dart run flutter_launcher_icons          # regerar ícone
dart run flutter_native_splash:create    # regerar splash
```

O build de release, a chave de assinatura e a instalação no celular estão em
[LEIAME-RELEASE.md](LEIAME-RELEASE.md).

## Estrutura

```
lib/
  main.dart
  app/            tema, rotas (go_router), shell com abas, porta do PIN
  core/           banco (schema, migrations, mappers), providers, formatação, widgets comuns
  features/
    auth/         PIN (serviço, teclado, desbloqueio, troca)
    onboarding/   primeira execução
    today/        plano do dia + repositório de treinos/recordes
    logging/      aba Lançar
    cardio/       formulário, card do dia, repositório e CardioSource (v2: Health Connect)
    body/         avaliações, comparador, metas corporais
    progress/     gráficos, cards do mês, linha do tempo de recordes
    statement/    extrato semanal
    catalog/      exercícios e tipos de medida
    settings/     Mais, configurações, backup e importação CSV
  domain/         regras de negócio puras (sem Flutter), 100% testadas
test/
  domain/         regra de ouro, cumprimento, recordes, sequência, extrato, corpo, CSV
  data/           repositórios com SQLite em memória (sqflite_common_ffi)
  widget/         onboarding, fluxo de lançamento e telas em 320 dp com fonte 1,3x
```

Camadas: telas → providers (Riverpod) → repositórios → banco. Toda escrita
chama `ref.bumpData()`, e os providers de leitura observam essa "revisão",
então as telas se atualizam sozinhas.

## Decisões de implementação

- **Banco**: `sqflite` (a tabela da especificação). Schema versionado em
  `lib/core/db/schema.dart`; para mudar, adicione a migration da versão
  seguinte e suba `schemaVersion`. Datas em texto ISO `AAAA-MM-DD`.
- **Material**: o Flutter 3.50 separou o Material no pacote `material_ui`;
  o app importa `package:material_ui/material_ui.dart` (o antigo
  `flutter/material.dart` está obsoleto).
- **Regra de ouro**: o "melhor recente" olha só sessões **anteriores** ao dia
  da meta. O produto é arredondado a 6 casas antes do `ceil`, para
  `30 × 1,1` dar 33 (e não 34 por erro de ponto flutuante).
- **Lançar sem plano** cria a meta com alvo = realizado (100% de cumprimento).
- **Recordes**: comparados com todos os outros lançamentos do exercício.
  Corrigir um lançamento para baixo remove o recorde daquele lançamento.
- **Esforço** é opcional no lançamento (1–10 quando informado).
- **Totais do extrato** separados por unidade (repetições e segundos), já que
  somar os dois não faz sentido.
- **Cardio na Evolução**: minutos por semana; semanas sem cardio entram como 0.
- **CSV**: a pergunta "Substituir ou pular?" vale para todas as datas
  repetidas de uma vez, na pré-visualização. Colunas desconhecidas podem
  virar tipos de medida novos (categoria "outro", unidade escolhida).
- **Backup**: JSON `{app, formato, schema_version, exportado_em, tabelas}`;
  importar é atômico e recusa versão de schema mais nova. O PIN não entra.
- **Android**: `allowBackup=false` (fora do backup automático do Google),
  retrato, `minSdk 24`, permissão `INTERNET` removida no manifest de release.
- **Fontes** Oswald e Rubik empacotadas em `assets/fonts/` (OFL 1.1).
