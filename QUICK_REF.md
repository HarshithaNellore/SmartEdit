# 📱 SmartCut Mobile - Quick Reference Card

## 🔐 Login Credentials
```
📧 test@smartcut.app
🔑 password123
```
**NO BACKEND NEEDED** - Works offline! ✅

---

## 🚀 Build & Deploy (Copy-Paste Ready)

### Terminal 1: Build APK
```bash
cd C:\Users\soumya\Downloads\SmartCut-main
flutter clean
flutter pub get
flutter build apk --release
```

### Terminal 2: Install on Phone
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Or manually:** Transfer `build/app/outputs/flutter-apk/app-release.apk` to phone & tap to install

---

## ✅ Verify Setup

- [ ] See "🔓 Demo Mode" banner on login screen?
- [ ] Login works with credentials above?
- [ ] All features accessible after login?
- [ ] Can edit videos/photos/create collages?

---

## 📚 Read These Files

| File | Purpose |
|------|---------|
| **DEPLOY_MOBILE.md** | Complete deployment guide |
| **DEMO_MODE.md** | Detailed demo mode info |
| **QUICK_START_APK.md** | APK building steps |

---

## 🔄 Switch to Real Backend Later

1. Edit `lib/services/auth_service.dart` Line 5:
   ```dart
   static const DEMO_MODE = false;  // Disable demo
   ```

2. Start backend:
   ```bash
   cd backend && python run.py
   ```

3. Rebuild APK:
   ```bash
   flutter clean && flutter pub get && flutter build apk --release
   ```

---

## 🎯 Status

- ✅ Demo mode enabled
- ✅ Offline credentials ready
- ✅ APK buildable
- ✅ Ready for mobile testing

**You're good to go!** 🚀
