# Yana Sale Price Manager (standalone PHP page)

This is an independent, mobile-friendly page. It is not a WordPress plugin. Upload the `sale-manager` folder by FTP to a private HTTPS URL on the same hosting account as WordPress.

## Server setup

1. Use PHP 8.1+ with cURL enabled. Put the folder behind HTTPS. Camera scanning requires HTTPS and a browser with the native `BarcodeDetector` API; manual SKU entry works without camera access.
2. In WooCommerce, create a REST API key for a dedicated administrator account with **Read/Write** access. Keep its consumer key and secret private.
3. Choose an absolute directory outside the public website root for persistent JSON files. For example, if the public folder is `/home/ACCOUNT/domains/example.com/public_html`, use `/home/ACCOUNT/private/yana-sale-manager`. The app creates this directory with private permissions on its first request, provided its parent is writable by PHP.
4. Copy `config.example.php` to `config.php` on the server. Fill in the HTTPS store URL, WooCommerce key and secret, an admin password hash, and the absolute private data directory. Generate a hash with `php -r "echo password_hash('a-long-unique-password', PASSWORD_DEFAULT), PHP_EOL;"` and paste its output. Do not put the plain password in the config.
5. Open the page URL and sign in with the password used to generate the hash.

If the host uses Nginx, `.htaccess` is ignored. Keep `config.php` out of the public folder if possible, or add a server rule that denies direct access to `config.php` and all JSON files. Never leave WooCommerce credentials or JSON records publicly downloadable.

## How it works

- Scan or enter WooCommerce **product SKUs**. Enter several at once separated by commas or new lines (up to 100); the page fetches each one and for variable products also fetches every variation and shows their prices.
- The first successful lookup stores each product/variation's regular and sale prices in `locks.json`. Later lookups never overwrite these first-seen values.
- Each scanned row has a **your cost** field. It auto-saves to the private draft JSON as you type and is kept for your own reference; it is never sent to WooCommerce.
- The page estimates profit as locked sale price minus cost when a locked sale price exists; otherwise it uses locked regular price minus cost. It shows margin (`profit ÷ selling price`) and markup (`profit ÷ cost`) percentages; a negative result is shown as an estimated loss.
- **AI Suggest** requires a saved cost. It calculates 25% off the locked sale price, or locked regular price when no locked sale price exists, and auto-saves that amount as a draft; the live website is unchanged until **Upload Website** is pressed.
- Scanned products are added to `drafts.json`. A blank new-price field means no update is staged; enter a price and press **Save draft**. Leaving the field blank and saving stages a sale-price clear.
- Nothing is sent to WooCommerce until **Upload Website** is pressed and confirmed. Then only rows with saved drafts are sent. Successful rows are removed from the draft queue; failed rows remain for retry. Uploaded or already-changed items stay out of the main list; use **Edit again** in History to intentionally stage another change.
- Every successfully uploaded simple product or variation's parent is assigned to the WooCommerce **Big Days Sale** category, preserving its existing categories. The category is created on the first upload if it does not already exist.
- The **History** button shows each upload attempt with your saved cost, the first locked regular/sale prices, submitted sale price, time and success/failure result. History is saved in `history.json` and the newest 3,000 events are retained.
- A click applies changes immediately. To launch later, wait until the launch time before pressing **Upload Website**. This tool does not schedule a future publish.

## Important notes

- Product barcodes must be stored as WooCommerce SKUs. A barcode matching a variable product loads its variations. A variation-only SKU is not searched globally by the WooCommerce REST API; scan the parent product SKU to stage all variations.
- The `data_dir` location must be private and persistent. Back it up if the locked first-seen prices are important.
- Sale dates and regular prices are not changed by this tool. It writes only the WooCommerce `sale_price` field.
- Restrict access to the page and use a strong unique password. The API credentials have the same WooCommerce access as the account that created them.
