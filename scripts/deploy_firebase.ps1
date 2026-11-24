param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectId = "",
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

Write-Host "==> Building Android release APK..."
flutter build apk --release
New-Item -ItemType Directory -Force -Path "web\downloads" | Out-Null
Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "web\downloads\m-mobilnost.apk" -Force

$dartDefines = @()
if ($ProjectId -ne "") { $dartDefines += "--dart-define=FIREBASE_PROJECT_ID=$ProjectId" }
if ($FirebaseApiKey -ne "") { $dartDefines += "--dart-define=FIREBASE_API_KEY=$FirebaseApiKey" }
if ($FirebaseAppId -ne "") { $dartDefines += "--dart-define=FIREBASE_APP_ID=$FirebaseAppId" }
if ($FirebaseSenderId -ne "") { $dartDefines += "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$FirebaseSenderId" }
if ($FirebaseAuthDomain -ne "") { $dartDefines += "--dart-define=FIREBASE_AUTH_DOMAIN=$FirebaseAuthDomain" }

Write-Host "==> Building Flutter Web bundle into build/web..."
flutter build web @dartDefines

Write-Host "==> Deploying Firebase Auth configuration + Firebase Hosting..."
npx -y firebase-tools@latest deploy --only hosting,auth
Write-Host "==> Done!"
