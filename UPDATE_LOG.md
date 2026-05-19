# Update Log

Use this file to record every app update before release.

## Format

```
## Version x.x.x+build - YYYY-MM-DD
- Added:
  - ...
- Changed:
  - ...
- Fixed:
  - ...
- Notes:
  - ...
```

---

## Version 1.0.2+6 - 2026-02-27
- Added:
  - Custom launcher icon integration flow.
  - FCM topic sync for logged-in users (`user_<customer_id>`).
- Changed:
  - PhonePe checkout moved to WooCommerce `order-pay` WebView flow.
  - PhonePe shown only for Full Payment; hidden for Advance mode.
  - Invoice button now shows website-login message.
- Fixed:
  - Launcher icon cache/resource mapping issues.
  - Notification reliability for foreground/background handling.
  - Advance-payment gateway behavior (PayU fallback when not full payment).
- Notes:
  - Before release, verify checkout (PayU/PhonePe), FCM delivery, and order status flow.
