# Windows and Microsoft Store release

This guide is for the MSIX version of CloudPOS submitted to Microsoft Store.

## Current local build status

- [x] Flutter Windows build completed.
- [x] MSIX package created:

  ```text
  build/windows/x64/runner/Release/cloudpos.msix
  ```

- [x] The package was signed with the repository's current local certificate.
- [!] Local signature trust verification reports that this certificate is self-signed and not trusted by Windows. This does not prevent a Microsoft Store submission; Microsoft signs Store-delivered packages after certification. Do not use this certificate as a long-term public code-signing secret.

## 1. Confirm the Store identity

In Partner Center, open the existing CloudPOS product and find **Product identity**. Its package identity must match the project configuration in `pubspec.yaml`:

```yaml
identity_name: enkeconsulting.CLOUDPOS-BillingApp
publisher: CN=DBDFAF94-3386-4A19-8AC8-1B8336E3BBFC
```

Do not submit an update until these values match the existing Store listing. A different identity is treated as a different application, not an update.

## 2. Version every Store update

Microsoft Store requires every new MSIX version to be greater than the package version already published in Partner Center.

MSIX uses four numeric parts:

```text
major.minor.build.revision
```

Before a Store submission, update both version values in `pubspec.yaml`, for example:

```yaml
version: 1.0.10+20
msix_version: 1.0.10.20
```

Do not reuse an MSIX version that has already been uploaded to the Store.

## 3. Prepare Microsoft Store API access

The automated release script uses Microsoft Store Developer CLI (`msstore`). Create an Entra application/service principal that is authorized for the Partner Center seller account, then collect:

- Tenant ID
- Seller ID
- Client ID
- Client secret

Keep the secret out of Git. In PowerShell, set it only for the active session:

```powershell
$env:MS_STORE_CLIENT_SECRET = "your-client-secret"
```

Install the required tools:

```powershell
winget install Microsoft.DotNet.DesktopRuntime.9
winget install "Microsoft Store Developer CLI"
```

Configure and validate the account:

```powershell
msstore reconfigure `
  --tenantId "YOUR-TENANT-ID" `
  --sellerId "YOUR-SELLER-ID" `
  --clientId "YOUR-CLIENT-ID" `
  --clientSecret $env:MS_STORE_CLIENT_SECRET

msstore apps list
```

`msstore apps list` should show the existing CloudPOS Store app before you attempt an upload.

## 4. Configure the local release script

Copy the local configuration template if it does not already exist:

```powershell
Copy-Item local-release/release.config.example.psd1 local-release/release.config.psd1
```

Set the non-secret Microsoft values:

```powershell
MicrosoftStore = @{
  TenantId = "YOUR-TENANT-ID"
  ClientId = "YOUR-CLIENT-ID"
  SellerId = "YOUR-SELLER-ID"
}
```

The `local-release/` directory is Git-ignored.

## 5. Run a Store release

After the script is updated to the current `msstore` syntax and the Store identity/version checks pass, run:

```powershell
.\scripts\release.ps1 -SkipGooglePlay -KeepArtifacts
```

This builds the Windows app, creates an MSIX package, submits it to Microsoft Store, and uploads the package to Google Drive. To skip the Drive copy:

```powershell
.\scripts\release.ps1 -SkipGooglePlay -SkipGoogleDrive -KeepArtifacts
```

## 6. Certification and release

An automated submission is not immediately public. Microsoft Store validates and certifies the package. Check the submission status in Partner Center, test the Store-delivered version when available, then release according to your configured Store availability/rollout settings.

## Manual local MSIX build

The following builds and packages the app locally without publishing it:

```powershell
.\build-msix.ps1
```

If the packaging step says NuGet is missing, install it once:

```powershell
winget install Microsoft.NuGet
```

For the full combined Play Store, Microsoft Store, and Google Drive workflow, see [LOCAL_RELEASE.md](LOCAL_RELEASE.md).
