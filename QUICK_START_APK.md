# 🚀 SmartCut - Quick Start APK Build Guide

## ✅ Credentials Ready

**Email:** `test@smartcut.app`  
**Password:** `password123`

(Auto-created in backend on first run)

---

## 📋 Pre-Build Checklist

- [x] Flutter SDK installed
- [x] Android SDK installed
- [x] Default user credentials set
- [x] API endpoints ready

---

## 🔧 Step 1: Run Backend

```bash
cd backend
python run.py
```

**Expected Output:**
```
✅ Default user created!
   Email: test@smartcut.app
   Password: password123
Application startup complete [uvicorn] Uvicorn running on http://0.0.0.0:5000
```

Keep this running in a terminal.

---

## 📱 Step 2: [OPTION A] Run on Physical Android Phone

**Requirements:**
- USB Cable
- Android phone with USB debugging enabled
- Phone connected via USB

**Commands:**
```bash
# Get dependencies
cd ..  # Go to project root
flutter pub get

# Run on connected device
flutter run

# Or run on specific device
flutter devices  # List devices first
flutter run -d <device-id>
```

The app will:
1. Build
2. Install on your phone
3. Launch automatically
4. Show login screen
5. Login with test@smartcut.app / password123

---

## 📦 Step 3: [OPTION B] Build APK for Distribution

```bash
cd ..  # Go to project root
flutter pub get

# Build Release APK (Optimized, ~30-50MB)
flutter build apk --release

# APK Location:
# build/app/outputs/flutter-apk/app-release.apk
```

**Install APK on phone:**
```bash
# Method 1: Via ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Method 2: Manual
# 1. Copy app-release.apk to phone via USB
# 2. Open file manager on phone
# 3. Tap the APK to install
```

---

## ⚙️ Important for Physical Phone

If your phone is NOT on the same network as PC, update API URL:

**File:** `lib/services/api_service.dart`

Change:
```dart
static String get baseUrl {
  if (kIsWeb) return 'http://localhost:5000';
  return defaultTargetPlatform == TargetPlatform.android 
      ? 'http://10.0.2.2:5000'  // For Android Emulator
      : 'http://localhost:5000';
}
```

To:
```dart
static String get baseUrl {
  // Replace YOUR_PC_IP with your actual PC IP (e.g., 192.168.x.x)
  return 'http://YOUR_PC_IP:5000';
}
```

**Find Your PC IP:**
- Windows: `ipconfig` → Look for IPv4 Address
- Mac/Linux: `ifconfig` → Look for inet

---

## 🧪 Testing Checklist

After login, test these features:

- [ ] **Video Editor**: Add video clip → should play
- [ ] **Photo Editor**: Add photo → should display
- [ ] **Mixed Editor**: Add both videos and photos
- [ ] **Collage Maker**: Create 2-9 photo collage
- [ ] **AI Features**: Check features list
- [ ] **Export**: Export sample project
- [ ] **Settings**: View settings screen

---

## 🐛 Troubleshooting

### "Connection refused" error
- **Solution**: Make sure backend is running with `python run.py`

### "Default user not created"
- **Solution**: Delete database file and restart backend
  ```bash
  rm -f app/smartcut.db  # Linux/Mac
  del app\smartcut.db    # Windows
  python run.py
  ```

### APK size too large
- **Solution**: Use `--split-per-abi` flag
  ```bash
  flutter build apk --release --split-per-abi
  ```
  Creates separate APKs for each CPU architecture (smaller download)

### App crashes on login
- **Solution**: 
  1. Check backend is running
  2. Verify API URL is correct
  3. Check internet connection
  4. Rebuild: `flutter clean && flutter pub get && flutter run`

---

## 📊 Build Output Info

**APK File Location:**
```
SmartCut-main/build/app/outputs/flutter-apk/app-release.apk
```

**APK Details:**
- Size: ~40-60MB (varies with assets)
- Architecture: ARM64 (all phones)
- Minimum SDK: Android 5.1+ (API 22)
- Target SDK: Android 14 (API 34)

---

## ✨ You're Ready!

1. **Backend running?** → Yes ✅
2. **Credentials set?** → Yes ✅
3. **Ready to build?** → Yes ✅

**Next:** Follow Step 2 or Step 3 above!

Questions? Check `AUTHENTICATION.md` for more details.

Good luck! 🎉
