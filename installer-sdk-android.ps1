# =====================================================================
#  Le Jardin du Tawhid - preparation de l'environnement de compilation
# ---------------------------------------------------------------------
#  Ce script verifie que Java 21 est present (exige par Capacitor 8),
#  installe le SDK Android si besoin, et configure le projet.
#
#  Environ 700 Mo de SDK au lieu des 5 Go d'Android Studio.
#
#  Lancement : clic droit sur le fichier -> "Executer avec PowerShell"
#  ou, dans PowerShell :
#      powershell -ExecutionPolicy Bypass -File .\installer-sdk-android.ps1
# =====================================================================

$ErrorActionPreference = "Stop"
$SDK = "C:\Android"

function Dire($msg) {
    Write-Host ""
    Write-Host "=== $msg ===" -ForegroundColor Cyan
}

function Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "    ->  $msg" -ForegroundColor Yellow }

# Les outils Java (java, sdkmanager) ecrivent leurs messages sur le canal
# d'erreur. Avec $ErrorActionPreference = "Stop", PowerShell 5.1 prend cela
# pour un echec et interrompt le script. On baisse donc la garde le temps
# de les appeler.
function Lancer-Natif {
    param([string]$Exe, [string[]]$Params)

    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Exe @Params
    $code = $LASTEXITCODE
    $ErrorActionPreference = $ancien

    return $code
}

# Renvoie le numero de version majeur (17, 21, 24...) ou 0 si absent.
function Version-Majeure-De-Java($javaExe) {
    if (-not $javaExe) { return 0 }
    if (-not (Test-Path $javaExe)) { return 0 }

    $ancien = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $sortie = & $javaExe -version 2>&1
    $ErrorActionPreference = $ancien

    $ligne = (($sortie | Out-String) -split "`n" | Select-Object -First 1)
    if ($ligne -match 'version "1\.(\d+)')  { return [int]$Matches[1] }  # ancien schema : 1.8
    if ($ligne -match 'version "(\d+)')     { return [int]$Matches[1] }
    return 0
}

# ---------------------------------------------------------------------
# 0. Recherche d'un JDK 21 (Capacitor 8 compile en Java 21)
# ---------------------------------------------------------------------
Dire "Recherche de Java 21"

$javaCmd = Get-Command java -ErrorAction SilentlyContinue
$versionJava = if ($javaCmd) { Version-Majeure-De-Java $javaCmd.Source } else { 0 }

if ($javaCmd) { Info "java du PATH : version $versionJava ($($javaCmd.Source))" }

# Emplacements d'installation courants sous Windows
$motifs = @(
    "$env:JAVA_HOME",
    "C:\Program Files\Eclipse Adoptium",
    "C:\Program Files\Java",
    "C:\Program Files\Microsoft",
    "C:\Program Files\Amazon Corretto",
    "C:\Program Files\Zulu",
    "C:\Program Files\BellSoft\LibericaJDK*",
    "C:\Program Files\OpenJDK"
)

$jdk21 = $null
$cheminJavaCmd = if ($javaCmd) { $javaCmd.Source } else { $null }

foreach ($base in $motifs) {
    if (-not $base) { continue }

    # Soit $base est deja un dossier de JDK, soit il en contient
    $dossiers = @()
    if (Test-Path "$base\bin\java.exe") { $dossiers += $base }
    elseif ($base -like '*jdk*' -or $base -like '*Java*' -or $base -like '*Microsoft*') {
        $dossiers += Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match 'jdk.*(21|22|23|24|25)' } |
                     ForEach-Object { $_.FullName }
    } else {
        $dossiers += Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
                     ForEach-Object { $_.FullName }
    }

    foreach ($d in $dossiers) {
        $exe = Join-Path $d "bin\java.exe"
        if (-not (Test-Path $exe)) { continue }
        $v = Version-Majeure-De-Java $exe
        if ($v -ge 21) { $jdk21 = $d; Info "JDK $v trouve : $d"; break }
    }
    if ($jdk21) { break }
}

if (-not $jdk21 -and $versionJava -ge 21 -and $cheminJavaCmd) {
    # java du PATH convient : on remonte au dossier du JDK
    $jdk21 = Split-Path -Parent (Split-Path -Parent $cheminJavaCmd)
    Info "Utilisation du java du PATH : $jdk21"
}

