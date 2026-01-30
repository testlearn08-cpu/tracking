# FocusFlow (Flutter + Firebase) — Codespaces Setup

FocusFlow is an Android-first focus timer app with:
- Google Sign-In
- Focus session timer (25/50/90), breaks, feedback
- Daily stats + streak tracking (Firestore transaction)
- Reports + export (CSV/PDF)
- Android home widget (quick start preset) + deep links
- Local notifications
- Battery optimization help screen

---

## Tech Stack
- Flutter (Android-first)
- Firebase Auth (Google Sign-In)
- Cloud Firestore
- Android widget (Kotlin + XML)
- flutter_local_notifications + timezone
- home_widget
- Export: csv + pdf + share_plus

---

## Requirements (in GitHub Codespaces)
You do NOT install anything on your laptop. All setup happens inside Codespaces.

You will need:
- A Firebase project (free tier is enough)
- An Android device (recommended) for testing widget + deep links
  - OR build an APK and install it on your phone

---

## 1) Open in Codespaces
1. Push this repo to GitHub
2. Click **Code → Codespaces → Create codespace**

---

## 2) Install Flutter inside Codespaces (one-time per codespace)
In the Codespaces terminal:

```bash
sudo apt-get update
sudo apt-get install -y unzip xz-utils git curl

# Download Flutter (stable)
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

flutter --version
flutter doctor
