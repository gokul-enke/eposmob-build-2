# CloudPOS AI — iOS release handoff

## Build identity

- App name: CloudPOS AI
- Version: 1.0.31
- Build number: 42
- Bundle ID candidate: `com.enke.cloudpos`
- Minimum iOS version: 13.0
- Production API: `https://eeezeeerp.cloudposai.com`
- Signing: Automatic; no developer team is committed to the repository

The bundle ID is permanent after the first App Store upload. Confirm that
`com.enke.cloudpos` belongs to the organization before creating the app record.

## Work remaining after Apple approves the organization

1. In Xcode, sign in with the approved organization Apple ID.
2. Open `ios/Runner.xcworkspace`, select Runner > Signing & Capabilities, choose
   the organization team, and confirm the bundle ID.
3. Create the CloudPOS AI app in App Store Connect with that same bundle ID.
4. Add the required URLs and store listing content below.
5. Create a signed archive, validate it, and upload it to App Store Connect.
6. Add internal TestFlight testers and complete the smoke-test checklist.
7. Complete export compliance, content rights, age rating, app privacy, and the
   review contact/demo-account sections before submitting for review.

Do not install or replace certificates manually unless automatic signing asks
for help. Choosing the correct team lets Xcode keep this app's signing separate
from other developers who use the Mac.

## Store listing content to supply

- Subtitle (maximum 30 characters)
- Description
- Keywords (maximum 100 characters total)
- Support URL
- Privacy policy URL (required)
- Marketing URL (optional)
- Copyright holder and year
- App category
- App Review contact name, phone, and email
- A stable review/demo account and review notes explaining printer/location use
- Screenshots: 1–10 for the 6.9-inch iPhone display class; add iPad screenshots
  if the app is offered on iPad

Screenshots should demonstrate login/store selection, product browsing, cart,
checkout/payment, order history, and printer setup. Do not include real customer
or payment data.

## App privacy draft

The included privacy manifest conservatively declares that the following data
may be linked to a user and used for app functionality, with no tracking:

- Name, email address, phone number, and physical address
- Precise location
- Payment information and other financial information
- User ID and purchase history
- Photos or videos selected for products/categories

Before submission, the business owner or backend owner must verify this list
against actual server retention and every third-party service. App Store Connect
answers must match actual behavior, including data collected by dependencies.

## TestFlight smoke test

- Fresh install, login, logout, forgotten-password flow, and store selection
- Product/category browsing, search, variants, stock limits, taxes, and discounts
- Add/edit/remove cart lines; save, restore, and delete held orders
- Complete cash and supported non-cash sales; verify totals and server sync
- Order history, returns/refunds, and offline/reconnect behavior where supported
- Select/upload an image; verify denied photo/location/Bluetooth permission paths
- Discover and print to each supported Bluetooth and network printer
- Rotate supported screens; test current iPhone and iPad layouts if iPad remains enabled
- Verify no test credentials, private customer data, or staging endpoints are present
- Check crash reports and key backend operations before promoting the build

## Release command

Run the release with the production endpoint and automatic signing enabled:

```sh
flutter build ipa --release \
  --dart-define=BASE_URL=https://eeezeeerp.cloudposai.com
```

Increase the build number for every new upload. Increase the version when the
public release version changes.
