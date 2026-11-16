# Release do Fôlego: chave, APK e instalação

## 1. Chave de release (keystore)

O Android só instala uma **atualização** por cima do app se ela vier assinada
com a **mesma chave**. Perdeu a chave = precisa desinstalar (e perder os dados,
a não ser que você tenha um backup JSON). Então: gere uma vez e guarde bem.

No Ubuntu, **fora do repositório**:

```bash
mkdir -p ~/chaves
keytool -genkeypair -v \
  -keystore ~/chaves/folego-release.jks \
  -storetype PKCS12 \
  -alias folego \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

- `-keystore`: arquivo da chave. Guarde uma cópia num lugar seguro (pendrive,
  gerenciador de senhas). **Nunca** commite.
- `-alias`: nome da chave dentro do arquivo.
- `-validity 10000`: ~27 anos.
- O `keytool` pede uma senha e seus dados (nome etc.). Anote a senha.

Depois crie `android/key.properties` (já está no `.gitignore`):

```properties
storeFile=/home/SEU_USUARIO/chaves/folego-release.jks
storePassword=SUA_SENHA
keyAlias=folego
keyPassword=SUA_SENHA
```

O que **não** commitar: `android/key.properties`, qualquer `*.jks` ou
`*.keystore` de release. O `.gitignore` já bloqueia esses arquivos.

### A chave de teste versionada

Enquanto `android/key.properties` não existir, o Gradle assina com
`android/app/folego-teste.keystore` (senha `folego-teste`). Ela está no git de
propósito e **não é segredo**: serve só para que todo APK gerado pelo GitHub
Actions tenha a mesma assinatura e uma versão nova instale por cima da
anterior durante os testes.

Quando você passar a usar a sua chave de release, o Android vai recusar a
atualização por cima do APK de teste (assinaturas diferentes). Faça assim uma
única vez: **Mais › Backup e importação › Exportar backup**, desinstale,
instale o APK novo e **Importar backup**.

### Usar a sua chave no GitHub Actions (opcional)

Em *Settings › Secrets and variables › Actions* do repositório, crie:

| Secret | Valor |
|---|---|
| `FOLEGO_KEYSTORE_BASE64` | saída de `base64 -w0 ~/chaves/folego-release.jks` |
| `FOLEGO_KEYSTORE_PASSWORD` | senha do keystore |
| `FOLEGO_KEY_ALIAS` | `folego` |
| `FOLEGO_KEY_PASSWORD` | senha da chave |

Com os quatro definidos, o workflow assina com a sua chave; sem eles, usa a de
teste.

## 2. Gerar o APK

```bash
flutter build apk --release                 # universal (todas as arquiteturas)
flutter build apk --release --split-per-abi # menores, um por arquitetura
```

Saída em `build/app/outputs/flutter-apk/`:

- `app-release.apk` — universal, funciona em qualquer celular;
- `app-arm64-v8a-release.apk` — celulares atuais (64 bits). **Use este** se
  quiser o menor arquivo;
- `app-armeabi-v7a-release.apk` — celulares antigos de 32 bits;
- `app-x86_64-release.apk` — emuladores.

O workflow `.github/workflows/apk.yml` faz isso a cada push: roda
`flutter analyze` e `flutter test`, gera os APKs, **confere que não há
permissão `INTERNET`** e publica tudo numa *release* (pré-lançamento) do
repositório.

### Conferir as permissões à mão

```bash
$ANDROID_HOME/build-tools/<versão>/aapt2 dump permissions \
  build/app/outputs/flutter-apk/app-release.apk
```

Não deve aparecer `android.permission.INTERNET`.

## 3. Instalar no celular

**Pelo arquivo (mais simples):** baixe o APK no celular (pela página de
releases do GitHub ou copiando pelo cabo/Drive), toque nele e permita
"instalar apps desconhecidos" para o navegador ou gerenciador de arquivos
quando o Android pedir.

**Por USB com adb:** ative *Opções do desenvolvedor › Depuração USB* e:

```bash
adb devices                                   # o celular precisa aparecer
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

O `-r` reinstala mantendo os dados (mesma chave).

## 4. Nova versão

Suba a versão no `pubspec.yaml` a cada APK novo (`1.0.0+1` → `1.0.1+2`): o
número depois do `+` (versionCode) precisa sempre aumentar para o Android
aceitar a atualização.
