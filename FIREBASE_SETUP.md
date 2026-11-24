# Marprom M Mobilnost — Firebase Hosting & Google Sign-In Setup Guide

This workspace is pre-configured for **Firebase Hosting** (`build/web`), direct Android APK distribution at `/downloads/m-mobilnost.apk`, and **Firebase Auth with Google Account Sign-In** across Web, Android, and iOS.

## Prerequisites
1. Install **Node.js >= 20 LTS** ([nodejs.org](https://nodejs.org/en/download)) so `npx -y firebase-tools@latest` can run.
2. Sign in with Firebase CLI:
   ```powershell
   npx -y firebase-tools@latest login
   ```
3. Select an existing Firebase project or create a new one:
   ```powershell
   npx -y firebase-tools@latest projects:create marprom-m-mobilnost --display-name "Marprom M Mobilnost"
   npx -y firebase-tools@latest use marprom-m-mobilnost
   ```

## Enable Google Account Sign-In
1. Update `auth.providers.googleSignIn` in [firebase.json](firebase.json) if you want custom `authorizedRedirectUris` (e.g. `https://<PROJECT_ID>.firebaseapp.com/__/auth/handler` and `http://localhost`).
2. In Firebase Console (**Authentication > Settings > Authorized domains**), ensure `localhost` and your custom domain are listed (domain name only, no `https://` or port number).
3. For Android/iOS native builds, retrieve platform config files via CLI:
   ```powershell
   npx -y firebase-tools@latest apps:sdkconfig ANDROID <ANDROID_APP_ID> --project <PROJECT_ID> > android/app/google-services.json
   npx -y firebase-tools@latest apps:sdkconfig IOS <IOS_APP_ID> --project <PROJECT_ID> > ios/Runner/GoogleService-Info.plist
   ```

## Build & Deploy to Firebase Hosting
Run the included PowerShell script or execute step-by-step:
```powershell
flutter build apk --release
Copy-Item build\app\outputs\flutter-apk\app-release.apk web\downloads\m-mobilnost.apk -Force
flutter build web `
  --dart-define=FIREBASE_PROJECT_ID=<PROJECT_ID> `
  --dart-define=FIREBASE_API_KEY=<WEB_API_KEY> `
  --dart-define=FIREBASE_APP_ID=<WEB_APP_ID> `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<SENDER_ID> `
  --dart-define=FIREBASE_AUTH_DOMAIN=<PROJECT_ID>.firebaseapp.com
npx -y firebase-tools@latest deploy --only hosting,auth
```
