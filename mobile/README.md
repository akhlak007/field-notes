# Field Notes mobile app

Flutter client for the offline-first Field Notes service.

The easiest way to run the complete system is from the repository root:

```powershell
.\run.ps1
```

For an Android emulator, get its id from `flutter devices` and use `.\run.ps1 -Device emulator-5554` (replace the example id when needed). The launcher selects `http://10.0.2.2:8080` so the emulator can reach the host API. A physical phone requires `-ApiBaseUrl http://<your-computer-ip>:8080`. Desktop targets use `http://localhost:8080`.

To run the client manually:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

A release APK already uses `https://field-notes-3.onrender.com`. From the repo root:

```powershell
.\scripts\build-release-apk.ps1
```

Run checks with:

```bash
dart analyze lib test
flutter test
```
