# Yana Sale Collections Plugin

## Festival schedules (v1.1.0)

## Old app compatibility (v1.1.2)

- In WordPress, open **Yana Sale** and enable **Manually activate Big Days Sale for old app versions**, then save.
- This server override makes the existing sale collection endpoint return `enabled: true` even outside scheduled festival dates. Turn it off when the sale ends.
- Old app installs that already cached a disabled response may still need to reopen or refresh the sale screen. A server switch cannot clear cache already stored on a phone.

- WordPress > Yana Sale > **Festival Schedule — Big Days Sale**.
- Tick **Automatically activate Big Days Sale using festival dates**.
- Tick any of the 22 festival options, fill start and end date/time, then Save Settings.
- Example: tick Diwali and choose your campaign dates. During that window the app shows **Diwali Sale**, its festival badge and an animated outer border. Existing Big Days tagged products remain the product collection.
- Dates use the WordPress Settings > General timezone. Choose Asia/Kolkata for Indian time. End time is exclusive. Dates are entered manually for each campaign; they do not repeat every year.
- Outside all selected windows the sale is closed. Invalid or reversed dates disable that festival and display an admin validation error. An overlap uses the most recently started festival; equal starts use the first entry in the table.
- With festival schedule mode OFF, the existing manual Big Days Sale toggle continues to work.
- API includes `label`, `festival_key`, `schedule_mode`, `starts_at`, `ends_at`, `server_now` and `next_transition_at`. `status_only=1` returns lightweight status without querying products. Responses disable HTTP caching.
- The updated app refreshes status every minute while active, on resume, and at scheduled boundaries. It uses bundled vector icons; no remote festival artwork is needed. Reduced-motion settings stop the border animation.
- Install the new plugin ZIP in WordPress and update the Flutter app to use the festival names/icons. The old APK cannot show the new design.

Checks: `php -l docs/yana_sale_collections_plugin.php`, `php test/festival_schedule_test.php`, and `flutter test test/festival_sale_banner_test.dart test/storefront_widgets_test.dart`.

`yana_sale_collections_plugin.php` ko `wp-content/plugins/yana-sale-collections/yana-sale-collections.php` me rakho aur plugin activate karo.

Plugin kya deta hai:
- Product edit page me `Daily Sale` aur `Big Days Sale` checkboxes
- Products list page me quick toggle columns
- App ke liye REST endpoint: `/wp-json/wp/v1/sale-collection?type=daily_sale`
- Supported types: `daily_sale`, `big_days_sale`

App-side expectation:
- Endpoint public GET hai
- Response me `items` array aata hai
- Har item WooCommerce product JSON jaisa rahega, especially `id`, `name`, `price`, `images`, `stock_status`
