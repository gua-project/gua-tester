# Gua Tester Actions

> [!IMPORTANT]
> **From 2026-10-01, all users must update gua-tester to v3.2** because Gua has moved to `gua-project/gua` (and this action repository to `gua-project/gua-tester`). Update every action and reusable workflow reference to `gua-project/gua-tester/...@v3.2` as shown below. **v3.2 is planned and is not published yet**; the examples below apply once the maintainer publishes it. This requirement is for **gua-tester**, not the Gua library version.

English | [日本語](README.ja.md)

GitHub Actions building blocks for running Gua UI tests in Godot 4.7 and
Unity 6 projects.

This repository is not a sample game repository. It provides a Godot composite
action, a Unity reusable workflow, and engine-neutral visual report tooling for
consumer repositories.

## Godot 4.7

The Godot action:

- Downloads the official Godot build matching the Windows x64, Linux x64, or macOS runner
- Downloads the latest stable `gua-v*` release containing a matching Godot addon asset from `gua-project/gua`
- Extracts the released `addons/gua` package, including the matching desktop GDExtension
- Copies the released addon into the consumer project's `game/addons/gua`
- Sets `GODOT_EXECUTABLE` and runs `dotnet test`

`Gua.Testing.Godot` is a .NET test host, but the launched Godot project can be a
GDScript project. As long as the game starts the Gua addon bridge at
`ws://127.0.0.1:8765`, external .NET tests can validate the live UI tree.

## Minimal Godot Workflow

Place this in the consumer repository at `.github/workflows/godot.yml`.

```yaml
name: Godot Gua UI Tests

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  godot:
    runs-on: ubuntu-22.04 # windows-latest and macOS runners are also supported
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
          # Optional. Leave unset to use the latest stable gua-v* release.
          # gua-plugin-tag: gua-v1.0.7
```

