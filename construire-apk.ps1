# =====================================================================
#  Le Jardin du Tawhid - fabriquer l'APK en une seule commande
# ---------------------------------------------------------------------
#  Ce script fait tout, de bout en bout :
#    1. installe Java 21 s'il manque (exige par Capacitor 8)
#    2. installe le SDK Android s'il manque
#    3. configure le projet
#    4. compile l'APK
#    5. ouvre le dossier contenant l'APK
#
#  Lancement : clic droit -> "Executer avec PowerShell"
#  Depuis PowerShell :
#      powershell -ExecutionPolicy Bypass -File .\construire-apk.ps1
#
#  Le premier lancement prend une quinzaine de minutes (telechargements).
#  Les suivants : moins d'une minute.
# =====================================================================

$ErrorActionPreference = "Stop"

# Windows 10 + PowerShell 5.1 : sans cela, les telechargements HTTPS
# vers GitHub echouent.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$Racine = $PSScriptRoot
$Projet = Join-Path $Racine "android"
$SDK    = "C:\Android"
$APK    = Join-Path $Projet "app\build\outputs\apk\debug\app-debug.apk"

function Dire($msg)  { Write-Host ""; Write-Host "=== $msg ===" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "    OK   $msg" -ForegroundColor Green }
function Info($msg)  { Write-Host "    ->   $msg" -ForegroundColor Yellow }
function Echec($msg) { Write-Host "    !!   $msg" -ForegroundColor Red }

# Les outils Java ecrivent leurs messages sur le canal d'erreur. Avec
# ErrorActionPreference = Stop, PowerShell 5.1 prend cela pour un echec
# et coupe le script. On baisse la garde le temps de l'appel.
function Lancer-Natif {
    param([string]$Exe, [string[]]$Params)
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # "Out-Host" est indispensable : sans lui, la sortie de la commande
    # remonte dans le pipeline et se melange a la valeur de retour, si
    # bien que $code contient le texte affiche au lieu du code d'erreur.
    & $Exe @Params 2>&1 | Out-Host
    $code = $LASTEXITCODE
    $ErrorActionPreference = $ancien
    return $code
}

function Version-Majeure-De-Java($javaExe) {
    if (-not $javaExe) { return 0 }
    if (-not (Test-Path $javaExe)) { return 0 }
    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $sortie = & $javaExe -version 2>&1
    $ErrorActionPreference = $ancien
    $ligne = (($sortie | Out-String) -split "`n" | Select-Object -First 1)
    if ($ligne -match 'version "1\.(\d+)') { return [int]$Matches[1] }
    if ($ligne -match 'version "(\d+)')    { return [int]$Matches[1] }
    return 0
}

function Trouver-JDK21 {
    $bases = @(
        $env:JAVA_HOME,
        "C:\Program Files\Eclipse Adoptium",
        "C:\Program Files\Java",
        "C:\Program Files\Microsoft",
        "C:\Program Files\Amazon Corretto",
        "C:\Program Files\Zulu",
        "C:\Program Files\BellSoft",
        "C:\Program Files\OpenJDK",
        "C:\Program Files\Temurin"
    )

    foreach ($base in $bases) {
        if (-not $base) { continue }
        if (-not (Test-Path $base)) { continue }

        $dossiers = @()
        if (Test-Path "$base\bin\java.exe") { $dossiers += $base }

        $dossiers += Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
                     ForEach-Object { $_.FullName }

        foreach ($d in $dossiers) {
            $exe = Join-Path $d "bin\java.exe"
            if (-not (Test-Path $exe)) { continue }
            $v = Version-Majeure-De-Java $exe
            if ($v -ge 21) { return $d }
        }
    }

    # Dernier recours : le java du PATH
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd -and (Version-Majeure-De-Java $javaCmd.Source) -ge 21) {
        return Split-Path -Parent (Split-Path -Parent $javaCmd.Source)
    }
    return $null
}

# =====================================================================
# Etape 1 - Java 21
# =====================================================================
Dire "Etape 1/5 : Java 21 (exige par Capacitor 8)"

$jdk = Trouver-JDK21

