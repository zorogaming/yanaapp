# flutter_snapmint_sdk

Snapmint Flutter SDK for integrating Snapmint checkout and EMI eligibility button in your Flutter apps (Android, iOS, Web, Desktop).

## Overview

To enable Snapmint checkout from your app, integrate in two steps:

1. Server-to-Server Integration
   - Your backend calls Snapmint Cart API to generate a one-time checkout URL.
   - Return the checkout URL to your app.

2. Client-side SDK Integration (Flutter)
   - Use the checkout URL with the Flutter SDK to launch the payment flow.
   - Handle success or failure status returned to your app.

## Prerequisites

- Flutter 3.24.3+
- Android minSdk 21+, compileSdk 34
- iOS 15.0+
- Dart 3.5.0+
- A Snapmint merchant account and credentials

## Installation

- **Add dependency**

```bash
flutter pub add flutter_snapmint_sdk
```

Or add manually in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_snapmint_sdk: ^latest
```

- **Add assets (already bundled by the plugin)**
No action needed. The plugin ships its own assets and registers the platforms.

## Platform setup

- **Android**: No additional configuration required beyond the default Flutter setup.
- Add internet permission if not already present in your host app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```
- **iOS**:
  - Requires iOS 15.0+.
  - Uses CocoaPod `SnapmintMerchantSdk` under the hood. Run `cd ios && pod install` after adding the dependency.

## Usage

Import the package public API:

```dart
import 'package:flutter_snapmint_sdk/flutter_snapmint_sdk.dart';
```

### 1) Launch Snapmint Checkout

Use `RNSnapmintCheckout.openSnapmintMerchant(checkoutUrl, options: ...)` with a full checkout URL you receive from your backend.

```dart
// Controls the text field where the user/developer enters or pastes the checkout URL.
// It lets you read the current value via `controller.text` and listen for changes.
final TextEditingController checkoutUrlController = TextEditingController();

Future<void> openSnapMintModule() async {
  final checkoutUrl = checkoutUrlController.text.trim();
  if (checkoutUrl.isEmpty) {
    // handle invalid input in UI
    return;
  }

  try {
    final result = await RNSnapmintCheckout.openSnapmintMerchant(
      checkoutUrl,
      options: PaymentOptions(
        onSuccess: (r) {
          // r.status, r.statusCode, r.responseMsg, r.paymentId, r.timestamp
        },
        onError: (e) {
          // e.status, e.statusCode, e.responseMsg/message, e.timestamp
        },
      ),
    );
    // Optionally use the resolved result here as well
  } catch (e) {
    // Handle thrown PaymentError or other exceptions
  }
}
```

Minimal UI button example:

```dart
ElevatedButton(
  onPressed: openSnapMintModule,
  child: const Text('Open SDK'),
)
```

### iOS header customization (optional)

You can customize the native iOS header by passing `iosHeader` to `openSnapmintMerchant`. Android ignores this parameter.

```dart
import 'package:flutter_snapmint_sdk/flutter_snapmint_sdk.dart';

final header = HeaderOptions(
  enableHeader: true,           // must be true to apply header
  showTitle: true,
  title: 'Snapmint',
  backButtonColor: '#000000',   // hex strings with leading '#'
  titleColor: '#000000',
  headerColor: '#F2FBFD',
);

await RNSnapmintCheckout.openSnapmintMerchant(
  checkoutUrl,
  iosHeader: header,            // iOS only; Android ignores this
  options: PaymentOptions(
    onSuccess: (r) { /* handle success */ },
    onError: (e) { /* handle error */ },
  ),
);
```

`HeaderOptions` fields:
- `enableHeader` (bool, required to apply header)
- `showTitle` (bool)
- `title` (String, used only when `showTitle` is true)
- `backButtonColor` (String hex, e.g., `#000000`)
- `titleColor` (String hex, e.g., `#000000`)
- `headerColor` (String hex, e.g., `#F2FBFD`)

Notes:
- Colors are forwarded to iOS as strings with the leading `#`.
- Android currently ignores `iosHeader` and renders without a custom header.

### 2) Show EMI Eligibility Button

Render the Snapmint button to display EMI eligibility info. Prefer `merchantPath` which maps to Snapmint merchant assets. You can also pass a full `jsonUrl` for legacy behavior.

```dart
// Basic usage with merchantPath (recommended)
const RNSnapmintButton(
  amount: '<amount>',
  merchantPath: '<merchant_assets_path>.json',
  // fontFamily: FontFamilyConfig(fontFamily: 'Roboto', fontMultiplier: 16),
  // buttonWidth: 300,
)

// Alternate legacy usage with full jsonUrl
// const RNSnapmintButton(
//   amount: '<amount>',
//   jsonUrl: '<full_json_url_from_backend>',
// )
```