Pin production workflows to `@v3.2`. The root action was removed in v2; see the
[v2 migration](#v2-migration) section.

## Godot Action Inputs

`godot/action.yml` is the all-in-one Godot action.

- `project-path`: Path to the Godot project. Default: `game`
- `test-project`: Path to the .NET test `.csproj` that references
  `Gua.Testing.Godot`
- `godot-version`: For example, `4.7`
- `godot-status`: For example, `stable`, `rc1`, or `dev1`
- `godot-executable-suffix`: Legacy Windows-only override. Linux and macOS use their official archive names automatically
- `dotnet-version`: Default: `10.0.x`
- `gua-repository`: Default: `gua-project/gua`
- `gua-plugin-tag`: Specific Gua release tag, such as `gua-v1.0.7`. By
  default, the latest stable `gua-v*` release containing a matching addon asset
  is used. Legacy `godot-plugin-*` releases remain as a fallback.
- `gua-plugin-asset-pattern`: Default: `gua-godot-addon-*.zip`. The default also accepts the legacy Windows addon name for older Gua tags.
- `configuration`: Default: `Release`
- `test-logger`: Default: `trx;LogFileName=godot.trx`

## Godot Component Actions

You can also use the smaller actions separately.

### setup-godot

```yaml
- uses: gua-project/gua-tester/setup-godot@v3.2
  with:
    godot-version: "4.7"
    godot-status: stable
```

This sets the `GODOT_EXECUTABLE` environment variable.

### link-gua-gdscript-addon

```yaml
- uses: gua-project/gua-tester/link-gua-gdscript-addon@v3.2
  with:
    project-path: game
    # Optional. Leave unset to use the latest stable gua-v* release.
    # gua-plugin-tag: gua-v1.0.7
```

This downloads the released `gua-project/gua` Godot plugin asset and copies its
`addons/gua` directory to `game/addons/gua`.

## Unity 6 desktop Mono

Unity uses a reusable workflow to build a Mono Player and exercise it through
external NUnit tests on the matching runner. `WindowsX64` remains the default;
`LinuxX64`, `MacOSX64`, `MacOSArm64`, and `MacOSUniversal` are also supported.

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

Professional licenses can pass `UNITY_SERIAL` instead of `UNITY_LICENSE`.
Fork pull requests do not receive Actions secrets, so the calling workflow must
skip the Unity job for untrusted forks. Do not use `pull_request_target` to run
untrusted game code with Unity credentials.
Gua v1.0.4 and later include the cross-platform native assets required by the
Linux and macOS platform values.

Required inputs are `project-path`, `scene-path`, `test-project`, and a unique
`artifact-key` for each reusable workflow invocation. Optional
inputs are `platform` (`WindowsX64`), `unity-version` (`auto`), `gua-repository` (`gua-project/gua`),
`gua-tag`, `dotnet-version` (`10.0.x`), `configuration` (`Release`),
`test-logger` (`trx;LogFileName=unity.trx`), and `artifact-path`
(`artifacts/gua`). `checkout-repository` and `checkout-ref` are advanced
overrides used when the project and tests come from another repository.
Use a matrix value or another stable caller-specific value for `artifact-key`
when the reusable workflow is invoked more than once in the same workflow run.

The workflow installs the released `com.link1345.gua-*.tgz` as an embedded UPM
package, builds the requested rendered Mono Player, and sets both
`GUA_UNITY_PLAYER` and `GUA_UNITY_ARTIFACT_PLAYER` for `dotnet test`. Unity
build logs, the Player, TRX results, and Gua diagnostic/visual artifacts are
retained as workflow artifacts. Windows uses a fixed 1920x1080 display and Linux
uses Xvfb. Unity 6000.5+ and Mono are required; IL2CPP, IMGUI, and EditorWindow
automation are outside this workflow scope.

Keep the UPM release selected by `gua-tag` aligned with the
`Gua.Testing.Unity` NuGet version used by the test project.

## Visual reports

`Gua.Testing.Visual` writes `comparison.json` and the available PNG files for
each comparison. A successful comparison includes its current `actual.png`, so a
report with no visual differences can still show the current screen. The
`visual-report` action converts that raw data into a
public `report.json`, combines it with the bundled Astro-built static viewer,
and uploads either a Pages artifact or a regular workflow artifact. Consumers do
not install Astro, Node.js, or npm dependencies.

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

The action accepts:

- `artifact-path`: Visual artifact directory. Default: `artifacts/gua`
- `test-outcome`: Required test step outcome: `success`, `failure`, or `cancelled`
- `include-comparisons-on-success`: Also include failed comparison artifacts while keeping a successful report status. Matched current screens are always included. Default: `false`
- `upload-target`: `pages` or `workflow`. Default: `pages`
- `pages-artifact-name`: Pages artifact name. Default: `github-pages`
- `workflow-artifact-name`: Workflow artifact name. Default: `gua-visual-report`
- `retention-days`: Artifact retention period. Default: `7`

It outputs `comparison-count` and `artifact-id`. Deployment remains a separate job
owned by the consumer workflow, where `pages: write`, `id-token: write`, and the
`github-pages` environment can be reviewed explicitly. Configure the repository's
Pages source as **GitHub Actions** before the first deployment. See the complete
[`examples/godot-ci.yml`](examples/godot-ci.yml) workflow.
If `pages-artifact-name` is customized, pass the same value as `artifact_name`
to `actions/deploy-pages`.

Use `upload-target: pages` for `main` or manually dispatched runs. On failed pull
requests use `upload-target: workflow`; the downloaded artifact already contains
the viewer and normalized report. Because the viewer loads `report.json`, serve
the extracted directory over local HTTP rather than opening `index.html` through
`file://` (for example, `python -m http.server`). A successful main run publishes
matched current screens but filters out failure artifacts unless
`include-comparisons-on-success` is enabled, so a previous failure is not
presented as current.

> [!WARNING]
> Screenshots can contain rendered secrets or personal information. Review the
> captured content before enabling Pages, especially for public repositories.

## Godot Addon Linking

Git submodules work at repository granularity, so they cannot directly link only
the subdirectory
`https://github.com/gua-project/gua/tree/main/examples/godot-gdscript/addons/gua`.

For that reason, these actions download the matching Godot addon asset from a
`gua-v*` release in `gua-project/gua` and copy only the released `addons/gua`
directory into the consumer Godot project. Legacy `godot-plugin-*` releases are
supported as a fallback. The release asset already includes the built Windows
GDExtension DLLs, so the consumer workflow does not build the addon from source.

## Godot Consumer Repository Requirements

- A Godot GDScript project
- Game-side code that starts the Gua bridge through the Gua addon
- A .NET test project that references `Gua.Testing.Godot`

Example test project:

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
