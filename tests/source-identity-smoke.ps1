$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'action-step.ps1')
$saved = $env:GUA_EXPECTED_SOURCE_COMMIT
$savedRepository = $env:GUA_REPOSITORY
$repository = 'fixture/asset-mirror'
$env:GUA_REPOSITORY = $repository
$headers = @{}
$release = [pscustomobject]@{ tag_name = 'gua-v1.2.0' }
$tagCommit = 'b' * 40
$upstreamCommit = 'a' * 40
function Invoke-RestMethod($Uri, $Headers) {
    $script:requests++
    if ($script:mode -eq 'forbidden') { throw 'A mirror override must not request its repository tag SHA.' }
    $kind = 'commit'
    if ($script:mode -eq 'annotated' -and $Uri.Contains('/git/ref/tags/')) { $kind = 'tag' }
    if ($script:mode -eq 'loop') { $kind = 'tag' }
    if ($script:mode -eq 'invalid') { $kind = 'tree' }
    return [pscustomobject]@{ object = [pscustomobject]@{ type = $kind; sha = $tagCommit } }
}
function Assert-IdentityRejected([scriptblock]$Resolver) {
    $rejected = $false
    try { & $Resolver | Out-Null } catch { $rejected = $true }
    if (!$rejected) { throw 'An invalid source identity was accepted.' }
}
try {
    foreach ($step in @(
        @{ file='godot/action.yml'; name='Download and link Gua addon' },
        @{ file='link-gua-gdscript-addon/action.yml'; name='Download and copy addon into Godot project' },
        @{ file='.github/workflows/unity.yml'; name='Install released Gua Unity package' }
    )) {
        $code = Get-StepScript $step.file $step.name
        $start = $code.IndexOf('# Resolve native source commit')
        $end = $code.IndexOf('# End native source commit resolution.', $start)
        $resolver = [scriptblock]::Create($code.Substring($start, $end-$start) + "`nreturn `$sourceCommit")
        $script:mode = 'forbidden'; $script:requests = 0
        $env:GUA_EXPECTED_SOURCE_COMMIT = $upstreamCommit
        if ((& $resolver) -cne $upstreamCommit -or $script:requests -ne 0) { throw 'Mirror source override was not preserved.' }
        $env:GUA_EXPECTED_SOURCE_COMMIT = 'invalid-source-sha'
        Assert-IdentityRejected $resolver
        if ($script:requests -ne 0) { throw 'Invalid source input reached the API.' }
        $env:GUA_EXPECTED_SOURCE_COMMIT = ''
        foreach ($case in @(@{ mode='default'; count=1 }, @{ mode='annotated'; count=2 })) {
            $script:mode = $case.mode; $script:requests = 0
            if ((& $resolver) -cne $tagCommit -or $script:requests -ne $case.count) { throw 'Default tag resolution failed.' }
        }
        $script:mode = 'invalid'; $script:requests = 0
        Assert-IdentityRejected $resolver
        $script:mode = 'loop'; $script:requests = 0
        Assert-IdentityRejected $resolver
        if ($script:requests -ne 6) { throw 'Annotated tag resolution was not bounded.' }
    }
    Write-Host 'Source identity resolution: 18 cases passed (3 production installers).'
} finally {
    $env:GUA_EXPECTED_SOURCE_COMMIT = $saved
    $env:GUA_REPOSITORY = $savedRepository
}
