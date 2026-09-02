# stahni.ps1 — stáhne skripty windowsových cvičení do C:\os-lab
#
# Windows VM nemá bash ani git, takže se skripty nestahují klonováním, ale
# jednotlivě z veřejného repozitáře. Spouštějte až potom, co jste si tenhle
# soubor přečetli — je to přesně ta situace, o které bylo cvičení o hashi
# a podpisu: stahujete kód z internetu a pouštíte ho na svém stroji.
param([string]$Cvic = '')

# Windows PowerShell 5.1 má ve výchozím stavu starší TLS a GitHub ho odmítá.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Zaklad = 'https://raw.githubusercontent.com/eduxo/os-lab/main/'
$Kam    = 'C:\os-lab'

$Soubory = @('lib/lab-lib.ps1')
switch ($Cvic) {
    'W1' { $Soubory += @('2-win/14a-windows-start/start.ps1','2-win/14a-windows-start/check.ps1',
                         '2-win/14a-windows-start/reset.ps1','2-win/14a-windows-start/stop.ps1') }
    'W2' { $Soubory += @('2-win/18a-windows-ntfs/start.ps1','2-win/18a-windows-ntfs/check.ps1',
                         '2-win/18a-windows-ntfs/reset.ps1','2-win/18a-windows-ntfs/stop.ps1') }
    default {
        Write-Host ''
        Write-Host '  Použití:  powershell -ExecutionPolicy Bypass -File .\stahni.ps1 -Cvic W1'
        Write-Host '            (nebo -Cvic W2)'
        Write-Host ''
        exit 1
    }
}

Write-Host ''
Write-Host "  Stahuji skripty cvičení $Cvic do $Kam …"
foreach ($s in $Soubory) {
    $cil = Join-Path $Kam ($s -replace '/', '\')
    New-Item -ItemType Directory -Force -Path (Split-Path $cil) | Out-Null
    try {
        Invoke-WebRequest -UseBasicParsing -Uri ($Zaklad + $s) -OutFile $cil
        # Windows označuje stažené soubory „z internetu" a PowerShell je pak
        # odmítá spustit. Značku odstraníme, ať to žáka nezastaví.
        Unblock-File -Path $cil -ErrorAction SilentlyContinue
        Write-Host "    $s"
    } catch {
        Write-Host "  Nepodařilo se stáhnout $s — zkontrolujte připojení k síti." -ForegroundColor Red
        exit 1
    }
}
Write-Host ''
Write-Host "  Hotovo. Přepněte se do adresáře cvičení a spusťte start.ps1:"
if ($Cvic -eq 'W1') { Write-Host '    cd C:\os-lab\2-win\14a-windows-start' }
else                { Write-Host '    cd C:\os-lab\2-win\18a-windows-ntfs' }
Write-Host '    powershell -ExecutionPolicy Bypass -File .\start.ps1'
Write-Host ''