if ($jdk) {
    Ok "JDK deja present : $jdk"
} else {
    Info "Aucun JDK 21 trouve. Telechargement de Temurin 21..."

    # On interroge l'API GitHub pour avoir la derniere version,
    # plutot qu'une adresse figee qui perimerait.
    $urlMsi = $null
    try {
        $entetes = @{ 'User-Agent' = 'jardin-du-tawhid' }
        $version = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/adoptium/temurin21-binaries/releases/latest" `
            -Headers $entetes -TimeoutSec 60
        $bon = $version.assets |
               Where-Object { $_.name -like 'OpenJDK21U-jdk_x64_windows_hotspot*.msi' } |
               Select-Object -First 1
        if ($bon) { $urlMsi = $bon.browser_download_url; Ok "Version proposee : $($bon.name)" }
    } catch {
        Echec "L'API GitHub n'a pas repondu, utilisation de l'adresse de secours."
    }

    if (-not $urlMsi) {
        $urlMsi = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13_9.msi"
    }

    $msi = Join-Path $env:TEMP "temurin-jdk21.msi"
    Info "Telechargement (environ 180 Mo)..."
    try {
        Invoke-WebRequest -Uri $urlMsi -OutFile $msi -TimeoutSec 1800
    } catch {
        Echec "Le telechargement a echoue : $($_.Exception.Message)"
        Write-Host "    Telechargez-le a la main puis relancez ce script :" -ForegroundColor White
        Write-Host "    $urlMsi" -ForegroundColor White
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }
    Ok "Telecharge : $msi"

    $admin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($admin) {
        Info "Installation silencieuse..."
        $code = Lancer-Natif "msiexec.exe" @(
            "/i", $msi, "/quiet", "/norestart",
            "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome"
        )
    } else {
        Info "L'assistant d'installation s'ouvre : laissez les options par defaut."
        Start-Process "msiexec.exe" -ArgumentList "/i `"$msi`"" -Wait
        $code = 0
    }

    if ($code -ne 0) {
        Echec "L'installation a echoue (code $code)."
        Write-Host "    Ouvrez le .msi vous-meme puis relancez ce script :" -ForegroundColor White
        Write-Host "    $msi" -ForegroundColor White
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }
    Ok "Java 21 installe"

    $jdk = Trouver-JDK21
    if (-not $jdk) {
        Echec "Java 21 installe mais introuvable. Redemarrez PowerShell et relancez."
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }
    Ok "JDK retenu : $jdk"
}

$env:JAVA_HOME = $jdk

# =====================================================================
# Etape 2 - SDK Android
# =====================================================================
Dire "Etape 2/5 : SDK Android"

$candidats = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    "$env:LOCALAPPDATA\Android\Sdk",
    $SDK
) | Where-Object { $_ -and (Test-Path "$_\platforms") }

if ($candidats) {
    $trouve = $candidats | Select-Object -First 1
    Ok "SDK deja present : $trouve"
} else {
    Info "Aucun SDK trouve. Recherche des outils en ligne de commande."

    $zip = Get-ChildItem "$env:USERPROFILE\Downloads" -Filter "commandlinetools-win-*.zip" -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $zip) {
        Write-Host ""
        Write-Host "    1. Ouvrez cette page :" -ForegroundColor White
        Write-Host "       https://developer.android.com/studio#command-line-tools-only" -ForegroundColor White
        Write-Host "    2. Acceptez les conditions, cliquez sur" -ForegroundColor White
        Write-Host "       'Download Android command line tools' (environ 130 Mo)" -ForegroundColor White
        Write-Host "    3. Laissez le .zip dans vos Telechargements" -ForegroundColor White
        Write-Host "    4. Relancez ce script" -ForegroundColor White
        Write-Host ""
        Start-Process "https://developer.android.com/studio#command-line-tools-only"
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }

    Ok "Archive trouvee : $($zip.Name)"

    $etape = "$SDK\cmdline-tools\_tmp"
    New-Item -ItemType Directory -Force -Path "$SDK\cmdline-tools" | Out-Null
    Expand-Archive -Path $zip.FullName -DestinationPath $etape -Force

    $source = "$etape\cmdline-tools"
    if (-not (Test-Path $source)) { $source = $etape }

    if (Test-Path "$SDK\cmdline-tools\latest") {
        Remove-Item "$SDK\cmdline-tools\latest" -Recurse -Force
    }
    Move-Item $source "$SDK\cmdline-tools\latest"
    if (Test-Path $etape) { Remove-Item $etape -Recurse -Force }
    Ok "Outils installes dans $SDK\cmdline-tools\latest"

    $sdkmanager = "$SDK\cmdline-tools\latest\bin\sdkmanager.bat"
    if (-not (Test-Path $sdkmanager)) {
        Echec "sdkmanager.bat introuvable."
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }

    Info "Acceptation des licences Google..."
    (@("y") * 30) | & $sdkmanager --licenses | Out-Null

    Info "Telechargement du SDK (environ 700 Mo, plusieurs minutes)..."
    $code = Lancer-Natif $sdkmanager @("--install", "platform-tools", "platforms;android-36", "build-tools;36.0.0")

    if ($code -ne 0) {
        Echec "Le telechargement du SDK a echoue (code $code)."
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }
    Ok "SDK installe"
    $trouve = $SDK
}

# =====================================================================
# Etape 3 - Configuration
# =====================================================================
Dire "Etape 3/5 : configuration du projet"

# local.properties : chemin du SDK, avec des slashes
$cheminSdk = $trouve -replace '\\', '/'
Set-Content -Path (Join-Path $Projet "local.properties") -Value "sdk.dir=$cheminSdk" -Encoding ASCII
Ok "android\local.properties -> sdk.dir=$cheminSdk"

# Gradle doit utiliser ce JDK precis, quel que soit le PATH.
# Fichier hors du depot : aucun git pull ne l'ecrasera.
$gradleHome  = Join-Path $env:USERPROFILE ".gradle"
$gradleProps = Join-Path $gradleHome "gradle.properties"
New-Item -ItemType Directory -Force -Path $gradleHome | Out-Null

$lignes = @()
if (Test-Path $gradleProps) {
    $lignes = Get-Content $gradleProps | Where-Object { $_ -notmatch '^\s*org\.gradle\.java\.home' }
}
$lignes += "org.gradle.java.home=" + ($jdk -replace '\\', '/')
Set-Content -Path $gradleProps -Value $lignes -Encoding ASCII
Ok "gradle.properties -> org.gradle.java.home=$jdk"

# =====================================================================
# Etape 4 - Copie des fichiers web puis compilation
# =====================================================================
Dire "Etape 4/5 : compilation de l'APK"

$node = Get-Command npm -ErrorAction SilentlyContinue
if ($node) {
    Info "Synchronisation des fichiers web..."
    $code = Lancer-Natif "cmd.exe" @("/c", "npx cap copy android")
    if ($code -eq 0) { Ok "Fichiers web a jour" } else { Echec "cap copy a echoue" }
} else {
    Echec "npm introuvable : les fichiers web ne seront pas resynchronises."
}

Info "Compilation en cours. La premiere fois : 5 a 10 minutes."
Info "Ne fermez pas cette fenetre."
Write-Host ""

$gradlew = Join-Path $Projet "gradlew.bat"
$debut = Get-Date
Push-Location $Projet
$code = Lancer-Natif $gradlew @("assembleDebug")
Pop-Location

# Filet de securite : si le code de retour est inattendu mais que l'APK
# vient tout juste d'etre produit, on fait confiance au fichier.
if ($code -ne 0 -and (Test-Path $APK)) {
    if ((Get-Item $APK).LastWriteTime -gt $debut) {
        Echec "Code de retour inattendu ($code), mais l'APK vient d'etre produit."
        $code = 0
    }
}

if ($code -ne 0) {
    Write-Host ""
    Echec "La compilation a echoue (code $code)."
    Write-Host "    Copiez le message d'erreur affiche ci-dessus et transmettez-le." -ForegroundColor White
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}

# =====================================================================
# Etape 5 - Resultat
# =====================================================================
Dire "Etape 5/5 : termine"

if (Test-Path $APK) {
    $taille = [math]::Round((Get-Item $APK).Length / 1MB, 1)
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host "   Votre APK est pret : $taille Mo" -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "   $APK" -ForegroundColor White
    Write-Host ""
    Write-Host "   Pour l'installer sur le telephone :" -ForegroundColor Yellow
    Write-Host "   copiez ce fichier sur le telephone (USB, Bluetooth ou WhatsApp" -ForegroundColor Yellow
    Write-Host "   a vous-meme), ouvrez-le, et autorisez les sources inconnues." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Une fois installee, l'application fonctionne sans connexion." -ForegroundColor Yellow
    Write-Host ""
    Start-Process "explorer.exe" -ArgumentList "/select,`"$APK`""
} else {
    Echec "Compilation reussie mais l'APK est introuvable a l'emplacement attendu."
}

Read-Host "Appuyez sur Entree pour terminer"
