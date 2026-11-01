param([string]$GodotExecutable = $env:GODOT_EXECUTABLE)
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('gua-tester-policy-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../godot/remote-capability.gd') -Destination $testRoot
'config_version=5' | Set-Content (Join-Path $testRoot 'project.godot')
@'
extends SceneTree
func _initialize() -> void:
    var policy = load("res://remote-capability.gd")
    var checks = 0
    for profile in ["debug", "player"]:
        OS.set_environment("GUA_OBSERVATION_PROFILE", profile)
        for flavor in ["development", "qa", "ai-player"]:
            var info = {"flavor": flavor, "remoteEnabled": true, "remotePermissionCeiling": "player" if flavor == "ai-player" else "debug", "transports": ["websocket"]}
            if policy.check(info) != "":
                push_error("Rejected valid capability: " + flavor)
                quit(1)
                return
            checks += 1
        var invalid = [null, {}, {"remoteEnabled": "true"}, {"remoteEnabled": false},
            {"flavor": "shipping", "remoteEnabled": true},
            {"flavor": "ai-player", "remoteEnabled": true, "remotePermissionCeiling": "debug", "transports": ["websocket"]},
            {"flavor": "qa", "remoteEnabled": true, "remotePermissionCeiling": "debug", "transports": ["webmcp"]},
            {"flavor": "development", "remoteEnabled": true, "remotePermissionCeiling": "debug", "transports": "websocket"}]
        for info in invalid:
            if policy.check(info) == "":
                push_error("Accepted invalid capability")
                quit(1)
                return
            checks += 1
    print("GUA_TESTER_POLICY_CHECKS=" + str(checks))
    quit(0)
'@ | Set-Content -LiteralPath (Join-Path $testRoot 'test.gd') -Encoding utf8NoBOM
$savedAppData = $env:APPDATA
$savedLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = $testRoot
    $env:LOCALAPPDATA = $testRoot
    $output = & $GodotExecutable --headless --path $testRoot --script res://test.gd --quit-after 300 2>&1 | Out-String
    Write-Host $output
    if ($LASTEXITCODE -ne 0 -or $output -notmatch 'GUA_TESTER_POLICY_CHECKS=22') { throw 'Native remote preflight policy smoke failed.' }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocal
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if (![IO.Path]::GetFullPath($testRoot).StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe policy cleanup path.' }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
