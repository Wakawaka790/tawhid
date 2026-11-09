# =====================================================================
#  Le Jardin du Tawhid - installation du SDK Android
# ---------------------------------------------------------------------
#  Ce script installe le strict necessaire pour compiler l'APK :
#  environ 700 Mo au lieu des 5 Go d'Android Studio.
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

# ---------------------------------------------------------------------
# 0. Verifications preliminaires
# ---------------------------------------------------------------------
Dire "Verification de Java"

$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java) {
    Write-Host "    Java n'est pas installe." -ForegroundColor Red
    Write-Host "    Telechargez JDK 17 sur https://adoptium.net puis relancez ce script." -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}

$ancien = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$sortie = java -version 2>&1
$ErrorActionPreference = $ancien

$versionJava = ($sortie | Out-String).Trim() -split "`n" | Select-Object -First 1
Ok "Java detecte : $versionJava"

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
Write-Host "  Le SDK Android est pret. Vous pouvez maintenant compiler l'APK :" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "      cd android" -ForegroundColor White
Write-Host "      .\gradlew.bat assembleDebug" -ForegroundColor White
Write-Host ""
Write-Host "  Le premier build prend 5 a 10 minutes." -ForegroundColor Yellow
Write-Host "  L'APK sera dans : android\app\build\outputs\apk\debug\app-debug.apk" -ForegroundColor Yellow
Write-Host ""
Read-Host "Appuyez sur Entree pour terminer"
