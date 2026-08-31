# 2/W2 — návrat do výchozího stavu (složky znovu, s výchozími oprávněními)
. "$PSScriptRoot\..\..\lib\lab-lib.ps1"
$Koren = 'C:\NetLab'
$Form  = Join-Path $env:USERPROFILE 'netlab\ntfs.txt'

Write-Host ''
Write-Host "  Tím smažete celou složku $Koren včetně nastavených oprávnění"
Write-Host '  a vyprázdníte formulář. Účty se to nedotkne.'
$o = Read-Host '  Opravdu začít znovu? [a/N]'
if ($o -notmatch '^(a|ano|y|yes)$') { Write-Host '  Zrušeno.'; Write-Host ''; exit 0 }

if (Test-Path -LiteralPath $Koren) {
    try { Remove-Item -LiteralPath $Koren -Recurse -Force -ErrorAction Stop }
    catch {
        Write-Host "  Složku se smazat nepodařilo: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '  Nejspíš jste si z ní odebrali přístup — přidělte si ho zpátky'
        Write-Host '  přes Upřesnit → Změnit vlastníka a zkuste to znovu.'
        exit 1
    }
}
Remove-Item -LiteralPath $Form -ErrorAction SilentlyContinue
Write-Host '  Smazáno. Spusťte start.ps1.'
Write-Host ''
