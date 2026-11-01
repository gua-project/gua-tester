param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [string]$GodotExecutable = $env:GODOT_EXECUTABLE,
    [string]$ReleaseTag = $env:GUA_TESTER_ADDON_TAG
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$requireInfo = $true
if ($ReleaseTag -match '^gua-v(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$') {
    $requireInfo = [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])" -ge [version]'1.2.0'
} elseif ($ReleaseTag -like 'godot-plugin-*') { $requireInfo = $false }

$probeRoot = Join-Path ([IO.Path]::GetTempPath()) ("gua-tester-probe-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $probeRoot 'addons') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $project 'addons/gua') -Destination (Join-Path $probeRoot 'addons/gua') -Recurse
'config_version=5' | Set-Content -LiteralPath (Join-Path $probeRoot 'project.godot')
New-Item -ItemType Directory -Path (Join-Path $probeRoot '.godot') | Out-Null
'res://addons/gua/gua.gdextension' | Set-Content -LiteralPath (Join-Path $probeRoot '.godot/extension_list.cfg')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'remote-capability.gd') -Destination $probeRoot
$probe = Join-Path $probeRoot 'probe.gd'

@'
extends SceneTree
func _initialize() -> void:
    call_deferred("_probe")
func _probe() -> void:
    if not ClassDB.class_exists("GuaContext"):
        push_error("Gua tester: the native Gua extension could not be loaded.")
        quit(1)
        return
    var context = ClassDB.instantiate("GuaContext")
    if not context.has_method("get_build_info_json"):
        if OS.get_environment("GUA_TESTER_REQUIRE_BUILD_INFO") == "1":
            push_error("Gua tester: v1.2.0+ requires native build-info; replace the complete matching addon.")
            quit(1)
        else:
            print("Gua tester: legacy addon has no build-info; remote capability is not preflight-verified.")
            quit(0)
        return
    var info = JSON.parse_string(context.get_build_info_json())
    var policy = load("res://remote-capability.gd")
    var error: String = policy.check(info)
    if error != "":
        push_error("Gua tester: " + error)
        quit(1)
        return
    var expected_source = OS.get_environment("GUA_TESTER_EXPECTED_SOURCE")
    if expected_source != "" and info.get("sourceCommit") != expected_source:
        push_error("Gua tester: the loaded native extension does not match the expected native source commit.")
        quit(1)
        return
    print("GUA_TESTER_BUILD_INFO=" + JSON.stringify(info))
    if info.remotePermissionCeiling == "player":
        print("Gua tester: Player ceiling is fixed; tests must use host-exposed Player operations. No Debug elevation is attempted.")
    quit(0)
'@ | Set-Content -LiteralPath $probe -Encoding utf8NoBOM
$saved = $env:GUA_TESTER_REQUIRE_BUILD_INFO
try {
    $env:GUA_TESTER_REQUIRE_BUILD_INFO = if ($requireInfo) { '1' } else { '0' }
    # This probe reads capability only. It never starts a listener or changes a profile.
    $start = [Diagnostics.ProcessStartInfo]::new($GodotExecutable)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $userData = Join-Path $probeRoot 'userdata'
    New-Item -ItemType Directory -Path $userData -Force | Out-Null
    $start.Environment['APPDATA'] = $userData
    $start.Environment['LOCALAPPDATA'] = $userData
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('--headless','--path',$probeRoot,'--script','res://probe.gd')) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit(45000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'Gua native capability probe timed out.'
        }
        $output = $stdout.GetAwaiter().GetResult()
        Write-Host $output
        Write-Host $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -or
            ($output -notmatch 'GUA_TESTER_BUILD_INFO=' -and $output -notmatch 'legacy addon has no build-info')) {
            throw 'Gua remote preflight failed; see the native capability message above.'
        }
    } finally { $process.Dispose() }
} finally {
    $env:GUA_TESTER_REQUIRE_BUILD_INFO = $saved
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if (![IO.Path]::GetFullPath($probeRoot).StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe probe cleanup path.' }
    Remove-Item -LiteralPath $probeRoot -Recurse -Force
}
