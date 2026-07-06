# Future Improvements & Known Issues
**Project**: eposmob (CloudPOS)  
**Related Task**: Task 291 - Customer Location Map Picker  
**Last Updated**: 2026-07-06  
**Author**: Mubashir  

---

## 1. API Key Security (flutter_dotenv Limitation)

### Current Approach
* The API key is stored in a `.env` file loaded dynamically via `flutter_dotenv`.
* The `.env` file is gitignored so the key is never committed to GitHub.
* The key is injected into the WebView HTML page at runtime using dynamic string replacement (`GOOGLE_MAPS_API_KEY_PLACEHOLDER` $\rightarrow$ `apiKey`) right before the WebView widget is mounted.

### Known Limitation
* The `flutter_dotenv` package bundles the `.env` file as a plain asset inside the compiled application binary (both the Android APK and the Windows MSIX installer).
* Anyone who decompiles the APK (using standard tools like apktool) or extracts the MSIX installer file can read the `.env` asset directly in plain text to retrieve the API key.
* The `.env` approach successfully protects the key from source control (VCS/GitHub) but does **NOT** secure it against client-side binary extraction. This is a standard limitation of environment bundles in native client-side architectures.

### Risk Level
* **Medium** — Google Maps API keys are semi-public by design (since they appear in standard client-side HTTP network requests). The true defense-in-depth security layer comes from API restrictions configured on the Google Cloud Console, rather than obfuscating the key within the client bundle.

### Recommended Future Fix
1. **Configure Strict API Restrictions (Google Cloud Console)**:
   * **Android apps**: Restrict the key to request matches from the specific Android Package Name and SHA-1 certificate fingerprint of the production-signed APK.
   * **Windows apps**: Restrict key usage to specific static IP ranges if possible.
   * **API Scope Restrictions**: Keep the key restricted strictly to the *Maps JavaScript API*, *Places API*, and *Geocoding API* profiles. (Already implemented ✅).
2. **Backend Proxy Layer**:
   * Instead of loading Google maps directly via client API keys, route geocoding and autocomplete requests through the store's own secure backend proxy endpoints.
   * The server-side proxy securely stores the private Google Maps API key, processes requests, and returns structured payloads to the app. The client binary never interacts with raw keys.
3. **CI/CD Injections**:
   * For automated pipeline builds (GitHub Actions), pass the key via `--dart-define=GOOGLE_MAPS_API_KEY=${{ secrets.GOOGLE_MAPS_KEY }}` instead of generating a `.env` file.

---

## 2. Linux Platform — No Map Picker

### Current State
* The Linux desktop build compiles without the "Pick on Map" feature because native WebView packages under Linux have unstable Flutter support.
* Currently, there is no platform guard surrounding the layout button in `custom_customer_form.dart`. The "Pick on Map" button is visible on Linux, which may cause unhandled layout exceptions or crashes if clicked.

### Risk Level
* **High** (for Linux users) — Tapping the trigger button on Linux builds will fail since the platform-specific WebView controllers are left uninitialized.

### Recommended Future Fix
* **Option A (Quick Fix)**: Hide the button dynamically on Linux targets using a simple platform check:
  ```dart
  if (!Platform.isLinux)
    TextButton.icon(
      icon: const Icon(Icons.location_pin),
      label: const Text("Pick on Map"),
      onPressed: _openLocationPicker,
    )
  ```
* **Option B (Intermediate - Recommended)**: Implement a search-only fallback for Linux:
  * On Linux, tapping the button displays a search-only dialog using a standard text field wired directly to the Google Places Rest API via the `http` package (bypassing the HTML WebView entirely).
  * Auto-fills identical geocoding details without rendering the visual map canvas.
* **Option C (Complex)**: Add `webview_cef` integration on Linux to render the embedded Chromium browser engine. (Lacks long-term stability guarantees and increases binary size significantly).

*Recommendation: Implement Option B.*

---

## 3. State/District/Pincode — Free Text Fallback

### Current State
* State, District, and Pincode dropdown fields are backed by strict local database entries synced from country-specific store data (e.g. a Saudi store has Saudi states).
* If the geocoded address returns a State or District name not present in the backend master tables, the dropdown selection remains empty, and the cashier is forced to select from the options manually.

### Recommended Future Fix
* When fuzzy matching fails for dropdown properties, dynamically toggle the widget from a dropdown to a standard free-text field pre-filled with Google's geocoded name value.
* This requires coordination with backend developer Shabab to ensure the customer creation endpoint accepts raw string values for State, District, and Pincode in place of integer database IDs.

---

## 4. Backend Storage of Location Data

### Current State
* The Location result payload captures extensive metadata: `latitude`, `longitude`, `place_id`, `landmark`, `formatted_address`, `country`, `state`, `city`, and `pincode`.
* Currently, only standard address lines are sent to the server. Parameters like `latitude`, `longitude`, `place_id`, and `landmark` are ignored by the serialization model and not stored on the database.

### Recommended Future Fix
* Request backend updates to store:
  * `latitude` (Float)
  * `longitude` (Float)
  * `place_id` (String)
  * `landmark` (String)
* Update `CustomerProvider.addCustomer()` to submit these details from `LocationResult`.
* This unlocks future features such as delivery route optimization, cashier distance checks, and map plotting in the admin dashboard.

---

## 5. stateSearchController Not Updated After Map Auto-fill

### Current State
* After `_autoFillFromLocation()` fuzzy-matches a state, `selectedStateId` is updated and the dropdown refreshes. However, the text search controllers (`stateSearchController` and `districtSearchController`) are not populated with the matched text names, leaving the dropdown search inputs blank or stale.

### Recommended Future Fix
* Force controller text values to update upon state/district matches inside `_autoFillFromLocation()`:
  ```dart
  setState(() {
    stateSearchController.text = matchedState.value;
    districtSearchController.text = matchedDistrict.value;
  });
  ```

---

## 6. GPS Timeout on Fixed Windows Tills

### Current State
* The geolocator queries the device GPS with a 5-second timeout window.
* Desktop POS registers (fixed tills) rarely feature GPS hardware. The 5-second wait before defaulting to a world map zoom is slow and impacts cashier speed.

### Recommended Future Fix
* Reduce the timeout to 2 seconds.
* Check the platform: bypass GPS lookups on Windows desktop builds entirely, opening the map directly centered on the store's configured coordinate profile or a standard world map view.

---
*These improvements are non-blocking for the current release. Core feature (Task 291) is complete and working on Windows and Android. Items above are recommended for future sprints based on code review and testing findings.*