if (-not $jdk21) {
    Write-Host ""
    Write-Host "    Capacitor 8 exige Java 21 minimum, et aucun JDK 21" -ForegroundColor Red
    if ($versionJava -gt 0) {
        Write-Host "    n'a ete trouve (vous avez Java $versionJava)." -ForegroundColor Red
    } else {
        Write-Host "    n'a ete trouve sur cette machine." -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "    Vous pouvez garder Java $versionJava : les JDK coexistent sans probleme." -ForegroundColor White
    Write-Host ""
    Write-Host "    1. Ouvrez https://adoptium.net" -ForegroundColor White
    Write-Host "    2. Prenez 'JDK 21 (LTS)', Windows x64, .msi" -ForegroundColor White
    Write-Host "    3. Installez-le en laissant les options par defaut" -ForegroundColor White
    Write-Host "    4. Relancez ce script" -ForegroundColor White
    Write-Host ""
    Start-Process "https://adoptium.net"
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}

Ok "JDK retenu : $jdk21"

# --- Gradle doit utiliser ce JDK precis, quel que soit le PATH.
#     On l'inscrit dans le fichier de configuration utilisateur de Gradle
#     (hors du depot, donc jamais ecrase par un git pull).
Dire "Configuration de Gradle"

$gradleHome = Join-Path $env:USERPROFILE ".gradle"
$gradleProps = Join-Path $gradleHome "gradle.properties"
New-Item -ItemType Directory -Force -Path $gradleHome | Out-Null

$cheminGradle = $jdk21 -replace '\\', '/'

$lignes = @()
if (Test-Path $gradleProps) {
    $lignes = Get-Content $gradleProps | Where-Object { $_ -notmatch '^\s*org\.gradle\.java\.home' }
}
$lignes += "org.gradle.java.home=$cheminGradle"
Set-Content -Path $gradleProps -Value $lignes -Encoding ASCII
Ok "$gradleProps : org.gradle.java.home=$cheminGradle"

# Verification
$verif = Version-Majeure-De-Java (Join-Path $jdk21 "bin\java.exe")
if ($verif -lt 21) {
    Write-Host "    Ce JDK n'a pas pu etre lu correctement." -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}
Ok "Confirme : Java $verif"

# ---------------------------------------------------------------------
# 1. Un SDK est-il deja present ?
# ---------------------------------------------------------------------
Dire "Recherche d'un SDK Android existant"

$candidats = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    "$env:LOCALAPPDATA\Android\Sdk",
    "$SDK"
) | Where-Object { $_ -and (Test-Path "$_\platforms") }

if ($candidats) {
    $trouve = $candidats | Select-Object -First 1
    Ok "SDK deja present : $trouve"
} else {
    Info "Aucun SDK trouve. Installation des outils en ligne de commande."

    $zip = Get-ChildItem "$env:USERPROFILE\Downloads" -Filter "commandlinetools-win-*.zip" -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $zip) {
        Write-Host ""
        Write-Host "    Le fichier des outils en ligne de commande n'a pas ete trouve" -ForegroundColor Red
        Write-Host "    dans votre dossier Telechargements." -ForegroundColor Red
        Write-Host ""
        Write-Host "    1. Ouvrez cette page :" -ForegroundColor White
        Write-Host "       https://developer.android.com/studio#command-line-tools-only" -ForegroundColor White
        Write-Host "    2. Acceptez les conditions, puis cliquez sur" -ForegroundColor White
        Write-Host "       'Download Android command line tools' (environ 130 Mo)" -ForegroundColor White
        Write-Host "    3. Laissez le fichier .zip dans Telechargements" -ForegroundColor White
        Write-Host "    4. Relancez ce script" -ForegroundColor White
        Write-Host ""
        Start-Process "https://developer.android.com/studio#command-line-tools-only"
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }

    Ok "Archive trouvee : $($zip.Name)"

    # --- Extraction : piege classique, il faut imbriquer cmdline-tools\latest
    $etape = "$SDK\cmdline-tools\_tmp"
    New-Item -ItemType Directory -Force -Path "$SDK\cmdline-tools" | Out-Null
    Info "Extraction en cours..."
    Expand-Archive -Path $zip.FullName -DestinationPath $etape -Force

    $source = "$etape\cmdline-tools"
    if (-not (Test-Path $source)) { $source = $etape }

    if (Test-Path "$SDK\cmdline-tools\latest") {
        Remove-Item "$SDK\cmdline-tools\latest" -Recurse -Force
    }
    Move-Item $source "$SDK\cmdline-tools\latest"
    if (Test-Path $etape) { Remove-Item $etape -Recurse -Force }
    Ok "Outils installes dans $SDK\cmdline-tools\latest"

    # --- Telechargement des composants du SDK
    $sdkmanager = "$SDK\cmdline-tools\latest\bin\sdkmanager.bat"
    if (-not (Test-Path $sdkmanager)) {
        Write-Host "    sdkmanager.bat introuvable, l'arborescence est inattendue." -ForegroundColor Red
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }

    Dire "Acceptation des licences Google"
    Write-Host "    Tapez y puis Entree autant de fois que demande." -ForegroundColor Yellow
    Write-Host ""
    Lancer-Natif $sdkmanager @("--licenses") | Out-Null

    Dire "Telechargement du SDK (platformes + outils de compilation)"
    Info "Environ 700 Mo. Cela peut prendre plusieurs minutes."
    $code = Lancer-Natif $sdkmanager @("--install", "platform-tools", "platforms;android-36", "build-tools;36.0.0")

    if ($code -ne 0) {
        Write-Host "    Le telechargement a echoue (code $code)." -ForegroundColor Red
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }
    Ok "SDK installe"

    $trouve = $SDK
}

# ---------------------------------------------------------------------
# 2. Creation du fichier local.properties
# ---------------------------------------------------------------------
Dire "Configuration du projet"

# Les chemins Windows s'ecrivent avec des slashes dans un .properties
$chemin = $trouve -replace '\\', '/'
$fichier = Join-Path $PSScriptRoot "android\local.properties"

Set-Content -Path $fichier -Value "sdk.dir=$chemin" -Encoding ASCII
Ok "android\local.properties : sdk.dir=$chemin"

# ---------------------------------------------------------------------
# 3. Termine
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  Environnement pret. Vous pouvez maintenant compiler l'APK :" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "      cd android" -ForegroundColor White
Write-Host "      .\gradlew.bat assembleDebug" -ForegroundColor White
Write-Host ""
Write-Host "  Le premier build prend 5 a 10 minutes." -ForegroundColor Yellow
Write-Host "  L'APK sera dans : android\app\build\outputs\apk\debug\app-debug.apk" -ForegroundColor Yellow
Write-Host ""
Read-Host "Appuyez sur Entree pour terminer"
