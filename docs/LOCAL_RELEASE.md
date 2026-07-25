# Local store release

Run the release script from a Windows PC to build, publish, and archive one version:

```powershell
Copy-Item local-release/release.config.example.psd1 local-release/release.config.psd1
$env:MS_STORE_CLIENT_SECRET = "your Azure app client secret"
.\scripts\release.ps1 -KeepArtifacts
```

`local-release/` is Git-ignored. Do not put service-account JSON or client secrets in the repository.

## One-time setup

1. Install Flutter, Ruby with `fastlane` (`gem install fastlane`), Microsoft Store CLI (`winget install Microsoft.MSStoreCLI`), and [rclone](https://rclone.org/downloads/).
2. Configure Android release signing in `android/key.properties`; Google Play rejects bundles signed with the debug key.
3. In Google Play Console, grant a service account Release Manager access for `com.enke.cloudposai`. Save its JSON key outside the repository and set its path in the release config or `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
4. Create an Azure AD app/service principal authorized for the Microsoft Partner Center seller account. Put its tenant/client/seller IDs in the config (or the `MS_STORE_*` environment variables) and set `MS_STORE_CLIENT_SECRET` in the current shell.
5. Run `rclone config` and create an authenticated Google Drive remote named `gdrive`, or change `GoogleDrive.Remote` to your remote name.

Before release, increase both the semantic version and build number in `pubspec.yaml`, for example `version: 1.0.10+20`. Google Play requires every uploaded build number to be greater than its previous one.

## Options

```powershell
# Build/publish Android only, then upload its AAB to Drive
.\scripts\release.ps1 -SkipMicrosoftStore

# Build/publish Microsoft Store only, then upload the MSIX to Drive
.\scripts\release.ps1 -SkipGooglePlay

# Build and publish stores without a Drive upload
.\scripts\release.ps1 -SkipGoogleDrive
```

The script uses `fastlane supply` for Google Play and `msstore publish` for Microsoft Store. Store publication is live according to the selected Play track/release status and the Partner Center configuration; use an internal/beta track first for a new release workflow.
