# 🔐 SmartCut - Login Credentials

## Default Test Account

Created automatically on backend startup.

### Credentials
```
Email:    test@smartcut.app
Password: password123
```

### How to Use

1. **Run Backend**:
   ```bash
   cd backend
   python run.py
   ```
   The backend will auto-create the default user on first run.

2. **Run Mobile App (Android)**:
   ```bash
   flutter run -d <device-id>
   # Or for APK build:
   flutter build apk --release
   ```

3. **Login in App**:
   - Email: `test@smartcut.app`
   - Password: `password123`

4. **Features Now Ready**:
   - ✅ Video Editor with playback
   - ✅ Photo Editor
   - ✅ Mixed Editor
   - ✅ Collage Maker
   - ✅ AI Features
   - ✅ Collaboration (coming soon)
   - ✅ Export

---

## Building APK for Android Mobile

### Prerequisites
- Flutter SDK installed
- Android SDK / Android Studio
- Physical device or emulator

### Build Steps

```bash
# Get dependencies
flutter pub get

# Build APK (Release mode - optimized)
flutter build apk --release

# Build APK (Debug mode - for testing)
flutter build apk

# APK location
# build/app/outputs/flutter-apk/app-release.apk
```

### Install on Phone
```bash
# Via USB or emulator
adb install build/app/outputs/flutter-apk/app-release.apk

# Or drag & drop the APK to your device
```

### Running on Phone
1. Plug in Android device (enable USB debugging)
2. Run: `flutter run`
3. App will install and launch automatically

---

## Notes

- Backend must be running for authentication
- Update `API_URL` in Flutter app if backend IP changes
- Default user is created once and persists in database
- You can create additional users through sign-up

---

**Built with Flutter + FastAPI + PostgreSQL**
