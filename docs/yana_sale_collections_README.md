# Yana Sale Collections Plugin

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
