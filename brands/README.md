# Brands

Each folder here is one Windows build of the same app with its own name,
icon, installer and data folder. `cloudpos` is the default and is what you
get from a plain `flutter run` / `flutter build windows`.

Build one brand (app + installer):

```powershell
./scripts/build_brand.ps1 -Brand easyerp
```

The installer lands in `Output/<BRAND_INSTALLER_NAME>-<version>.exe`.
Release CI builds every brand listed in `.github/workflows/release.yml`.

## Adding a brand

1. Copy `brands/easyerp` to `brands/<id>` and edit `brand.json`.
   - `BRAND_APP_ID`: a **new** GUID (`[guid]::NewGuid()`). Never reuse one:
     the installer would replace the other brand's app.
   - `BRAND_PRODUCT_NAME`: names the data folder
     (`%APPDATA%\<BRAND_COMPANY>\<BRAND_PRODUCT_NAME>`). Must be unique.
   - Keep values ASCII; they are compiled into the Windows resource file.
2. Put the Windows icon at `brands/<id>/app_icon.ico` (16–256 px). Without
   one the build uses `windows/runner/resources/app_icon.ico`.
3. Put the in-app logo and icon under `assets/brands/<id>/` and add that
   folder to the `assets:` list in `pubspec.yaml`.
4. Add the brand to the `brand` matrix in `.github/workflows/release.yml`.

## Never change for `cloudpos`

`BRAND_APP_ID`, `BRAND_COMPANY`, `BRAND_PRODUCT_NAME` and `BRAND_EXE_NAME`
identify the existing installs. Changing them makes the next release install
as a second app with empty data instead of updating customers' tills.
