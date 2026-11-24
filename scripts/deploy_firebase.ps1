param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectId = "m-mobilnost-2",
    [Parameter(Mandatory = $false)]
    [string]$FirebaseApiKey = "",
    [Parameter(Mandatory = $false)]
    [string]$FirebaseAppId = "",
    [Parameter(Mandatory = $false)]
    [string]$FirebaseSenderId = "",
    [Parameter(Mandatory = $false)]
    [string]$FirebaseAuthDomain = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==> Checking Node.js & Firebase CLI..."
node --version
npx -y firebase-tools@latest --version

if ($ProjectId -ne "") {
    Write-Host "==> Selecting Firebase project: $ProjectId"
    npx -y firebase-tools@latest use $ProjectId
}

Write-Host "==> Verifying Spark-plan binary cleanliness (no .apk/.exe/.dll/.bat in web/ or assets/)..."
$forbidden = Get-ChildItem -Path "web", "assets" -Recurse -Include *.apk, *.exe, *.ipa, *.dll, *.bat -ErrorAction SilentlyContinue
if ($forbidden) {
    throw "Forbidden binaries found in web/ or assets/: $($forbidden.FullName -join ', '). Android APK is hosted via GitHub Releases v2.0."
}

$dartDefines = @()
if ($ProjectId -ne "") { $dartDefines += "--dart-define=FIREBASE_PROJECT_ID=$ProjectId" }
if ($FirebaseApiKey -ne "") { $dartDefines += "--dart-define=FIREBASE_API_KEY=$FirebaseApiKey" }
if ($FirebaseAppId -ne "") { $dartDefines += "--dart-define=FIREBASE_APP_ID=$FirebaseAppId" }
if ($FirebaseSenderId -ne "") { $dartDefines += "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$FirebaseSenderId" }
if ($FirebaseAuthDomain -ne "") { $dartDefines += "--dart-define=FIREBASE_AUTH_DOMAIN=$FirebaseAuthDomain" }

Write-Host "==> Building Flutter Web bundle into build/web..."
flutter build web --release @dartDefines

Write-Host "==> Deploying Firebase Hosting, Auth & Firestore Rules..."
npx -y firebase-tools@latest deploy --only hosting,auth,firestore:rules --project $ProjectId
Write-Host "==> Done!"
