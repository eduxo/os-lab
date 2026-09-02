# 2/W1 — Windows 11: první start, účty a UAC. Prostředí: windowsová VM.
# Nic nezakládá — účty jsou učivo. Připraví jen formulář a vypíše zadání.
. "$PSScriptRoot\..\..\lib\lab-lib.ps1"

$Doku = Join-Path $env:USERPROFILE 'netlab'
$Form = Join-Path $Doku 'stanice.txt'

if (Test-Path -LiteralPath $Form) {
    Write-Host ''
    Write-Host "  Prostředí už existuje — pokračujte, kde jste skončili."
    Write-Host "  Jméno stanice:  $ZakStanice"
    Write-Host "  Účty:           $ZakUzivatel (běžný) a $ZakSpravce (správce)"
    Write-Host ''
    exit 0
}

New-Item -ItemType Directory -Force -Path $Doku | Out-Null
@"
# Přehled stanice — vyplňte hodnoty za dvojtečku.
# Řádky s mřížkou nechte být.
#
# vydani  = edice Windows (např. Windows 11 Pro)
# sestaveni = číslo sestavení (build)
# sid     = SID účtu $ZakUzivatel
vydani:
sestaveni:
sid:
"@ | Set-Content -LiteralPath $Form -Encoding UTF8

Write-Host ''
Write-Host '  Prostředí je připravené.'
Write-Host ''
Write-Host "    Formulář:       $Form"
Write-Host "    Jméno stanice:  $ZakStanice"
Write-Host "    Běžný účet:     $ZakUzivatel"
Write-Host "    Účet správce:   $ZakSpravce"
Write-Host ''
Write-Host '  Průběžnou kontrolu spouštějte odsud:'
Write-Host '    powershell -ExecutionPolicy Bypass -File .\check.ps1 -Krok 1'
Write-Host ''