All props example (merchantPath takes precedence over jsonUrl):

```dart
const RNSnapmintButton(
  amount: '<amount>',
  merchantPath: '<merchant_assets_path>.json', // if full URL provided here, jsonUrl is ignored
  jsonUrl: '<full_json_url_from_backend>',
  fontFamily: FontFamilyConfig(fontFamily: 'Roboto', fontMultiplier: 16),
  buttonWidth: 320,
  disablePopup: false,
)
```

#### RNSnapmintButton props
- `amount` (String, required): Net product amount to evaluate EMI
- `merchantPath` (String, optional): Merchant asset path like `merchantId/file.json` or full URL
- `jsonUrl` (String, optional): Full JSON URL (legacy); ignored if `merchantPath` is provided
- `fontFamily` (FontFamilyConfig, optional): Custom font and multiplier
- `buttonWidth` (double, optional): Button width
- `disablePopup` (bool, optional, default false): Disable eligibility popup

### Payment callbacks and result shape

`RNSnapmintCheckout.openSnapmintMerchant` accepts `PaymentOptions` with:
- `onSuccess(PaymentResult result)`
- `onError(PaymentError error)`

`PaymentResult` fields:
- `status` (String)
- `statusCode` (int?)
- `message` (String?)
- `responseMsg` (String?)
- `paymentId` (String?)
- `timestamp` (String?)

`PaymentError` fields mirror the result with error-specific values:
- `status` (String)
- `statusCode` (int?)
- `message` (String?)
- `responseMsg` (String?)
- `timestamp` (String?)

## Create a checkout URL (server-side)

Your backend should create a Snapmint checkout URL (including required query parameters) and return it to the app. Work with your Snapmint integration manager for the exact fields and signing/validation steps. Return this full URL to the app, then pass it into `RNSnapmintCheckout.openSnapmintMerchant(...)`.

Use the checkout URL generated by your backend. Do not call Snapmint APIs from the app or embed credentials. Checkout URLs may be one-time or time-bound; generate a fresh URL per attempt on the server and pass it to the SDK.

## Quick start

Minimal checkout integration:

```dart
import 'package:flutter_snapmint_sdk/flutter_snapmint_sdk.dart';

Future<void> openSnapMintModule(String checkoutUrl) async {
  if (checkoutUrl.trim().isEmpty) return;
  try {
    final result = await RNSnapmintCheckout.openSnapmintMerchant(
      checkoutUrl,
      options: PaymentOptions(
        onSuccess: (r) {
          // handle success
        },
        onError: (e) {
          // handle error
        },
      ),
    );
    // Optionally use result
  } catch (e) {
    // Handle thrown PaymentError or other exceptions
  }
}

// UI trigger
// ElevatedButton(onPressed: () => openSnapMintModule('<your_checkout_url>'), child: const Text('Open SDK'))
```

Render EMI eligibility button:

```dart
const RNSnapmintButton(
  amount: '<amount>',
  merchantPath: '<merchant_assets_path>.json',
  // fontFamily: FontFamilyConfig(fontFamily: 'Roboto', fontMultiplier: 16),
  // buttonWidth: 300,
)
```

### Sample responses

Success (PaymentResult):

```json
{
  "status": "success",
  "statusCode": 200,
  "responseMsg": "Payment captured",
  "paymentId": "pay_12345",
  "timestamp": "2025-01-01T12:34:56.000Z"
}
```

Error (PaymentError):

```json
{
  "status": "failure",
  "statusCode": 400,
  "responseMsg": "Payment declined",
  "message": "Insufficient limit",
  "timestamp": "2025-01-01T12:34:56.000Z"
}
```

## Troubleshooting

- Ensure the checkout URL you pass is complete and valid for the target environment.
- Handle both callbacks and thrown exceptions to avoid duplicate UI and to cover timeouts.
- For iOS, if builds fail, run `pod repo update && pod install` inside the `ios` folder.

## Testing on Sandbox (Recommended)

1. Obtain a sandbox checkout URL from your server.
2. Launch the Flutter SDK with this URL as shown in the examples.
3. If your flow reaches a UPI page and requires simulation, follow your Snapmint sandbox instructions to simulate a success outcome. After simulation, the user should be redirected back and the SDK will return success to your app.

## FAQs

- Q: How do I generate the checkout URL?
  - A: Generate it on your server using your merchant credentials and return the full URL to the client. Use sandbox for testing.

- Q: Can I customize the Snapmint EMI button style?
  - A: Set `fontFamily: FontFamilyConfig(fontFamily: 'YourFont', fontMultiplier: 16)` and optionally `buttonWidth`.

- Q: What indicates success vs failure?
  - A: Success is when `statusCode` is `200` or `status` equals `success`. Otherwise treat as failure and show the `responseMsg/message`.

## License

See `LICENSE`.

