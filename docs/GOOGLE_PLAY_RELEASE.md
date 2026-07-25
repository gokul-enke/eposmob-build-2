# Google Play release checklist

App package name: `com.enke.cloudposai`

## Completed

- [x] **Play Console setup** — App created, required Play Console information completed, and Play App Signing enabled.
- [x] **Local Android signing** — Upload keystore created and `android/key.properties` configured. Keep the keystore and this properties file private; neither belongs in Git.

## 3. Enable automated Play API access

The local release script uploads an Android App Bundle through Fastlane and the Google Play Developer Publishing API.

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Select or create a Cloud project dedicated to this app.
3. Go to **APIs & Services → Library**, search for **Google Play Android Developer API**, and enable it.
4. Go to **IAM & Admin → Service Accounts** and create a service account, for example `cloudpos-play-release`.
5. Create a JSON key for that service account and save it somewhere private, for example:

   ```text
   C:\secure\cloudpos-google-play.json
   ```

6. In Play Console, open the developer-account API access/users area and give this service account access to `com.enke.cloudposai`. It needs permission to upload releases to the target track; use the least privileges that allow the release workflow.

Never commit the JSON key or place it under this project folder.

## 4. Configure this computer

Install the local tools once:

```powershell
gem install fastlane
```

Flutter must already be installed and available on `PATH`.

Create your ignored local configuration file:

```powershell
Copy-Item local-release/release.config.example.psd1 local-release/release.config.psd1
```

Edit `local-release/release.config.psd1` for an initial internal test:

```powershell
GooglePlay = @{
  PackageName        = "com.enke.cloudposai"
  Track              = "internal"
  ReleaseStatus      = "completed"
  ServiceAccountJson = "C:\secure\cloudpos-google-play.json"
}
```

`local-release/` is ignored by Git, so this machine-specific configuration is not committed.

## 5. Prepare each release

Increase the version and build number in `pubspec.yaml` before every upload. The build number after `+` becomes Android's `versionCode` and must always increase.

```yaml
# Example: current version 1.0.9+19
version: 1.0.10+20
```

Keep your local `.env` file available if the app build needs its Google Maps key.

## 6. First automated upload: internal testing

Run the Android/Drive part of the release workflow:

```powershell
.\scripts\release.ps1 -SkipMicrosoftStore -KeepArtifacts
```

This creates a signed `.aab`, uploads it to the Play **internal** track, copies it to Google Drive, and keeps a local copy in `local-release/output/`.

In Play Console, confirm that the new release appears under **Testing → Internal testing**, add testers if necessary, and install it on a test device.

## 7. Production release

After internal testing succeeds, change the config to:

```powershell
Track = "production"
ReleaseStatus = "completed"
```

Then run the same command again with a **new, higher build number**. A production release with `completed` becomes available according to your Play Console rollout settings. Use a staged rollout in Play Console for safer deployment when appropriate.

## Useful commands

```powershell
# Android only; no Drive upload
.\scripts\release.ps1 -SkipMicrosoftStore -SkipGoogleDrive

# Keep generated AAB files after a successful run
.\scripts\release.ps1 -SkipMicrosoftStore -KeepArtifacts
```

For the full three-destination workflow (Play Store, Microsoft Store, and Drive), see [LOCAL_RELEASE.md](LOCAL_RELEASE.md).
