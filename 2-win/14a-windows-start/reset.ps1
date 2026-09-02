# 2/W1 — návrat do výchozího stavu: smaže účty, které cvičení zadává
. "$PSScriptRoot\..\..\lib\lab-lib.ps1"
$Doku = Join-Path $env:USERPROFILE 'netlab'
$Spravce = $ZakSpravce

Write-Host ''
Write-Host "  Tím smažete účty $ZakUzivatel a $Spravce"
Write-Host '  a vyprázdníte formulář. Jméno stanice ani jejich profily se nemění.'
$o = Read-Host '  Opravdu začít znovu? [a/N]'
if ($o -notmatch '^(a|ano|y|yes)$') { Write-Host '  Zrušeno.'; Write-Host ''; exit 0 }

foreach ($u in @($ZakUzivatel, $Spravce)) {
    if (Get-LocalUser -Name $u -ErrorAction SilentlyContinue) {
        try {
            Remove-LocalUser -Name $u -ErrorAction Stop
            Write-Host "  Účet $u smazán."
        } catch {
            Write-Host "  Účet $u se smazat nepodařilo: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
Write-Host '  Pozn.: profil účtu (složka v C:\Users) zůstává — Windows ho'
Write-Host '  s účtem nemažou. Smazat ho jde v Nastavení systému.'
Remove-Item -LiteralPath (Join-Path $Doku 'stanice.txt') -ErrorAction SilentlyContinue
Write-Host '  Hotovo. Spusťte start.ps1.'
Write-Host ''
