# Gua Tester Actions

> [!IMPORTANT]
> **2026-10-01から、すべての利用者はgua-testerをv3.2へ更新してください。** Guaの`gua-project/gua`への移管（このActions repoも`gua-project/gua-tester`へ移管）への対応が必要です。すべてのActionとreusable workflowの参照を、以下の例のように`gua-project/gua-tester/...@v3.2`へ変更してください。**v3.2は公開予定で、まだリリースされていません。** 以下の例はメンテナーによる公開後に利用してください。更新対象は**gua-tester**であり、Guaライブラリのバージョンではありません。

[English](README.md) | 日本語

Godot 4.7／Unity 6プロジェクトでGua UIテストをCI実行するための
GitHub Actions部品群です。

このrepo自体はテスト対象ゲームではありません。利用者repo向けにGodotの
composite Action、Unityのreusable workflow、engine共通のVisual report機能を
提供します。

## Godot 4.7

Godot Actionは次を実行します。

- runnerに合うGodot公式版（Windows x64、Linux x64、macOS）をダウンロード
- 対象の Godot addon asset を含む `gua-project/gua` の最新安定版 `gua-v*` リリースを取得
- 対応desktop GDExtensionを含む`addons/gua` packageを展開
- 展開した addon を利用者の `game/addons/gua` へ配置
- `GODOT_EXECUTABLE` を設定して `dotnet test` を実行

`Gua.Testing.Godot` は .NET のテストホストですが、起動対象の Godot
プロジェクトは GDScript 版で構いません。ゲーム側が Gua addon で
`ws://127.0.0.1:8765` を立てれば、外部の .NET テストから検証できます。

## 最小Godot workflow

利用者repoの`.github/workflows/godot.yml`に置く想定です。

```yaml
name: Godot Gua UI Tests

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  godot:
    runs-on: ubuntu-22.04 # windows-latest／macOS runnerにも対応
    steps:
      - name: Check out game repository
        uses: actions/checkout@v4

      - name: Run Godot Gua tests
        uses: gua-project/gua-tester/godot@v3.2
        with:
          project-path: game
          test-project: tests/GuaTester.Tests.csproj
          godot-version: "4.7"
          godot-status: stable
          # 省略時は最新安定版の gua-v* リリースを使います。
          # gua-plugin-tag: gua-v1.0.7
```

