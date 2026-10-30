<?php
// Copy this file to config.php on the server. Never put live credentials in a public repository.
return [
    // Full HTTPS WordPress site URL, without a trailing slash.
    'store_url' => 'https://your-store.example',
    // WooCommerce > Settings > Advanced > REST API. Create a key for a dedicated admin user.
    'consumer_key' => 'ck_REPLACE_ME',
    'consumer_secret' => 'cs_REPLACE_ME',
    // Generate with: php -r "echo password_hash('your-long-password', PASSWORD_DEFAULT), PHP_EOL;"
    'admin_password_hash' => 'REPLACE_WITH_PASSWORD_HASH',
    // Absolute server path OUTSIDE the public website directory, created and writable by PHP.
    'data_dir' => '/home/ACCOUNT/private/yana-sale-manager',
];
