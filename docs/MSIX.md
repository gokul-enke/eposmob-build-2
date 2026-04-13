# MSIX Build Guide

## Quick Steps for a New Update Build

### 1. Bump the Version

Open `pubspec.yaml` and update **both** version fields:

```yaml
# App version (format: major.minor.patch+build)
version: 1.0.2+1

# MSIX version (format: major.minor.patch.revision) — must go UP from previous
msix_config:
  msix_version: 1.0.2.0
```

**Versioning rules:**
- Bug fix → increment patch: `1.0.1` → `1.0.2`
- New feature → increment minor: `1.0.2` → `1.1.0`
- Breaking change → increment major: `1.1.0` → `2.0.0`
- `msix_version` must **always increase** from the previous submission
- Reset build number (`+1`) when you change the version

### 2. Run the Build

```powershell
.\build-msix.ps1
```

This runs all 7 steps automatically:
1. `flutter clean`
2. `flutter pub get`
3. `flutter build windows --release`
4. Copies VC++ DLLs from `dependencies/`
5. Prepares MSIX build directory
6. Creates MSIX package via `dart run msix:create`
7. Signs with `certificate.pfx`

**Custom base URL:**
```powershell
.\build-msix.ps1 -BaseUrl "https://eposdemo.yougoit.in" -OutputName "cloudpos-demo"
```

### 3. Output

The signed MSIX will be at:
```
build\windows\runner\Release\cloudpos.msix
```

---

## Sharing the MSIX (Sideloading)

Send **2 files** to the user:
- `cloudpos.msix`
- `cloudpos.cer` (public certificate, no password needed)

**Recipient steps:**
1. Right-click `cloudpos.cer` → **Install Certificate**
2. Select **Local Machine** → Next
3. **Place all certificates in the following store** → Browse → **Trusted Root Certification Authorities** → OK → Finish
4. Double-click `cloudpos.msix` → Install

> Certificate install is a one-time step. Updates only need the new `.msix`.

To export the `.cer` from the `.pfx`:
```powershell
$cert = Get-PfxCertificate -FilePath "certificate.pfx"
# Enter password: 1234
[System.IO.File]::WriteAllBytes(
  "build\windows\runner\Release\cloudpos.cer",
  $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
)
```

---

## Microsoft Store Submission

- The Store **re-signs** your package — the self-signed cert is only for sideloading
- Add this to the **first two lines** of the Store description:
  > Requires Microsoft Visual C++ 2015-2022 Redistributable (x64). The app will prompt you to download it if not installed.
- `msix_version` must be **higher** than the previously submitted version

---

## Key Files

| File | Purpose |
|---|---|
| `pubspec.yaml` | Version numbers + `msix_config` settings |
| `build-msix.ps1` | Automated build script (7 steps) |
| `certificate.pfx` | Signing certificate (password: `1234`) |
| `dependencies/*.dll` | VC++ runtime DLLs bundled with the app |
| `windows/runner/main.cpp` | VC++ runtime check at startup |

## Certificate Info

- **Subject:** `CN=DBDFAF94-3386-4A19-8AC8-1B8336E3BBFC`
- **Expires:** April 8, 2027
- **Type:** Self-signed
- **Password:** `1234`

---

## Troubleshooting

| Error | Fix |
|---|---|
| `msix:create failed` / package not found | Run `flutter pub get` — ensure `msix: ^3.7.0` is in `dev_dependencies` |
| `0x800B010A` certificate error on install | Install `cloudpos.cer` to Trusted Root (see Sharing section) |
| `SignerSign() failed` during build | The build script handles this — it signs with `signtool /fd SHA256` |
| VC++ DLLs missing in MSIX | The build script copies `dependencies/*.dll` to both build dirs |
| Store rejects: undisclosed software | Add VC++ dependency note to first 2 lines of Store description |
| Store rejects: version not higher | Bump `msix_version` in `pubspec.yaml` higher than last submission |
