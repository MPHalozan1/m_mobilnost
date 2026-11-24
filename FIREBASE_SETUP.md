# Marprom M Mobilnost — Firebase Hosting, Firestore & Auth Setup Guide

This workspace is pre-configured for **Firebase Hosting** (`build/web`) on Spark Plan, external Android APK distribution via GitHub Releases (`https://github.com/MPHalozan1/m_mobilnost/releases/download/v2.0/m-mobilnost.apk`), **Cloud Firestore**, and **Firebase Auth (Email/Password + Google Sign-In)** across Web and Android on project **`m-mobilnost-2`**.

## Prerequisites
1. Install **Node.js >= 20 LTS** ([nodejs.org](https://nodejs.org/en/download)) so `npx -y firebase-tools@latest` can run.
2. Sign in with Firebase CLI:
   ```powershell
   npx -y firebase-tools@latest login
   npx -y firebase-tools@latest use m-mobilnost-2
   ```

## Enable Cloud Firestore & Google Account Sign-In
1. In Firebase Console (`m-mobilnost-2`), ensure **Cloud Firestore** `(default)` Standard database is created in `eur3` (Europe).
2. In Firebase Console (**Authentication > Settings > Authorized domains**), ensure `localhost`, `m-mobilnost-2.web.app`, and `m-mobilnost-2.firebaseapp.com` are listed (domain name only, no `https://` or port number).
3. Android config is stored in `android/app/google-services.json`, and Web/Android options are pre-populated in `lib/core/firebase/firebase_options.dart`.

## Build & Deploy to Firebase Hosting (Spark Plan Safe)
Do **NOT** place `.apk`, `.exe`, `.ipa`, `.dll`, or `.bat` files inside `web/` or `build/web/`.
```powershell
flutter build web --release
npx -y firebase-tools@latest deploy --only hosting,auth,firestore:rules --project m-mobilnost-2
```