本番workflowは`@v3.2`へ固定してください。v2ではroot Actionを削除しています。
移行方法は[v2への移行](#v2への移行)を参照してください。

## Godot Action inputs

`godot/action.yml`はall-in-one Godot Actionです。

- `project-path`: Godot プロジェクトのパス。既定値は `game`
- `test-project`: `Gua.Testing.Godot` を参照する .NET テスト csproj
- `godot-version`: `4.7` など
- `godot-status`: `stable`、`rc1`、`dev1` など
- `godot-executable-suffix`: Windows向け後方互換override。Linux／macOSは公式archive名を自動選択
- `dotnet-version`: 既定値 `10.0.x`
- `gua-repository`: 既定値 `gua-project/gua`
- `gua-plugin-tag`: `gua-v1.0.7` などの特定の Gua リリースタグ。省略時は
  対象 addon asset を含む最新安定版の `gua-v*` リリースを使います。旧形式の
  `godot-plugin-*` リリースにもフォールバックします。
- `gua-plugin-asset-pattern`: 既定値 `gua-godot-addon-*.zip`。既定設定では、古いGuaタグのWindowsアドオン名も後方互換として受け付けます。
- `configuration`: 既定値 `Release`
- `test-logger`: 既定値 `trx;LogFileName=godot.trx`

## Godot構成Action

必要なら all-in-one ではなく、部品ごとに使えます。

### setup-godot

```yaml
- uses: gua-project/gua-tester/setup-godot@v3.2
  with:
    godot-version: "4.7"
    godot-status: stable
```

`GODOT_EXECUTABLE` を環境変数に設定します。

### link-gua-gdscript-addon

```yaml
- uses: gua-project/gua-tester/link-gua-gdscript-addon@v3.2
  with:
    project-path: game
    # 省略時は最新安定版の gua-v* リリースを使います。
    # gua-plugin-tag: gua-v1.0.7
```

`gua-project/gua` の Godot plugin リリース asset をダウンロードし、その中の
`addons/gua` を `game/addons/gua` にコピーします。

## Unity 6 desktop Mono

Unityでは、Mono Playerをビルドし、対象OSのrunner上の外部NUnitテストから操作します。
既定値は従来どおり`WindowsX64`で、`LinuxX64`、`MacOSX64`、`MacOSArm64`、
`MacOSUniversal`も指定できます。

```yaml
name: Unity Gua UI Tests

on:
  pull_request:
  push:
    branches: [main]

jobs:
  unity:
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
    uses: gua-project/gua-tester/.github/workflows/unity.yml@v3.2
    with:
      project-path: game
      scene-path: Assets/Scenes/Title.unity
      test-project: tests/GuaTester.Unity.Tests.csproj
      artifact-key: game
      platform: LinuxX64
      unity-version: auto
      gua-tag: gua-v1.0.7
    secrets:
      UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}
      UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}
      UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
      UNITY_SERIAL: ${{ secrets.UNITY_SERIAL }}
```

Professionalライセンスでは`UNITY_LICENSE`の代わりに`UNITY_SERIAL`を渡せます。
fork PRにはActions secretsが渡らないため、呼び出し側で未信頼forkのUnity jobを
skipしてください。Unity credentialsを渡して未信頼コードを実行する
`pull_request_target`は使用しません。
Gua v1.0.4以降には、Linux／macOS platformで必要なcross-platform native assetが含まれます。

必須inputは`project-path`、`scene-path`、`test-project`と、呼び出しごとに一意な
`artifact-key`です。任意inputは
`platform`（`WindowsX64`）、`unity-version`（`auto`）、`gua-repository`（`gua-project/gua`）、`gua-tag`、
`dotnet-version`（`10.0.x`）、`configuration`（`Release`）、`test-logger`
（`trx;LogFileName=unity.trx`）、`artifact-path`（`artifacts/gua`）です。
`checkout-repository`と`checkout-ref`は別repoのfixtureを使う高度なoverrideです。
同じworkflow runから複数回呼び出す場合は、matrix値など呼び出し元で一意になる値を
`artifact-key`へ指定してください。

workflowは配布済み`com.link1345.gua-*.tgz`をembedded UPM packageとして配置し、
指定したrendered Mono Playerをビルドします。テスト時は`GUA_UNITY_PLAYER`と
`GUA_UNITY_ARTIFACT_PLAYER`を設定し、Unity build log、Player、TRX、Gua診断・
Visual artifactを保存します。Windowsは1920x1080へ固定し、LinuxはXvfbを使います。
対象はUnity 6000.5以降のMonoです。IL2CPP、IMGUI、EditorWindow自動化は対象外です。

`gua-tag`で選ぶUPM packageと、テストprojectが参照する`Gua.Testing.Unity`の
バージョンは揃えてください。

## Visual report

`Gua.Testing.Visual` は比較ごとに `comparison.json` と利用可能なPNGを出力します。
比較成功時にも現在画面の `actual.png` が含まれるため、差分がないレポートでも
現在の画面を表示できます。
`visual-report` action はrawデータを公開用 `report.json` へ変換し、同梱済みの
Astro製静的Viewerと合わせて、Pages artifactまたは通常のworkflow artifactとして
アップロードします。利用側CIでAstro、Node.js、npm依存をインストールする必要はありません。

```yaml
- name: Run Godot Gua tests
  id: gua-tests
  uses: gua-project/gua-tester/godot@v3.2
  with:
    project-path: game
    test-project: tests/GuaTester.Tests.csproj

- name: Prepare latest main visual report
  id: visual-report
  if: always() && github.event_name != 'pull_request'
  uses: gua-project/gua-tester/visual-report@v3.2
  with:
    artifact-path: artifacts/gua
    test-outcome: ${{ steps.gua-tests.outcome }}
    upload-target: pages
```

入力は次のとおりです。

- `artifact-path`: Visual artifact directory。既定値は `artifacts/gua`
- `test-outcome`: 必須。テストstepの結果で、`success`、`failure`、`cancelled` のいずれか
- `include-comparisons-on-success`: 成功レポートにも失敗した比較artifactを含めます。一致した現在画面は常に含まれます。既定値は `false`
- `upload-target`: `pages` または `workflow`。既定値は `pages`
- `pages-artifact-name`: Pages artifact名。既定値は `github-pages`
- `workflow-artifact-name`: 通常artifact名。既定値は `gua-visual-report`
- `retention-days`: artifactの保持日数。既定値は `7`

出力は `comparison-count` と `artifact-id` です。実際のdeployは利用側workflowの
専用jobで行い、`pages: write`、`id-token: write`、`github-pages` environmentを
明示してください。初回deploy前にrepositoryのPages sourceを **GitHub Actions**
へ設定します。完全な例は
[`examples/godot-ci.yml`](examples/godot-ci.yml)にあります。
`pages-artifact-name` を変更した場合は、同じ値を `actions/deploy-pages` の
`artifact_name` に渡してください。

`main` または手動実行では `upload-target: pages` を使います。pull requestの失敗時は
`upload-target: workflow` を使うと、Viewerと正規化済みreportを含む通常artifactを
保存できます。Viewerは `report.json` を読み込むため、ダウンロード後は `file://` で
直接開かず、展開先を `python -m http.server` などでHTTP配信してください。
mainが成功した場合は一致した現在画面を公開し、`include-comparisons-on-success` を
有効にしない限り失敗artifactは除外するため、以前の失敗を現在の結果に見せません。

> [!WARNING]
> Screenshotには、画面へ描画された秘密情報や個人情報が含まれる可能性があります。
> 特にpublic repositoryでPagesを有効にする前に、capture内容を確認してください。

## Godot addonのリンク方式

Git submodule はリポジトリ単位なので、
`https://github.com/gua-project/gua/tree/main/examples/godot-gdscript/addons/gua`
のようなサブディレクトリだけを直接 submodule にはできません。

そのため、この actions repo では `gua-project/gua` の `gua-v*` リリースから対象の
Godot addon asset をダウンロードし、リリース内の `addons/gua` だけを利用者の
Godot project へコピーします。旧形式の `godot-plugin-*` リリースにもフォールバック
します。リリース asset にはビルド済み Windows GDExtension DLL が含まれるので、
利用者 workflow 側で addon をソースからビルドする必要はありません。

## Godot利用repo側に必要なもの

- Godot GDScript project
- Gua addon を使って bridge を起動するゲーム側コード
- `Gua.Testing.Godot` を参照する .NET テストプロジェクト

テストプロジェクト例:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Gua.Testing.Godot" Version="1.0.7" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="NUnit" Version="4.3.2" />
    <PackageReference Include="NUnit3TestAdapter" Version="4.6.0" />
  </ItemGroup>

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
</Project>
```
