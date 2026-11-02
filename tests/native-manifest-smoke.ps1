param([Parameter(Mandatory)][string]$PackagePath, [string]$Platform = 'WindowsX64')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'action-step.ps1')
$script = (Get-StepScript '.github/workflows/unity.yml' 'Install released Gua Unity package').Replace('${{ inputs.platform }}', $Platform)
$start = $script.IndexOf('# v1.2.0+')
$end = $script.IndexOf('$manifest = Get-Content', $start)
$check = [scriptblock]::Create($script.Substring($start, $end - $start))
$target = (Resolve-Path -LiteralPath $PackagePath).Path
$native = switch ($Platform) { 'WindowsX64' { 'Runtime/Plugins/Windows/x86_64' } 'LinuxX64' { 'Runtime/Plugins/Linux/x86_64' } default { 'Runtime/Plugins/macOS' } }
$nativeRoot = Join-Path $target $native
$proofPath = Join-Path $nativeRoot 'gua-build-manifest.json'
$original = [IO.File]::ReadAllText($proofPath)
$sourceCommit = ($original | ConvertFrom-Json).build.sourceCommit
$expectedVersion = '1.2.0'
$saved = $env:GUA_TEST_VARIANT
$env:GUA_TEST_VARIANT = 'development'
function Assert-Rejected([scriptblock]$Mutation, [string]$Name) {
    $proof = $original | ConvertFrom-Json
    & $Mutation $proof
    $proof | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $proofPath -Encoding utf8NoBOM
    $rejected = $false
    try { & $check } catch { $rejected = $true }
    if (!$rejected) { throw "Native manifest accepted $Name." }
    [IO.File]::WriteAllText($proofPath, $original)
    Write-Host "Rejected $Name."
}
try {
    & $check
    Assert-Rejected { param($p) $p.build.remoteEnabled = $false; $p.build.flavor = 'shipping' } 'ordinary release without remote code'
    Assert-Rejected { param($p) $p.build.remoteEnabled = 'true' } 'non-boolean capability'
    Assert-Rejected { param($p) $p.build.sourceCommit = ('0' * 40) } 'wrong release source commit'
    Assert-Rejected { param($p) $p.build.flavor = 'ai-player'; $p.build.remotePermissionCeiling = 'debug' } 'Player/Debug ceiling mismatch'
    Assert-Rejected { param($p) $p.files = @() } 'empty file records'
    Assert-Rejected { param($p) $p.files = @($p.files[0], $p.files[0]) } 'duplicate native identity'
    Assert-Rejected { param($p) $p.files[0].path = '../outside.dll' } 'escaping native path'
    Assert-Rejected { param($p) $p.files = @($p.files | Where-Object path -eq LICENSE) } 'missing native file records'
    $file = Join-Path $nativeRoot (($original | ConvertFrom-Json).files | Where-Object path -Match '\.(dll|so|dylib)$' | Select-Object -First 1 -ExpandProperty path)
    $bytes = [IO.File]::ReadAllBytes($file)
    try {
        [IO.File]::WriteAllBytes($file, $bytes + [byte]0)
        $rejected = $false
        try { & $check } catch { $rejected = $true }
        if (!$rejected) { throw 'Native manifest accepted modified native bytes.' }
    } finally { [IO.File]::WriteAllBytes($file, $bytes) }
    $extra = Join-Path $nativeRoot 'unlisted.dll'
    try {
        [IO.File]::WriteAllBytes($extra, [byte[]]@(0))
        $rejected = $false
        try { & $check } catch { $rejected = $true }
        if (!$rejected) { throw 'Native manifest accepted an unlisted native file.' }
    } finally { Remove-Item -LiteralPath $extra -Force }
    Remove-Item -LiteralPath $proofPath
    $rejected = $false
    try { & $check } catch { $rejected = $true }
    if (!$rejected) { throw 'Native manifest accepted missing inspection records.' }
    Write-Host 'Native manifest baseline and 11 rejection cases passed.'
} finally {
    [IO.File]::WriteAllText($proofPath, $original)
    $env:GUA_TEST_VARIANT = $saved
}
