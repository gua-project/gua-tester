param([string]$GuaTag = "")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("gua-release-smoke-" + [Guid]::NewGuid().ToString("N"))
$savedEnvironment = @{}
foreach ($name in @("RUNNER_TEMP", "RUNNER_OS", "RUNNER_ARCH", "GUA_REPOSITORY", "GUA_TAG", "PROJECT_PATH")) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}

# Execute the production inline scripts, rather than reimplementing release resolution.
function Get-StepScript([string]$File, [string]$Step) {
    $lines = Get-Content -LiteralPath (Join-Path $root $File)
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq "- name: $Step") { $start = $i; break }
    }
    if ($start -lt 0) { throw "Step '$Step' was not found in '$File'." }
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(\s*)run: \|\s*$') {
            $indent = $Matches[1].Length + 2
            $body = @()
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j].Trim() -and [regex]::Match($lines[$j], '^\s*').Length -lt $indent) { break }
                $body += if ($lines[$j].Length -ge $indent) { $lines[$j].Substring($indent) } else { "" }
            }
            return $body -join "`n"
        }
    }
    throw "Inline script was not found for '$Step'."
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $env:RUNNER_TEMP = $testRoot
    if (!$env:RUNNER_OS) { $env:RUNNER_OS = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } else { "Linux" } }
    if (!$env:RUNNER_ARCH) { $env:RUNNER_ARCH = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToUpperInvariant() }
    $env:GUA_REPOSITORY = "gua-project/gua"
    $env:GUA_TAG = $GuaTag
    Push-Location $testRoot
    foreach ($step in @(
        @{ file = "godot/action.yml"; name = "Download and link Gua addon"; project = "godot" },
        @{ file = "link-gua-gdscript-addon/action.yml"; name = "Download and copy addon into Godot project"; project = "link" }
    )) {
        $script = Get-StepScript $step.file $step.name
        $script = $script.Replace('${{ inputs.gua-repository }}', $env:GUA_REPOSITORY).
            Replace('${{ inputs.gua-plugin-tag }}', $GuaTag).
            Replace('${{ inputs.gua-plugin-asset-pattern }}', 'gua-godot-addon-*.zip').
            Replace('${{ inputs.project-path }}', $step.project)
        & ([scriptblock]::Create($script))
        if (!(Test-Path "$($step.project)/addons/gua/plugin.cfg")) { throw "Addon was not installed by $($step.file)." }
        Write-Host "Verified $($step.file) release download, extraction, native plugin validation and installation."
    }

    $env:PROJECT_PATH = "unity"
    New-Item -ItemType Directory -Path "unity/Packages" | Out-Null
    '{"dependencies":{"com.link1345.gua":"old","com.example.keep":"1.0.0"}}' | Set-Content "unity/Packages/manifest.json"
    $platform = switch ($env:RUNNER_OS) { "Windows" { "WindowsX64" } "Linux" { "LinuxX64" } default { "MacOSArm64" } }
    $script = (Get-StepScript ".github/workflows/unity.yml" "Install released Gua Unity package").Replace('${{ inputs.platform }}', $platform)
    & ([scriptblock]::Create($script))
    $manifest = Get-Content "unity/Packages/manifest.json" -Raw | ConvertFrom-Json
    if ($manifest.dependencies.'com.link1345.gua' -or $manifest.dependencies.'com.example.keep' -ne "1.0.0") {
        throw "Embedded-package installation did not preserve unrelated dependencies."
    }
    Write-Host "Verified Unity release resolution, extraction, managed/native plugins, package version and manifest migration."
} finally {
    if ((Get-Location).Path -eq $testRoot) { Pop-Location }
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    # Only remove the unique directory created by this test, within the OS temp directory.
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if (![IO.Path]::GetFullPath($testRoot).StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe test cleanup path." }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
