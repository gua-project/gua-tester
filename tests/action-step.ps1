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
