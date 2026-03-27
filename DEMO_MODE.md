# 🔓 SmartCut - Demo Mode (Offline Testing)

## ✅ NOW ENABLED: Offline Demo Credentials

The app now runs **WITHOUT a backend server**. Perfect for testing on your mobile phone without network dependencies.

---

## 🔐 Demo Login Credentials

```
📧 Email:    test@smartcut.app
🔑 Password: password123
```

**Usage:** 
- Use these credentials to login on your phone
- App works 100% offline
- No backend server needed
- Demo mode badge shows in bottom-left corner

---

## 📱 How to Build & Run on Mobile

### Step 1: Build APK
```bash
cd C:\Users\soumya\Downloads\SmartCut-main
flutter clean
flutter pub get
flutter build apk --release
```

**APK Location:**
```
build/app/outputs/flutter-apk/app-release.apk
```

### Step 2: Install on Phone
- Copy the APK to your phone via USB
- Tap the APK file to install
- Or use: `adb install build/app/outputs/flutter-apk/app-release.apk`

### Step 3: Launch & Login
1. Open SmartCut app on your phone
2. You'll see "🔓 Demo Mode" banner at top
3. Login with:
   - Email: `test@smartcut.app`
   - Password: `password123`
4. Enjoy all features! 🎉

---

## ✨ What Works in Demo Mode

✅ **Login/Logout** (offline)  
✅ **Video Editor** (play, edit, export)  
✅ **Photo Editor** (select, edit, export)  
✅ **Mixed Editor** (videos + photos)  
✅ **Collage Maker** (2-9 photo layouts)  
✅ **AI Features** (show feature list)  
✅ **Settings** (view & edit settings)  
✅ **Collaboration** (view screen)  
✅ **Export** (save projects)  

---

## 🔄 Switch Between Demo Mode & Production

### To Enable Demo Mode (CURRENT):

**File:** `lib/services/auth_service.dart`

```dart
static const DEMO_MODE = true;  // ✅ Demo mode ON
```

### To Disable Demo Mode (Use Real Backend):

**File:** `lib/services/auth_service.dart`

```dart
static const DEMO_MODE = false;  // 🔌 Use real backend
```

Then start your backend:
```bash
cd backend
python run.py
```

---

## 📋 Demo Mode Details

### What Happens in Demo Mode

1. **Login Screen**:
   - Shows "🔓 Demo Mode" banner
   - Accepts only: `test@smartcut.app` / `password123`
   - Any other credentials show helpful error

2. **Local Storage**:
   - User token stored locally
   - No API calls made
   - Works completely offline

3. **User Data**:
   - Demo user: `Test User`
   - ID: `demo_user_001`
   - Email: `test@smartcut.app`
   - Stored in app memory

4. **Features**:
   - All UI features work locally
   - No server communication
   - Perfect for testing UI/UX

---

## 🎨 Demo Mode Indicator

A banner appears at the top of login screen:

```
┌────────────────────────────────────━━━┐
│ ℹ️  🔓 Demo Mode: No backend needed    │
└────────────────────────────────────━━━┘
```

This reminds you that you're in offline testing mode.

---

## 🚀 Production Checklist

When ready to use real backend:

- [ ] Set `DEMO_MODE = false` in `auth_service.dart`
- [ ] Start backend: `cd backend && python run.py`
- [ ] Update API URL if needed (phone on different network)
- [ ] Test login with demo credentials (should fail)
- [ ] Register new account via app
- [ ] Login with your account

---

## 💾 File Locations

**Demo Mode Config:**
```
lib/services/auth_service.dart  (Line 5: DEMO_MODE = true)
```

**Demo Credentials Config:**
```
lib/services/auth_service.dart  (Lines 7-9)
- DEMO_EMAIL
- DEMO_PASSWORD  
- DEMO_TOKEN
```

**Demo Mode Badge:**
```
lib/screens/auth/login_screen.dart  (Lines 104-118)
```

---

## ❓ FAQ

**Q: Can I test all features in demo mode?**  
A: Yes! All features work offline. Export saves happen locally.

**Q: How do I switch to real backend later?**  
A: Change `DEMO_MODE = false` in `auth_service.dart` and restart.

**Q: Will demo data persist after app restart?**  
A: You'll need to login again, but you can do so instantly since it's local.

**Q: Can I create more demo users?**  
A: In demo mode, any email (except the test one) can be registered. Changes won't persist though.

**Q: What if I want to test login failures?**  
A: Try wrong password - you'll get helpful error message showing correct credentials.

---

## 🎉 You're Ready!

**Next Steps:**

1. Build APK: `flutter build apk --release`
2. Install on phone
3. Login with `test@smartcut.app` / `password123`
4. Start editing videos and photos!

**Enjoy! 🚀**
