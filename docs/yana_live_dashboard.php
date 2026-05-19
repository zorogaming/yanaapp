<?php
declare(strict_types=1);

/**
 * Standalone Yana app dashboard.
 *
 * Deployment:
 * 1. Upload this file anywhere inside your WordPress project.
 * 2. Open it in browser while logged in as admin.
 * 3. If WordPress does not load, update the wp-load.php paths below.
 */

$wpLoadCandidates = [
    __DIR__ . '/wp-load.php',
    dirname(__DIR__) . '/wp-load.php',
    dirname(__DIR__, 2) . '/wp-load.php',
    dirname(__DIR__, 3) . '/wp-load.php',
];

$wpLoaded = false;
foreach ($wpLoadCandidates as $candidate) {
    if (is_file($candidate)) {
        require_once $candidate;
        $wpLoaded = true;
        break;
    }
}

if (!$wpLoaded) {
    http_response_code(500);
    echo 'WordPress bootstrap not found. Edit wp-load.php path in this file.';
    exit;
}

if (!is_user_logged_in() || !current_user_can('manage_options')) {
    auth_redirect();
    exit;
}

if (!isset($wpdb)) {
    http_response_code(500);
    echo '$wpdb not available.';
    exit;
}

$eventsTable = $wpdb->prefix . 'yana_app_events';
$tokensTable = $wpdb->prefix . 'yana_push_tokens';
$walletsTable = $wpdb->prefix . 'yana_wallets';
$walletTxTable = $wpdb->prefix . 'yana_wallet_transactions';

foreach ([$eventsTable, $tokensTable, $walletsTable, $walletTxTable] as $requiredTable) {
    $exists = $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $requiredTable));
    if ($exists !== $requiredTable) {
        http_response_code(500);
        echo 'Required table missing: ' . esc_html($requiredTable);
        exit;
    }
}

function yana_dashboard_actor_key(int $userId, string $installId): string
{
    if ($userId > 0) {
        return 'u:' . $userId;
    }
    return $installId !== '' ? 'g:' . $installId : '';
}

function yana_dashboard_actor_label(int $userId, string $installId): array
{
    $email = '';
    $name = '';

    if ($userId > 0) {
        $user = get_userdata($userId);
        if ($user instanceof WP_User) {
            $email = (string) $user->user_email;
            $name = trim((string) $user->display_name);
        }
    }

    return [
        'name' => $name !== '' ? $name : ($userId > 0 ? 'User #' . $userId : 'Guest User'),
        'email' => $email,
        'user_id' => $userId,
        'install_id' => $installId,
        'actor_key' => yana_dashboard_actor_key($userId, $installId),
    ];
}

function yana_dashboard_wallet_for_input(wpdb $wpdb, string $walletsTable, string $actorKey, int $userId, string $installId): ?array
{
    if ($actorKey !== '') {
        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$walletsTable} WHERE actor_key = %s LIMIT 1", $actorKey),
            ARRAY_A
        );
        return is_array($row) ? $row : null;
    }

    if ($userId > 0) {
        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$walletsTable} WHERE user_id = %d ORDER BY updated_at DESC LIMIT 1", $userId),
            ARRAY_A
        );
        if (is_array($row)) {
            return $row;
        }
    }

    if ($installId !== '') {
        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$walletsTable} WHERE install_id = %s ORDER BY updated_at DESC LIMIT 1", $installId),
            ARRAY_A
        );
        return is_array($row) ? $row : null;
    }

    return null;
}

function yana_dashboard_get_home_popup_state(): array
{
    $state = get_option('yana_home_popup_state', []);
    if (!is_array($state)) {
        $state = [];
    }

    return array_merge([
        'campaign_id' => '',
        'active' => false,
        'title' => '',
        'message' => '',
        'button_text' => 'View Now',
        'action_url' => '',
        'updated_at' => '',
    ], $state);
}

function yana_dashboard_set_home_popup_state(array $payload): array
{
    $current = yana_dashboard_get_home_popup_state();
    $action = sanitize_key((string) ($payload['action'] ?? 'activate_new'));

    if ($action === 'deactivate') {
        $state = $current;
        $state['active'] = false;
        $state['updated_at'] = current_time('mysql');
        update_option('yana_home_popup_state', $state, false);

        return ['ok' => true, 'state' => $state];
    }

    $message = trim((string) ($payload['message'] ?? ''));
    if ($message === '') {
        return ['ok' => false, 'message' => 'Popup message required hai.'];
    }

    $currentCampaignId = trim((string) ($current['campaign_id'] ?? ''));
    $state = [
        'campaign_id' => $action === 'update_current' && $currentCampaignId !== ''
            ? $currentCampaignId
            : 'campaign_' . wp_generate_password(10, false, false) . '_' . time(),
        'active' => true,
        'title' => sanitize_text_field((string) ($payload['title'] ?? 'Important Update')),
        'message' => sanitize_textarea_field($message),
        'button_text' => sanitize_text_field((string) ($payload['button_text'] ?? 'View Now')),
        'action_url' => esc_url_raw((string) ($payload['action_url'] ?? '')),
        'updated_at' => current_time('mysql'),
    ];

    update_option('yana_home_popup_state', $state, false);

    return ['ok' => true, 'state' => $state];
}

function yana_dashboard_log_wallet_tx(
    wpdb $wpdb,
    string $walletTxTable,
    string $actorKey,
    float $amount,
    float $balanceAfter,
    string $source,
    array $meta = []
): void {
    $wpdb->insert(
        $walletTxTable,
        [
            'actor_key' => $actorKey,
            'linked_actor' => null,
            'tx_type' => $amount >= 0 ? 'credit' : 'debit',
            'amount' => $amount,
            'balance_after' => $balanceAfter,
            'source' => $source,
            'meta' => wp_json_encode($meta),
            'created_at' => current_time('mysql'),
        ],
        ['%s', '%s', '%s', '%f', '%f', '%s', '%s', '%s']
    );
}

function yana_dashboard_adjust_wallet(
    wpdb $wpdb,
    string $walletsTable,
    string $walletTxTable,
    string $actorKey,
    float $delta,
    string $note
): bool {
    $wallet = $wpdb->get_row(
        $wpdb->prepare("SELECT * FROM {$walletsTable} WHERE actor_key = %s LIMIT 1", $actorKey),
        ARRAY_A
    );

    if (!is_array($wallet)) {
        return false;
    }

    $current = (float) ($wallet['balance'] ?? 0);
    $newBalance = max(0, round($current + $delta, 2));
    $actualDelta = round($newBalance - $current, 2);

    $updated = $wpdb->update(
        $walletsTable,
        [
            'balance' => $newBalance,
            'updated_at' => current_time('mysql'),
        ],
        ['id' => (int) $wallet['id']],
        ['%f', '%s'],
        ['%d']
    );

    if ($updated === false) {
        return false;
    }

    yana_dashboard_log_wallet_tx(
        $wpdb,
        $walletTxTable,
        $actorKey,
        $actualDelta,
        $newBalance,
        'standalone_dashboard_adjust',
        [
            'note' => $note,
            'requested_delta' => $delta,
            'admin_user_id' => get_current_user_id(),
        ]
    );

    return true;
}

function yana_dashboard_push_templates(): array
{
    return [
        'custom' => [
            'title' => 'Yana Update',
            'body' => 'Aapke liye ek naya update hai. App kholkar dekhiye.',
        ],
        'cart_reminder' => [
            'title' => 'Cart Me Product Wait Kar Raha Hai',
            'body' => 'Aapke cart me products abhi bhi pade hain. Checkout complete kijiye.',
        ],
        'payment_retry' => [
            'title' => 'Payment Complete Kijiye',
            'body' => 'Aapka payment complete nahi hua. Dobara try karke order finish kijiye.',
        ],
        'wallet_alert' => [
            'title' => 'Wallet Update',
            'body' => 'Aapke wallet me balance update hua hai. App me check kijiye.',
        ],
        'product_followup' => [
            'title' => 'Aapka Dekha Hua Product Ready Hai',
            'body' => 'Jo product aap dekh rahe the wo abhi available hai. Jaldi check kijiye.',
        ],
        'coupon_2_percent' => [
            'title' => '2% Coupon For You',
            'body' => 'Aapke liye 2% OFF coupon ready hai. App open karke checkout par apply kijiye.',
        ],
    ];
}

function yana_dashboard_bulk_push_templates(): array
{
    return [
        'please_see_app' => [
            'title' => 'Please Check the App',
            'body' => 'We have something important for you. Please open the app and take a look.',
            'audience_filter' => 'any',
        ],
        'cart_reminder' => [
            'title' => 'Items Are Waiting in Your Cart',
            'body' => 'You still have items in your cart. Complete your checkout before they go out of stock.',
            'audience_filter' => 'cart',
        ],
        'pending_order' => [
            'title' => 'Your Order Is Still Pending',
            'body' => 'Your order is pending. Please open the app and complete the next step.',
            'audience_filter' => 'any',
        ],
        'product_interest' => [
            'title' => 'A Product You Viewed Is Waiting',
            'body' => 'A product you showed interest in is still available. Open the app to check it now.',
            'audience_filter' => 'repeat_views',
        ],
        'payment_retry' => [
            'title' => 'Complete Your Payment',
            'body' => 'Your payment was not completed. Please retry from the app to finish your order.',
            'audience_filter' => 'any',
        ],
        'wallet_update' => [
            'title' => 'Wallet Update Available',
            'body' => 'Your wallet has been updated. Please open the app to check your latest balance.',
            'audience_filter' => 'any',
        ],
        'app_update' => [
            'title' => 'New App Update Available',
            'body' => 'A new version of the app is available. Please update now for the latest features and fixes.',
            'audience_filter' => 'any',
        ],
    ];
}

function yana_dashboard_send_push(string $actorKey, string $pushType, string $title, string $body, array $extraData = []): array
{
    if ($actorKey === '') {
        return ['ok' => false, 'message' => 'actor_key required'];
    }
    if (!class_exists('Yana_App_Event_Automation')) {
        return ['ok' => false, 'message' => 'Push automation class load nahi hui.'];
    }

    $payload = [
        'actor_key' => $actorKey,
        'title' => $title,
        'body' => $body,
        'data' => array_merge([
            'type' => $pushType !== '' ? $pushType : 'custom_admin_message',
            'source' => 'standalone_dashboard',
        ], $extraData),
    ];

    $request = new WP_REST_Request('POST', '/yana-admin/v1/push/custom');
    $request->set_header('content-type', 'application/json');
    $request->set_body(wp_json_encode($payload));

    $response = Yana_App_Event_Automation::rest_admin_push_custom($request);
    $data = $response instanceof WP_REST_Response ? $response->get_data() : null;
    if (is_array($data)) {
        return $data;
    }

    return ['ok' => false, 'message' => 'Push send failed.'];
}

function yana_dashboard_extract_search_term(array $payload): string
{
    $candidates = [
        (string) ($payload['search_term'] ?? ''),
        (string) ($payload['query'] ?? ''),
        (string) ($payload['keyword'] ?? ''),
        (string) ($payload['term'] ?? ''),
    ];

    foreach ($candidates as $candidate) {
        $candidate = trim($candidate);
        if ($candidate !== '' && strtolower($candidate) !== 'empty') {
            return $candidate;
        }
    }

    return '';
}

function yana_dashboard_current_page_label(string $eventName, array $payload, int $productId): string
{
    $screenName = trim((string) ($payload['screen_name'] ?? ''));
    if ($screenName !== '') {
        return $screenName;
    }

    $pageUrl = trim((string) ($payload['page_url'] ?? ''));
    if ($pageUrl !== '') {
        return $pageUrl;
    }

    $productName = trim((string) ($payload['product_name'] ?? ''));
    if (in_array($eventName, ['product_view', 'view_item'], true)) {
        return $productName !== '' ? $productName : ($productId > 0 ? 'product/' . $productId : 'product');
    }

    return $eventName;
}

function yana_dashboard_create_coupon_code(int $userId, string $installId, string $reason): string
{
    if (!class_exists('WC_Coupon')) {
        return '';
    }

    $scope = $userId > 0 ? 'u' . $userId : ($installId !== '' ? $installId : 'all');
    $cacheKey = 'yana_dashboard_coupon_' . md5($scope . '_' . $reason);
    $existing = get_transient($cacheKey);
    if (is_string($existing) && $existing !== '') {
        return $existing;
    }

    $code = 'YANA2-' . strtoupper(wp_generate_password(6, false, false));
    $coupon = new WC_Coupon();
    $coupon->set_code($code);
    $coupon->set_discount_type('percent');
    $coupon->set_amount('2');
    $coupon->set_usage_limit(1);
    $coupon->set_usage_limit_per_user(1);
    $coupon->set_date_expires(new DateTime('+3 days'));
    $coupon->update_meta_data('yana_generated_for', $scope);
    $coupon->update_meta_data('yana_reason', $reason);
    $coupon->save();

    set_transient($cacheKey, $code, 12 * HOUR_IN_SECONDS);
    return $code;
}

function yana_dashboard_compare_versions(string $left, string $right): int
{
    $parse = static function (string $value): array {
        $normalized = trim(explode('+', $value)[0] ?? '');
        if ($normalized === '') {
            return [];
        }

        return array_map(
            static fn(string $part): int => (int) preg_replace('/[^0-9]/', '', $part),
            explode('.', $normalized)
        );
    };

    $a = $parse($left);
    $b = $parse($right);
    $length = max(count($a), count($b));
    for ($i = 0; $i < $length; $i++) {
        $av = $a[$i] ?? 0;
        $bv = $b[$i] ?? 0;
        if ($av !== $bv) {
            return $av <=> $bv;
        }
    }

    return 0;
}

function yana_dashboard_is_outdated_version(string $currentVersion, string $targetVersion): bool
{
    if ($currentVersion === '' || $targetVersion === '') {
        return false;
    }

    return yana_dashboard_compare_versions($currentVersion, $targetVersion) < 0;
}

$walletMessage = '';
$walletError = '';
$pushMessage = '';
$pushError = '';
$updateMessage = '';
$updateError = '';
$homePopupMessage = '';
$homePopupError = '';
$walletLookupResult = null;
$bulkPushMessage = '';
$bulkPushError = '';
$couponMessage = '';
$couponError = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['wallet_adjust_submit'])) {
    check_admin_referer('yana_wallet_adjust_action', 'yana_wallet_adjust_nonce');

    $actorKey = sanitize_text_field((string) wp_unslash($_POST['actor_key'] ?? ''));
    $userId = absint((int) ($_POST['user_id'] ?? 0));
    $installId = sanitize_text_field((string) wp_unslash($_POST['install_id'] ?? ''));
    $delta = round((float) ($_POST['delta_amount'] ?? 0), 2);
    $note = sanitize_text_field((string) wp_unslash($_POST['note'] ?? ''));

    $wallet = yana_dashboard_wallet_for_input($wpdb, $walletsTable, $actorKey, $userId, $installId);
    if (!$wallet) {
        $walletError = 'Wallet user not found.';
    } elseif ($delta === 0.0) {
        $walletError = 'Amount 0 nahi ho sakta.';
    } else {
        $ok = yana_dashboard_adjust_wallet(
            $wpdb,
            $walletsTable,
            $walletTxTable,
            (string) $wallet['actor_key'],
            $delta,
            $note
        );
        if ($ok) {
            $walletMessage = 'Wallet updated for ' . esc_html((string) $wallet['actor_key']);
            $amountText = '₹' . number_format(abs($delta), 2);
            $pushTitle = $delta > 0 ? 'Wallet Topup' : 'Wallet Balance Update';
            $pushBody = $delta > 0
                ? "{$amountText} aapke wallet me add kiya gaya hai. App me check kijiye."
                : "{$amountText} aapke wallet se adjust kiya gaya hai. App me balance check kijiye.";
            $pushResult = yana_dashboard_send_push(
                (string) $wallet['actor_key'],
                $delta > 0 ? 'wallet_topup' : 'wallet_adjustment',
                $pushTitle,
                $pushBody
            );
            if (!empty($pushResult['ok'])) {
                $walletMessage .= ' Aur wallet notification bhi bhej diya gaya.';
            } else {
                $walletError = is_array($pushResult) && !empty($pushResult['message'])
                    ? ' Wallet update hua, push failed: ' . (string) $pushResult['message']
                    : ' Wallet update hua, lekin push nahi gaya.';
            }
        } else {
            $walletError = 'Wallet update failed.';
        }
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['push_send_submit'])) {
    check_admin_referer('yana_push_send_action', 'yana_push_send_nonce');

    $actorKey = sanitize_text_field((string) wp_unslash($_POST['actor_key'] ?? ''));
    $pushType = sanitize_key((string) wp_unslash($_POST['push_type'] ?? 'custom'));
    $title = sanitize_text_field((string) wp_unslash($_POST['push_title'] ?? ''));
    $body = sanitize_text_field((string) wp_unslash($_POST['push_body'] ?? ''));

    $templates = yana_dashboard_push_templates();
    if ($actorKey === '') {
        $pushError = 'Push ke liye actor_key required hai.';
    } elseif ($title === '' || $body === '') {
        $pushError = 'Push title aur body required hai.';
    } else {
        $data = yana_dashboard_send_push($actorKey, $pushType, $title, $body);
        if (is_array($data) && !empty($data['ok'])) {
            $pushMessage = 'Push sent to ' . esc_html($actorKey);
        } else {
            $pushError = is_array($data) && !empty($data['message'])
                ? (string) $data['message']
                : 'Push send failed.';
        }
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['coupon_push_submit'])) {
    check_admin_referer('yana_coupon_push_action', 'yana_coupon_push_nonce');

    $actorKey = sanitize_text_field((string) wp_unslash($_POST['actor_key'] ?? ''));
    $userId = absint((int) ($_POST['user_id'] ?? 0));
    $installId = sanitize_text_field((string) wp_unslash($_POST['install_id'] ?? ''));
    $couponCode = yana_dashboard_create_coupon_code($userId, $installId, 'standalone_dashboard_manual');

    if ($actorKey === '') {
        $couponError = 'Coupon bhejne ke liye actor_key required hai.';
    } elseif ($couponCode === '') {
        $couponError = '2% coupon generate nahi hua. WooCommerce coupon support check kijiye.';
    } else {
        $title = '2% Coupon For You';
        $body = "Use {$couponCode} and save 2% on your next order.";
        $data = yana_dashboard_send_push(
            $actorKey,
            'coupon',
            $title,
            $body,
            ['coupon_code' => $couponCode]
        );
        if (is_array($data) && !empty($data['ok'])) {
            $couponMessage = '2% coupon sent to ' . esc_html($actorKey) . ' (' . esc_html($couponCode) . ')';
        } else {
            $couponError = is_array($data) && !empty($data['message'])
                ? (string) $data['message']
                : 'Coupon notification send failed.';
        }
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['version_push_submit'])) {
    check_admin_referer('yana_version_push_action', 'yana_version_push_nonce');

    $actorKey = sanitize_text_field((string) wp_unslash($_POST['actor_key'] ?? ''));
    $currentVersion = sanitize_text_field((string) wp_unslash($_POST['current_version'] ?? ''));
    $targetVersion = sanitize_text_field((string) wp_unslash($_POST['target_version'] ?? ''));
    $title = sanitize_text_field((string) wp_unslash($_POST['version_push_title'] ?? ''));
    $body = sanitize_text_field((string) wp_unslash($_POST['version_push_body'] ?? ''));

    if ($actorKey === '') {
        $pushError = 'Version reminder ke liye actor_key required hai.';
    } elseif ($title === '' || $body === '') {
        $pushError = 'Version reminder title aur body required hai.';
    } else {
        $data = yana_dashboard_send_push($actorKey, 'app_update_reminder', $title, $body);
        if (is_array($data) && !empty($data['ok'])) {
            $pushMessage = 'Version reminder sent to ' . esc_html($actorKey);
            if ($currentVersion !== '' && $targetVersion !== '') {
                $pushMessage .= ' (' . esc_html($currentVersion) . ' -> ' . esc_html($targetVersion) . ')';
            }
        } else {
            $pushError = is_array($data) && !empty($data['message'])
                ? (string) $data['message']
                : 'Version reminder send failed.';
        }
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['app_update_submit'])) {
    check_admin_referer('yana_app_update_action', 'yana_app_update_nonce');

    $updateAction = sanitize_key((string) wp_unslash($_POST['update_action'] ?? 'activate'));
    $title = sanitize_text_field((string) wp_unslash($_POST['update_title'] ?? 'Update Available'));
    $message = sanitize_text_field((string) wp_unslash($_POST['update_message'] ?? 'Please update the app for the best experience.'));
    $url = esc_url_raw((string) wp_unslash($_POST['update_url'] ?? ''));
    $minVersion = sanitize_text_field((string) wp_unslash($_POST['update_min_version'] ?? ''));
    $latestVersion = sanitize_text_field((string) wp_unslash($_POST['update_latest_version'] ?? ''));
    $forceUpdate = !empty($_POST['update_force']);

    if (!class_exists('Yana_App_Event_Automation')) {
        $updateError = 'App update class load nahi hui.';
    } else {
        $payload = $updateAction === 'deactivate'
            ? ['action' => 'deactivate']
            : [
                'action' => 'activate',
                'title' => $title,
                'message' => $message,
                'url' => $url,
                'min_version' => $minVersion,
                'latest_version' => $latestVersion,
                'force_update' => $forceUpdate,
            ];

        $request = new WP_REST_Request('POST', '/yana-admin/v1/app-update');
        $request->set_header('content-type', 'application/json');
        $request->set_body(wp_json_encode($payload));

        $response = Yana_App_Event_Automation::rest_admin_app_update_set($request);
        $data = $response instanceof WP_REST_Response ? $response->get_data() : null;
        if (is_array($data) && !empty($data['ok'])) {
            $updateMessage = $updateAction === 'deactivate'
                ? 'App update popup band kar diya gaya.'
                : 'App update popup active kar diya gaya.';
        } else {
            $updateError = is_array($data) && !empty($data['message'])
                ? (string) $data['message']
                : 'App update action failed.';
        }
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && (isset($_POST['home_popup_submit']) || isset($_POST['home_popup_submit_action']))) {
    check_admin_referer('yana_home_popup_action', 'yana_home_popup_nonce');

    $homePopupAction = sanitize_key((string) wp_unslash($_POST['home_popup_submit_action'] ?? ($_POST['home_popup_action'] ?? 'activate_new')));
    $homePopupTitle = sanitize_text_field((string) wp_unslash($_POST['home_popup_title'] ?? 'Important Update'));
    $homePopupBody = sanitize_textarea_field((string) wp_unslash($_POST['home_popup_message'] ?? ''));
    $homePopupButtonText = sanitize_text_field((string) wp_unslash($_POST['home_popup_button_text'] ?? 'View Now'));
    $homePopupActionUrl = esc_url_raw((string) wp_unslash($_POST['home_popup_action_url'] ?? ''));

    $payload = $homePopupAction === 'deactivate'
        ? ['action' => 'deactivate']
        : [
            'action' => $homePopupAction,
            'title' => $homePopupTitle,
            'message' => $homePopupBody,
            'button_text' => $homePopupButtonText,
            'action_url' => $homePopupActionUrl,
        ];

    $data = yana_dashboard_set_home_popup_state($payload);

    if (is_array($data) && !empty($data['ok'])) {
        $homePopupMessage = $homePopupAction === 'deactivate'
            ? 'Home popup band kar diya gaya.'
            : ($homePopupAction === 'update_current'
                ? 'Current popup update kar diya gaya. Same campaign ID rahegi.'
                : 'New home popup campaign users ke liye active kar diya gaya.');
    } else {
        $homePopupError = is_array($data) && !empty($data['message'])
            ? (string) $data['message']
            : 'Home popup action failed.';
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['wallet_lookup_submit'])) {
    check_admin_referer('yana_wallet_lookup_action', 'yana_wallet_lookup_nonce');

    $actorKey = sanitize_text_field((string) wp_unslash($_POST['lookup_actor_key'] ?? ''));
    $userId = absint((int) ($_POST['lookup_user_id'] ?? 0));
    $installId = sanitize_text_field((string) wp_unslash($_POST['lookup_install_id'] ?? ''));

    $walletLookupResult = yana_dashboard_wallet_for_input($wpdb, $walletsTable, $actorKey, $userId, $installId);
    if (!$walletLookupResult) {
        $walletError = 'Wallet balance check me user nahi mila.';
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['bulk_push_submit'])) {
    check_admin_referer('yana_bulk_push_action', 'yana_bulk_push_nonce');

    $templateKey = sanitize_key((string) wp_unslash($_POST['bulk_template'] ?? 'please_see_app'));
    $targetMode = sanitize_key((string) wp_unslash($_POST['bulk_target_mode'] ?? 'all'));
    $audienceFilter = sanitize_key((string) wp_unslash($_POST['bulk_audience_filter'] ?? 'any'));
    $title = sanitize_text_field((string) wp_unslash($_POST['bulk_title'] ?? ''));
    $body = sanitize_text_field((string) wp_unslash($_POST['bulk_body'] ?? ''));
    $productId = absint((int) ($_POST['bulk_product_id'] ?? 0));
    $lookbackDays = max(1, min(60, absint((int) ($_POST['bulk_lookback_days'] ?? 7))));
    $templates = yana_dashboard_bulk_push_templates();

    if (isset($templates[$templateKey])) {
        if ($title === '') {
            $title = (string) ($templates[$templateKey]['title'] ?? '');
        }
        if ($body === '') {
            $body = (string) ($templates[$templateKey]['body'] ?? '');
        }
        if ($audienceFilter === '') {
            $audienceFilter = (string) ($templates[$templateKey]['audience_filter'] ?? 'any');
        }
    }

    if ($title === '' || $body === '') {
        $bulkPushError = 'Bulk push title aur body required hai.';
    } elseif (!class_exists('Yana_App_Event_Automation')) {
        $bulkPushError = 'Bulk push class load nahi hui.';
    } else {
        $request = new WP_REST_Request('POST', '/yana-admin/v1/push/campaign');
        $request->set_header('content-type', 'application/json');
        $request->set_body(wp_json_encode([
            'title' => $title,
            'body' => $body,
            'target_mode' => in_array($targetMode, ['all', 'guest_only'], true) ? $targetMode : 'all',
            'audience_filter' => in_array($audienceFilter, ['any', 'cart', 'product', 'repeat_views'], true) ? $audienceFilter : 'any',
            'lookback_days' => $lookbackDays,
            'product_id' => $productId,
            'deep_link' => '',
            'image_url' => '',
            'coupon_code' => '',
            'schedule_mode' => 'now',
            'schedule_at' => '',
        ]));

        $response = Yana_App_Event_Automation::rest_admin_push_campaign($request);
        $data = $response instanceof WP_REST_Response ? $response->get_data() : null;
        if (is_array($data) && !empty($data['ok'])) {
            $result = is_array($data['result'] ?? null) ? $data['result'] : [];
            $bulkPushMessage = 'Bulk push sent.';
            if (!empty($result)) {
                $sent = isset($result['sent']) ? (int) $result['sent'] : null;
                $attempted = isset($result['attempted']) ? (int) $result['attempted'] : null;
                if ($sent !== null || $attempted !== null) {
                    $bulkPushMessage .= ' Sent: ' . (string) ($sent ?? 0) . ', Attempted: ' . (string) ($attempted ?? 0);
                }
            }
        } else {
            $bulkPushError = is_array($data) && !empty($data['message'])
                ? (string) $data['message']
                : 'Bulk push send failed.';
        }
    }
}

$activeMinutes = isset($_GET['active_minutes']) ? max(5, min(120, absint((int) $_GET['active_minutes']))) : 15;
$paymentHours = isset($_GET['payment_hours']) ? max(1, min(168, absint((int) $_GET['payment_hours']))) : 24;
$walletLimit = isset($_GET['wallet_limit']) ? max(20, min(300, absint((int) $_GET['wallet_limit']))) : 80;
$walletSearch = sanitize_text_field((string) ($_GET['q'] ?? ''));
$walletSearchLike = '%' . $wpdb->esc_like($walletSearch) . '%';

$summary = [
    'installs' => (int) $wpdb->get_var("SELECT COUNT(DISTINCT install_id) FROM {$eventsTable} WHERE install_id IS NOT NULL AND install_id <> ''"),
    'active_devices' => (int) $wpdb->get_var(
        $wpdb->prepare(
            "SELECT COUNT(DISTINCT install_id)
             FROM {$eventsTable}
             WHERE install_id IS NOT NULL
               AND install_id <> ''
               AND created_at >= (NOW() - INTERVAL %d MINUTE)",
            $activeMinutes
        )
    ),
    'wallet_users' => (int) $wpdb->get_var("SELECT COUNT(*) FROM {$walletsTable} WHERE balance > 0"),
    'wallet_balance' => round((float) $wpdb->get_var("SELECT COALESCE(SUM(balance), 0) FROM {$walletsTable}"), 2),
    'checkout_users' => 0,
    'live_viewers' => 0,
    'payment_failed' => (int) $wpdb->get_var(
        $wpdb->prepare(
            "SELECT COUNT(*)
             FROM {$eventsTable}
             WHERE event_name = 'payment_status'
               AND created_at >= (NOW() - INTERVAL %d HOUR)
               AND (
                    payload LIKE '%payment_not_completed%'
                    OR payload LIKE '%order_created_pending%'
                    OR payload LIKE '%failed%'
               )",
            $paymentHours
        )
    ),
];

$recentEvents = $wpdb->get_results(
    $wpdb->prepare(
        "SELECT id, event_name, user_id, install_id, product_id, payload, created_at
         FROM {$eventsTable}
         WHERE created_at >= (NOW() - INTERVAL %d MINUTE)
         ORDER BY id DESC
         LIMIT 1200",
        $activeMinutes
    ),
    ARRAY_A
);

$latestByActor = [];
$lastProductByActor = [];
$lastSearchByActor = [];
foreach ((array) $recentEvents as $eventRow) {
    $userId = (int) ($eventRow['user_id'] ?? 0);
    $installId = (string) ($eventRow['install_id'] ?? '');
    $actorKey = yana_dashboard_actor_key($userId, $installId);
    if ($actorKey === '') {
        continue;
    }

    $payload = json_decode((string) ($eventRow['payload'] ?? '{}'), true);
    $payload = is_array($payload) ? $payload : [];
    $eventName = (string) ($eventRow['event_name'] ?? '');

    if (!isset($latestByActor[$actorKey])) {
        $latestByActor[$actorKey] = [
            'event_name' => $eventName,
            'created_at' => (string) ($eventRow['created_at'] ?? ''),
            'product_id' => (int) ($eventRow['product_id'] ?? 0),
            'product_name' => (string) ($payload['product_name'] ?? ''),
            'screen_name' => (string) ($payload['screen_name'] ?? ''),
            'page_url' => (string) ($payload['page_url'] ?? ''),
            'status' => (string) ($payload['status'] ?? ''),
            'payment_method' => (string) ($payload['payment_method'] ?? ''),
            'amount' => round((float) ($payload['amount'] ?? 0), 2),
            'identity' => yana_dashboard_actor_label($userId, $installId),
            'payload' => $payload,
        ];
    }

    if (!isset($lastProductByActor[$actorKey]) && in_array($eventName, ['product_view', 'view_item'], true)) {
        $productName = trim((string) ($payload['product_name'] ?? ''));
        $productId = (int) ($eventRow['product_id'] ?? 0);
        $lastProductByActor[$actorKey] = [
            'name' => $productName !== '' ? $productName : ($productId > 0 ? 'Product #' . $productId : '-'),
            'time' => (string) ($eventRow['created_at'] ?? ''),
        ];
    }

    if (!isset($lastSearchByActor[$actorKey]) && $eventName === 'search') {
        $searchTerm = yana_dashboard_extract_search_term($payload);
        if ($searchTerm !== '') {
            $lastSearchByActor[$actorKey] = [
                'term' => $searchTerm,
                'time' => (string) ($eventRow['created_at'] ?? ''),
            ];
        }
    }
}

$liveProductRows = [];
$checkoutRows = [];
$currentPageRows = [];
$activeActorKeys = [];
foreach ($latestByActor as $actorKey => $item) {
    $eventName = $item['event_name'];
    $screenName = strtolower(trim($item['screen_name']));
    $activeActorKeys[$actorKey] = true;
    $currentPage = yana_dashboard_current_page_label($eventName, (array) ($item['payload'] ?? []), (int) ($item['product_id'] ?? 0));
    $lastProduct = $lastProductByActor[$actorKey]['name'] ?? '-';
    $lastSearch = $lastSearchByActor[$actorKey]['term'] ?? '-';

    $currentPageRows[] = [
        'identity' => $item['identity'],
        'current_page' => $currentPage,
        'last_product' => $lastProduct,
        'last_search' => $lastSearch,
        'seen_at' => $item['created_at'],
        'event_name' => $eventName,
    ];

    if ($eventName === 'product_view') {
        $liveProductRows[] = [
            'identity' => $item['identity'],
            'product_name' => $item['product_name'] !== '' ? $item['product_name'] : ('Product #' . $item['product_id']),
            'seen_at' => $item['created_at'],
        ];
    }

    if ($eventName === 'begin_checkout' || ($eventName === 'page_view' && $screenName === 'checkout')) {
        $checkoutRows[] = [
            'identity' => $item['identity'],
            'amount' => $item['amount'],
            'seen_at' => $item['created_at'],
        ];
    }
}

$summary['live_viewers'] = count($liveProductRows);
$summary['checkout_users'] = count($checkoutRows);

$popupEvents = $wpdb->get_results(
    "SELECT id, event_name, user_id, install_id, payload, created_at
     FROM {$eventsTable}
     WHERE event_name IN ('home_popup_view', 'home_popup_close', 'home_popup_cta', 'home_popup_dismiss')
     ORDER BY id DESC
     LIMIT 800",
    ARRAY_A
);

$popupSeenRows = [];
foreach ((array) $popupEvents as $row) {
    $payload = json_decode((string) ($row['payload'] ?? '{}'), true);
    $payload = is_array($payload) ? $payload : [];
    $campaignId = trim((string) ($payload['campaign_id'] ?? ''));
    if ($campaignId === '') {
        continue;
    }

    $userId = (int) ($row['user_id'] ?? 0);
    $installId = (string) ($row['install_id'] ?? '');
    $actorKey = yana_dashboard_actor_key($userId, $installId);
    if ($actorKey === '') {
        continue;
    }

    $rowKey = $actorKey . '|' . $campaignId;
    if (!isset($popupSeenRows[$rowKey])) {
        $popupSeenRows[$rowKey] = [
            'identity' => yana_dashboard_actor_label($userId, $installId),
            'campaign_id' => $campaignId,
            'title' => trim((string) ($payload['title'] ?? 'Important Update')),
            'viewed_at' => '-',
            'last_action' => '-',
            'action_at' => '-',
        ];
    }

    $eventName = (string) ($row['event_name'] ?? '');
    if ($eventName === 'home_popup_view' && $popupSeenRows[$rowKey]['viewed_at'] === '-') {
        $popupSeenRows[$rowKey]['viewed_at'] = (string) ($row['created_at'] ?? '-');
    }

    if (in_array($eventName, ['home_popup_close', 'home_popup_cta', 'home_popup_dismiss'], true)
        && $popupSeenRows[$rowKey]['action_at'] === '-') {
        $popupSeenRows[$rowKey]['last_action'] = $eventName === 'home_popup_cta'
            ? 'View More'
            : ($eventName === 'home_popup_close' ? 'Close' : 'Dismiss');
        $popupSeenRows[$rowKey]['action_at'] = (string) ($row['created_at'] ?? '-');
    }
}

$popupSeenRows = array_values($popupSeenRows);
$popupSeenRows = array_slice($popupSeenRows, 0, 10);
$currentPopupSeenCount = 0;
if (!empty($homePopupState['campaign_id'])) {
    foreach ($popupSeenRows as $popupSeenRow) {
        if ((string) ($popupSeenRow['campaign_id'] ?? '') === (string) $homePopupState['campaign_id']) {
            $currentPopupSeenCount++;
        }
    }
}

$paymentFailures = $wpdb->get_results(
    $wpdb->prepare(
        "SELECT id, user_id, install_id, payload, created_at
         FROM {$eventsTable}
         WHERE event_name = 'payment_status'
           AND created_at >= (NOW() - INTERVAL %d HOUR)
           AND (
                payload LIKE '%payment_not_completed%'
                OR payload LIKE '%order_created_pending%'
                OR payload LIKE '%failed%'
           )
         ORDER BY id DESC
         LIMIT 60",
        $paymentHours
    ),
    ARRAY_A
);

$paymentFailureRows = [];
foreach ((array) $paymentFailures as $row) {
    $userId = (int) ($row['user_id'] ?? 0);
    $installId = (string) ($row['install_id'] ?? '');
    $payload = json_decode((string) ($row['payload'] ?? '{}'), true);
    $payload = is_array($payload) ? $payload : [];
    $paymentFailureRows[] = [
        'identity' => yana_dashboard_actor_label($userId, $installId),
        'status' => (string) ($payload['status'] ?? 'failed'),
        'method' => (string) ($payload['payment_method'] ?? ''),
        'amount' => round((float) ($payload['amount'] ?? 0), 2),
        'created_at' => (string) ($row['created_at'] ?? ''),
    ];
}

$walletWhere = '';
$walletRowsParams = [];
if ($walletSearch !== '') {
    $walletWhere = "WHERE (w.actor_key LIKE %s OR w.install_id LIKE %s OR CAST(w.user_id AS CHAR) LIKE %s)";
    $walletRowsParams = [$walletSearchLike, $walletSearchLike, $walletSearchLike];
}

$walletSql = "SELECT
        w.actor_key,
        w.user_id,
        w.install_id,
        w.balance,
        w.banned,
        w.updated_at,
        (
            SELECT t.app_version
            FROM {$tokensTable} t
            WHERE (
                (w.user_id IS NOT NULL AND w.user_id > 0 AND t.user_id = w.user_id)
                OR (
                    (w.user_id IS NULL OR w.user_id = 0)
                    AND w.install_id IS NOT NULL
                    AND w.install_id <> ''
                    AND t.install_id = w.install_id
                )
            )
              AND t.app_version IS NOT NULL
              AND t.app_version <> ''
            ORDER BY t.last_seen DESC, t.id DESC
            LIMIT 1
        ) AS app_version,
        (
            SELECT t.last_seen
            FROM {$tokensTable} t
            WHERE (
                (w.user_id IS NOT NULL AND w.user_id > 0 AND t.user_id = w.user_id)
                OR (
                    (w.user_id IS NULL OR w.user_id = 0)
                    AND w.install_id IS NOT NULL
                    AND w.install_id <> ''
                    AND t.install_id = w.install_id
                )
            )
            ORDER BY t.last_seen DESC, t.id DESC
            LIMIT 1
        ) AS app_version_seen_at,
        COALESCE(tx.wallet_used_total, 0) AS wallet_used_total,
        COALESCE(tx.credit_total, 0) AS credit_total,
        COALESCE(tx.debit_total, 0) AS debit_total,
        COALESCE(tx.tx_count, 0) AS tx_count
    FROM {$walletsTable} w
    LEFT JOIN (
        SELECT
            actor_key,
            SUM(CASE WHEN source = 'wallet_usage' THEN ABS(amount) ELSE 0 END) AS wallet_used_total,
            SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS credit_total,
            SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS debit_total,
            COUNT(*) AS tx_count
        FROM {$walletTxTable}
        GROUP BY actor_key
    ) tx ON tx.actor_key = w.actor_key
    {$walletWhere}
    ORDER BY w.updated_at DESC
    LIMIT %d";

$walletRowsParams[] = $walletLimit;
$walletRows = $wpdb->get_results($wpdb->prepare($walletSql, $walletRowsParams), ARRAY_A);
$updateState = get_option('yana_app_update_notice_state', []);
$homePopupState = yana_dashboard_get_home_popup_state();
$versionReminderTarget = trim((string) ($updateState['latest_version'] ?? ''));
if ($versionReminderTarget === '') {
    $versionReminderTarget = trim((string) ($updateState['min_version'] ?? ''));
}

?><!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Yana Live Dashboard</title>
    <style>
        :root {
            --bg: #f5efe6;
            --card: rgba(255, 255, 255, 0.92);
            --ink: #1f2937;
            --muted: #667085;
            --line: #eadfce;
            --accent: #c2410c;
            --accent-dark: #7c2d12;
            --accent-soft: #fff4ea;
            --good: #15803d;
            --bad: #b42318;
            --shadow: 0 18px 44px rgba(84, 49, 16, 0.08);
        }
        * { box-sizing: border-box; }
        html, body {
            width: 100%;
            min-width: 100%;
        }
        body {
            margin: 0;
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            background:
                radial-gradient(circle at top left, rgba(194, 65, 12, 0.10), transparent 24%),
                radial-gradient(circle at top right, rgba(22, 163, 74, 0.08), transparent 22%),
                linear-gradient(180deg, #fcfaf7 0%, var(--bg) 100%);
            color: var(--ink);
            overflow-x: hidden;
        }
        .wrap {
            width: 100vw;
            max-width: none;
            margin: 0;
            padding: 8px;
        }
        h1, h2 { margin: 0 0 12px; }
        h1 {
            font-size: clamp(30px, 4vw, 46px);
            line-height: 1.04;
            letter-spacing: -0.04em;
        }
        h2 {
            font-size: 20px;
        }
        .topbar, .grid, .section, .filters {
            display: grid;
            gap: 16px;
        }
        .topbar { grid-template-columns: 1.5fr 1fr; align-items: stretch; margin-bottom: 18px; }
        .grid { grid-template-columns: repeat(6, minmax(0, 1fr)); margin-bottom: 18px; }
        .card, .panel {
            background: var(--card);
            border: 1px solid var(--line);
            border-radius: 24px;
            padding: 20px;
            box-shadow: var(--shadow);
            backdrop-filter: blur(14px);
            overflow: hidden;
        }
        .metric {
            font-size: 34px;
            font-weight: 700;
            margin-top: 8px;
            letter-spacing: -0.04em;
        }
        .label, .muted { color: var(--muted); font-size: 13px; }
        .label {
            text-transform: uppercase;
            letter-spacing: 0.08em;
            font-weight: 700;
        }
        .filters {
            grid-template-columns: repeat(4, minmax(0, 1fr));
            margin-bottom: 18px;
        }
        .section {
            grid-template-columns: repeat(3, minmax(0, 1fr));
            margin-bottom: 18px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            min-width: 100%;
        }
        th, td {
            text-align: left;
            padding: 12px 10px;
            border-bottom: 1px solid #f3ebdf;
            vertical-align: top;
            font-size: 14px;
        }
        th {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: var(--muted);
            font-weight: 700;
            background: rgba(247, 242, 236, 0.8);
        }
        .pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 5px 10px;
            border-radius: 999px;
            background: var(--accent-soft);
            color: var(--accent);
            font-size: 12px;
            font-weight: 700;
        }
        .status-dot {
            display: inline-block;
            width: 10px;
            height: 10px;
            margin-right: 8px;
            border-radius: 50%;
            background: #16a34a;
            box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.16);
            vertical-align: middle;
        }
        .ok { color: var(--good); }
        .bad { color: var(--bad); }
        .table-wrap {
            overflow: auto;
            margin-top: 12px;
        }
        .table-wrap table {
            min-width: 680px;
        }
        input, button, select, textarea {
            width: 100%;
            border: 1px solid #d8cab6;
            border-radius: 12px;
            padding: 11px 12px;
            font: inherit;
            background: #fffdf9;
            color: var(--ink);
            transition: border-color 0.16s ease, box-shadow 0.16s ease, transform 0.16s ease;
        }
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: rgba(194, 65, 12, 0.6);
            box-shadow: 0 0 0 4px rgba(194, 65, 12, 0.10);
        }
        button {
            background: linear-gradient(135deg, var(--accent), var(--accent-dark));
            color: #fff;
            cursor: pointer;
            border: 0;
            font-weight: 700;
            box-shadow: 0 12px 24px rgba(194, 65, 12, 0.18);
        }
        button:hover {
            transform: translateY(-1px);
        }
        .btn-muted {
            background: linear-gradient(135deg, #475467, #344054);
            box-shadow: 0 12px 24px rgba(52, 64, 84, 0.18);
        }
        .wallet-form {
            display: grid;
            gap: 10px;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            align-items: end;
        }
        .wallet-table .actions form {
            display: grid;
            gap: 8px;
            grid-template-columns: 90px 1fr 110px;
            min-width: 360px;
        }
        .panel .actions form {
            display: grid;
            gap: 8px;
        }
        .panel .actions button {
            min-width: 140px;
        }
        .notice {
            margin-bottom: 14px;
            padding: 14px 16px;
            border-radius: 16px;
            box-shadow: var(--shadow);
            font-weight: 600;
        }
        .notice.ok { background: #ecfdf5; border: 1px solid #bbf7d0; }
        .notice.bad { background: #fef2f2; border: 1px solid #fecaca; }
        .hero-card {
            background: linear-gradient(135deg, rgba(194, 65, 12, 0.96), rgba(124, 45, 18, 0.94));
            color: #fff;
        }
        .hero-card .muted {
            color: rgba(255, 255, 255, 0.82);
            font-size: 15px;
            line-height: 1.65;
        }
        .toolbar-card {
            background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(255,250,244,0.9));
        }
        .metric-card {
            background: linear-gradient(180deg, rgba(255,255,255,0.98), rgba(255,249,242,0.96));
            min-height: 132px;
            position: relative;
        }
        .metric-card::before {
            content: "";
            position: absolute;
            inset: 0 0 auto 0;
            height: 4px;
            background: linear-gradient(90deg, var(--accent), #f59e0b);
        }
        .subhead p {
            margin: 4px 0 0;
            color: var(--muted);
            line-height: 1.55;
        }
        .split-inline {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
        }
        .layout-toolbar {
            display: flex;
            justify-content: flex-end;
            gap: 10px;
            margin: 0 0 12px;
        }
        .layout-toolbar button {
            width: auto;
            min-width: 0;
            padding: 10px 14px;
        }
        .layout-item {
            position: relative;
            min-width: 0;
        }
        .layout-actions {
            position: absolute;
            top: 10px;
            right: 10px;
            z-index: 3;
            display: flex;
            gap: 6px;
            flex-wrap: wrap;
            opacity: 0.25;
            transition: opacity 0.18s ease;
        }
        .layout-item:hover .layout-actions {
            opacity: 1;
        }
        .layout-actions button {
            width: auto;
            min-width: 34px;
            padding: 6px 8px;
            border-radius: 10px;
            font-size: 11px;
            line-height: 1;
            box-shadow: none;
            background: rgba(31, 41, 55, 0.9);
        }
        .layout-actions button[data-size].is-active {
            background: linear-gradient(135deg, var(--accent), var(--accent-dark));
        }
        .layout-note {
            margin: 0 0 10px;
            color: var(--muted);
            font-size: 12px;
        }
        .code {
            font-family: Consolas, "Courier New", monospace;
        }
        @media (max-width: 1100px) {
            .grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
            .section, .filters, .topbar { grid-template-columns: 1fr 1fr; }
        }
        @media (max-width: 700px) {
            .wrap { width: 100vw; margin-top: 0; padding: 4px; }
            .grid, .section, .filters, .topbar, .wallet-form { grid-template-columns: 1fr; }
            .wallet-table .actions form { grid-template-columns: 1fr; min-width: 0; }
            .metric { font-size: 28px; }
        }
    </style>
</head>
<body>
    <div class="wrap">
        <div class="layout-toolbar">
            <button class="btn-muted" type="button" id="reset_layout_btn">Reset Layout</button>
        </div>
        <p class="layout-note">Panel ke upar mouse le jao. Arrow se order badlo, `S/M/L` se width set karo. Layout browser me save rahega.</p>
        <div class="topbar">
            <div class="card hero-card">
                <h1>Yana App Standalone Dashboard</h1>
                <div class="muted">
                    Installs, live users, checkout flow, wallet controls, update popup aur push notifications ek hi page par manage karo.
                </div>
            </div>
            <div class="card toolbar-card">
                <div class="subhead">
                    <h2>Quick Filters</h2>
                    <p>Live data window aur wallet result size yahin se control hota hai.</p>
                </div>
                <form method="get" class="filters">
                    <div>
                        <div class="label">Active Window (minutes)</div>
                        <input type="number" name="active_minutes" min="5" max="120" value="<?php echo esc_attr((string) $activeMinutes); ?>">
                    </div>
                    <div>
                        <div class="label">Payment Window (hours)</div>
                        <input type="number" name="payment_hours" min="1" max="168" value="<?php echo esc_attr((string) $paymentHours); ?>">
                    </div>
                    <div>
                        <div class="label">Wallet Search</div>
                        <input type="text" name="q" value="<?php echo esc_attr($walletSearch); ?>" placeholder="user id / install id / actor key">
                    </div>
                    <div>
                        <div class="label">Wallet Rows</div>
                        <input type="number" name="wallet_limit" min="20" max="300" value="<?php echo esc_attr((string) $walletLimit); ?>">
                    </div>
                    <div style="grid-column: 1 / -1;">
                        <button type="submit">Refresh Dashboard</button>
                    </div>
                </form>
            </div>
        </div>

        <?php if ($walletMessage !== '') : ?>
            <div class="notice ok"><?php echo esc_html($walletMessage); ?></div>
        <?php endif; ?>
        <?php if ($walletError !== '') : ?>
            <div class="notice bad"><?php echo esc_html($walletError); ?></div>
        <?php endif; ?>
        <?php if ($pushMessage !== '') : ?>
            <div class="notice ok"><?php echo esc_html($pushMessage); ?></div>
        <?php endif; ?>
        <?php if ($pushError !== '') : ?>
            <div class="notice bad"><?php echo esc_html($pushError); ?></div>
        <?php endif; ?>
        <?php if ($updateMessage !== '') : ?>
            <div class="notice ok"><?php echo esc_html($updateMessage); ?></div>
        <?php endif; ?>
        <?php if ($updateError !== '') : ?>
            <div class="notice bad"><?php echo esc_html($updateError); ?></div>
        <?php endif; ?>
        <?php if ($homePopupMessage !== '') : ?>
            <div class="notice ok"><?php echo esc_html($homePopupMessage); ?></div>
        <?php endif; ?>
        <?php if ($homePopupError !== '') : ?>
            <div class="notice bad"><?php echo esc_html($homePopupError); ?></div>
        <?php endif; ?>
        <?php if ($bulkPushMessage !== '') : ?>
            <div class="notice ok"><?php echo esc_html($bulkPushMessage); ?></div>
        <?php endif; ?>
        <?php if ($bulkPushError !== '') : ?>
            <div class="notice bad"><?php echo esc_html($bulkPushError); ?></div>
        <?php endif; ?>
        <?php if ($couponMessage !== '') : ?>
            <div class="notice ok"><?php echo esc_html($couponMessage); ?></div>
        <?php endif; ?>
        <?php if ($couponError !== '') : ?>
            <div class="notice bad"><?php echo esc_html($couponError); ?></div>
        <?php endif; ?>

        <div class="grid">
            <div class="card metric-card"><div class="label">Tracked Installs</div><div class="metric"><?php echo esc_html((string) $summary['installs']); ?></div><div class="muted">Unique install IDs captured</div></div>
            <div class="card metric-card"><div class="label">Active Devices</div><div class="metric"><?php echo esc_html((string) $summary['active_devices']); ?></div><div class="muted">Live in last <?php echo esc_html((string) $activeMinutes); ?> min</div></div>
            <div class="card metric-card"><div class="label">Users With Wallet</div><div class="metric"><?php echo esc_html((string) $summary['wallet_users']); ?></div><div class="muted">Positive balance users</div></div>
            <div class="card"><div class="label">Total Wallet Balance</div><div class="metric">₹<?php echo esc_html(number_format((float) $summary['wallet_balance'], 2)); ?></div></div>
            <div class="card metric-card"><div class="label">Live Product Viewers</div><div class="metric"><?php echo esc_html((string) $summary['live_viewers']); ?></div><div class="muted">Users on product detail</div></div>
            <div class="card metric-card"><div class="label">Checkout Users</div><div class="metric"><?php echo esc_html((string) $summary['checkout_users']); ?></div><div class="muted">Reached checkout recently</div></div>
        </div>

        <div class="section">
            <div class="panel">
                <h2>Bulk Notification Center</h2>
                <div class="muted" style="margin-bottom:12px;">Yahan se English notification sab users ya selected audience ko bhej sakte ho.</div>
                <form method="post" class="wallet-form">
                    <?php wp_nonce_field('yana_bulk_push_action', 'yana_bulk_push_nonce'); ?>
                    <div>
                        <div class="label">Notification Type</div>
                        <select name="bulk_template" id="bulk_template" style="width:100%; border:1px solid #d8cab6; border-radius:12px; padding:10px 12px; font:inherit; background:#fff;">
                            <?php foreach (yana_dashboard_bulk_push_templates() as $templateKey => $templateValue) : ?>
                                <option value="<?php echo esc_attr($templateKey); ?>"><?php echo esc_html(ucwords(str_replace('_', ' ', $templateKey))); ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div>
                        <div class="label">Target</div>
                        <select name="bulk_target_mode" style="width:100%; border:1px solid #d8cab6; border-radius:12px; padding:10px 12px; font:inherit; background:#fff;">
                            <option value="all">All Users</option>
                            <option value="guest_only">Guest Only</option>
                        </select>
                    </div>
                    <div>
                        <div class="label">Audience Filter</div>
                        <select name="bulk_audience_filter" id="bulk_audience_filter" style="width:100%; border:1px solid #d8cab6; border-radius:12px; padding:10px 12px; font:inherit; background:#fff;">
                            <option value="any">Any</option>
                            <option value="cart">Cart Users</option>
                            <option value="product">Specific Product Viewers</option>
                            <option value="repeat_views">Product Interest Users</option>
                        </select>
                    </div>
                    <div>
                        <div class="label">Lookback Days</div>
                        <input type="number" name="bulk_lookback_days" value="7" min="1" max="60">
                    </div>
                    <div>
                        <div class="label">Title</div>
                        <input type="text" name="bulk_title" id="bulk_title" value="Please Check the App">
                    </div>
                    <div>
                        <div class="label">Message</div>
                        <input type="text" name="bulk_body" id="bulk_body" value="We have something important for you. Please open the app and take a look.">
                    </div>
                    <div>
                        <div class="label">Product ID</div>
                        <input type="number" name="bulk_product_id" placeholder="Only for specific product viewers">
                    </div>
                    <div>
                        <div class="label">Action</div>
                        <button type="submit" name="bulk_push_submit" value="1">Send To Audience</button>
                    </div>
                </form>
            </div>

            <div class="panel">
                <h2>App Update Control</h2>
                <div class="muted" style="margin-bottom:12px;">
                    Status:
                    <span class="<?php echo !empty($updateState['active']) ? 'ok' : 'bad'; ?>">
                        <?php echo !empty($updateState['active']) ? 'Active' : 'Inactive'; ?>
                    </span>
                </div>
                <form method="post" class="wallet-form">
                    <?php wp_nonce_field('yana_app_update_action', 'yana_app_update_nonce'); ?>
                    <div>
                        <div class="label">Title</div>
                        <input type="text" name="update_title" value="<?php echo esc_attr((string) ($updateState['title'] ?? 'Update Available')); ?>">
                    </div>
                    <div>
                        <div class="label">Button URL</div>
                        <input type="text" name="update_url" value="<?php echo esc_attr((string) ($updateState['url'] ?? '')); ?>">
                    </div>
                    <div>
                        <div class="label">Minimum Version</div>
                        <input type="text" name="update_min_version" value="<?php echo esc_attr((string) ($updateState['min_version'] ?? '')); ?>" placeholder="1.0.9">
                    </div>
                    <div>
                        <div class="label">Latest Version</div>
                        <input type="text" name="update_latest_version" value="<?php echo esc_attr((string) ($updateState['latest_version'] ?? '')); ?>" placeholder="1.0.9">
                    </div>
                    <div>
                        <div class="label">Message</div>
                        <input type="text" name="update_message" value="<?php echo esc_attr((string) ($updateState['message'] ?? 'Please update the app for the best experience.')); ?>">
                    </div>
                    <div>
                        <div class="label">Force Update</div>
                        <label style="display:flex;align-items:center;gap:8px;height:42px;">
                            <input type="checkbox" name="update_force" value="1" <?php checked(!empty($updateState['force_update'])); ?> style="width:auto;">
                            <span>Required update</span>
                        </label>
                    </div>
                    <div>
                        <div class="label">Action</div>
                        <button type="submit" name="app_update_submit" value="1">Activate Update Popup</button>
                        <input type="hidden" name="update_action" value="activate">
                    </div>
                </form>
                <form method="post" style="margin-top:10px;">
                    <?php wp_nonce_field('yana_app_update_action', 'yana_app_update_nonce'); ?>
                    <input type="hidden" name="update_action" value="deactivate">
                    <button type="submit" name="app_update_submit" value="1" style="background:#374151;">Deactivate Update Popup</button>
                </form>
            </div>

            <div class="panel">
                <h2>Home Popup Control</h2>
                <div class="muted" style="margin-bottom:12px;">
                    Status:
                    <span class="<?php echo !empty($homePopupState['active']) ? 'ok' : 'bad'; ?>">
                        <?php echo !empty($homePopupState['active']) ? 'Active' : 'Inactive'; ?>
                    </span>
                </div>
                <form method="post" class="wallet-form">
                    <?php wp_nonce_field('yana_home_popup_action', 'yana_home_popup_nonce'); ?>
                    <div>
                        <div class="label">Title</div>
                        <input type="text" name="home_popup_title" value="<?php echo esc_attr((string) ($homePopupState['title'] ?? 'Important Update')); ?>">
                    </div>
                    <div>
                        <div class="label">Message</div>
                        <textarea name="home_popup_message" rows="4" style="width:100%;border:1px solid var(--line);border-radius:14px;padding:12px 14px;font:inherit;resize:vertical;"><?php echo esc_textarea((string) ($homePopupState['message'] ?? '')); ?></textarea>
                    </div>
                    <div>
                        <div class="label">Button Text</div>
                        <input type="text" name="home_popup_button_text" value="<?php echo esc_attr((string) ($homePopupState['button_text'] ?? 'View Now')); ?>">
                    </div>
                    <div>
                        <div class="label">Action URL</div>
                        <input type="text" name="home_popup_action_url" value="<?php echo esc_attr((string) ($homePopupState['action_url'] ?? '')); ?>" placeholder="Optional deep link or https:// URL">
                    </div>
                    <div>
                        <div class="label">Action</div>
                        <button type="submit" name="home_popup_submit" value="1">Update Current Popup</button>
                        <button type="submit" name="home_popup_submit_action" value="activate_new" style="margin-top:8px;background:#c2410c;">Send As New Campaign</button>
                        <input type="hidden" name="home_popup_action" value="update_current">
                    </div>
                </form>
                <form method="post" style="margin-top:10px;">
                    <?php wp_nonce_field('yana_home_popup_action', 'yana_home_popup_nonce'); ?>
                    <input type="hidden" name="home_popup_action" value="deactivate">
                    <button type="submit" name="home_popup_submit" value="1" style="background:#374151;">Disable Home Popup</button>
                </form>
            </div>

            <div class="panel">
                <h2>Wallet Balance Check</h2>
                <form method="post" class="wallet-form">
                    <?php wp_nonce_field('yana_wallet_lookup_action', 'yana_wallet_lookup_nonce'); ?>
                    <div>
                        <div class="label">Actor Key</div>
                        <input type="text" name="lookup_actor_key" placeholder="u:123 or g:guest_xxx">
                    </div>
                    <div>
                        <div class="label">User ID</div>
                        <input type="number" name="lookup_user_id" placeholder="123">
                    </div>
                    <div>
                        <div class="label">Install ID</div>
                        <input type="text" name="lookup_install_id" placeholder="guest_xxx">
                    </div>
                    <div>
                        <div class="label">Action</div>
                        <button type="submit" name="wallet_lookup_submit" value="1">Check Balance</button>
                    </div>
                </form>
                <?php if (is_array($walletLookupResult)) :
                    $lookupIdentity = yana_dashboard_actor_label((int) ($walletLookupResult['user_id'] ?? 0), (string) ($walletLookupResult['install_id'] ?? ''));
                    ?>
                    <div style="margin-top:14px;">
                        <div><strong><?php echo esc_html($lookupIdentity['name']); ?></strong></div>
                        <div class="muted"><?php echo esc_html($lookupIdentity['email'] !== '' ? $lookupIdentity['email'] : $lookupIdentity['install_id']); ?></div>
                        <div style="margin-top:8px;"><strong>Balance:</strong> ₹<?php echo esc_html(number_format((float) ($walletLookupResult['balance'] ?? 0), 2)); ?></div>
                        <div><strong>Actor Key:</strong> <?php echo esc_html((string) ($walletLookupResult['actor_key'] ?? '')); ?></div>
                        <div><strong>Status:</strong> <?php echo !empty($walletLookupResult['banned']) ? 'Blocked' : 'Active'; ?></div>
                        <div><strong>Updated At:</strong> <?php echo esc_html((string) ($walletLookupResult['updated_at'] ?? '')); ?></div>
                    </div>
                <?php endif; ?>
            </div>

            <div class="panel">
                <h2>Quick Info</h2>
                <table>
                    <tbody>
                        <tr><th>Update Last Changed</th><td><?php echo esc_html((string) ($updateState['updated_at'] ?? '-')); ?></td></tr>
                        <tr><th>Current Update Title</th><td><?php echo esc_html((string) ($updateState['title'] ?? '-')); ?></td></tr>
                        <tr><th>Current Update Message</th><td><?php echo esc_html((string) ($updateState['message'] ?? '-')); ?></td></tr>
                        <tr><th>Current Update URL</th><td><?php echo esc_html((string) ($updateState['url'] ?? '-')); ?></td></tr>
                        <tr><th>Minimum Version</th><td><?php echo esc_html((string) ($updateState['min_version'] ?? '-')); ?></td></tr>
                        <tr><th>Latest Version</th><td><?php echo esc_html((string) ($updateState['latest_version'] ?? '-')); ?></td></tr>
                        <tr><th>Force Update</th><td><?php echo !empty($updateState['force_update']) ? 'Yes' : 'No'; ?></td></tr>
                        <tr><th>Home Popup Last Changed</th><td><?php echo esc_html((string) ($homePopupState['updated_at'] ?? '-')); ?></td></tr>
                        <tr><th>Home Popup Active</th><td><?php echo !empty($homePopupState['active']) ? 'Yes' : 'No'; ?></td></tr>
                        <tr><th>Current Popup Seen Users</th><td><?php echo esc_html((string) $currentPopupSeenCount); ?></td></tr>
                        <tr><th>Popup Title</th><td><?php echo esc_html((string) ($homePopupState['title'] ?? '-')); ?></td></tr>
                        <tr><th>Popup Message</th><td><?php echo esc_html((string) ($homePopupState['message'] ?? '-')); ?></td></tr>
                        <tr><th>Popup Button Text</th><td><?php echo esc_html((string) ($homePopupState['button_text'] ?? '-')); ?></td></tr>
                        <tr><th>Popup Action URL</th><td><?php echo esc_html((string) ($homePopupState['action_url'] ?? '-')); ?></td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <div class="panel">
                <h2>Home Popup Seen Users</h2>
                <table>
                    <thead><tr><th>User</th><th>Campaign ID</th><th>Popup Title</th><th>Viewed At</th><th>Last Action</th><th>Action Time</th></tr></thead>
                    <tbody>
                    <?php if (!$popupSeenRows) : ?>
                        <tr><td colspan="6" class="muted">Abhi tak kisi user ka popup view event nahi aaya.</td></tr>
                    <?php else : foreach ($popupSeenRows as $row) : ?>
                        <tr>
                            <td>
                                <strong><?php echo esc_html($row['identity']['name']); ?></strong><br>
                                <span class="muted"><?php echo esc_html($row['identity']['email'] !== '' ? $row['identity']['email'] : $row['identity']['install_id']); ?></span>
                            </td>
                            <td><?php echo esc_html((string) ($row['campaign_id'] ?? '-')); ?></td>
                            <td><?php echo esc_html((string) ($row['title'] ?? '-')); ?></td>
                            <td><?php echo esc_html((string) ($row['viewed_at'] ?? '-')); ?></td>
                            <td><?php echo esc_html((string) ($row['last_action'] ?? '-')); ?></td>
                            <td><?php echo esc_html((string) ($row['action_at'] ?? '-')); ?></td>
                        </tr>
                    <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>

            <div class="panel">
                <h2>Currently Active Users</h2>
                <table>
                    <thead><tr><th>User</th><th>Current Page</th><th>Last Product</th><th>Last Search</th><th>Time</th><th>Action</th></tr></thead>
                    <tbody>
                    <?php if (!$currentPageRows) : ?>
                        <tr><td colspan="6" class="muted">No active users in last <?php echo esc_html((string) $activeMinutes); ?> minutes.</td></tr>
                    <?php else : foreach ($currentPageRows as $row) : ?>
                        <tr>
                            <td>
                                <strong><span class="status-dot"></span><?php echo esc_html($row['identity']['name']); ?></strong><br>
                                <span class="muted"><?php echo esc_html($row['identity']['email'] !== '' ? $row['identity']['email'] : $row['identity']['install_id']); ?></span>
                            </td>
                            <td><?php echo esc_html($row['current_page']); ?></td>
                            <td><?php echo esc_html($row['last_product']); ?></td>
                            <td><?php echo esc_html($row['last_search']); ?></td>
                            <td><?php echo esc_html($row['seen_at']); ?></td>
                            <td class="actions">
                                <form method="post">
                                    <?php wp_nonce_field('yana_coupon_push_action', 'yana_coupon_push_nonce'); ?>
                                    <input type="hidden" name="actor_key" value="<?php echo esc_attr((string) ($row['identity']['actor_key'] ?? '')); ?>">
                                    <input type="hidden" name="user_id" value="<?php echo esc_attr((string) ((int) ($row['identity']['user_id'] ?? 0))); ?>">
                                    <input type="hidden" name="install_id" value="<?php echo esc_attr((string) ($row['identity']['install_id'] ?? '')); ?>">
                                    <button type="submit" name="coupon_push_submit" value="1">Send 2% Coupon</button>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>

            <div class="panel">
                <h2>Live Product View</h2>
                <table>
                    <thead><tr><th>User</th><th>Product</th><th>Time</th></tr></thead>
                    <tbody>
                    <?php if (!$liveProductRows) : ?>
                        <tr><td colspan="3" class="muted">No live product viewers in last <?php echo esc_html((string) $activeMinutes); ?> minutes.</td></tr>
                    <?php else : foreach ($liveProductRows as $row) : ?>
                        <tr>
                            <td>
                                <strong><span class="status-dot"></span><?php echo esc_html($row['identity']['name']); ?></strong><br>
                                <span class="muted"><?php echo esc_html($row['identity']['email'] !== '' ? $row['identity']['email'] : $row['identity']['install_id']); ?></span>
                            </td>
                            <td><?php echo esc_html($row['product_name']); ?></td>
                            <td><?php echo esc_html($row['seen_at']); ?></td>
                        </tr>
                    <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>

            <div class="panel">
                <h2>Checkout Right Now</h2>
                <table>
                    <thead><tr><th>User</th><th>Amount</th><th>Time</th></tr></thead>
                    <tbody>
                    <?php if (!$checkoutRows) : ?>
                        <tr><td colspan="3" class="muted">No checkout activity in last <?php echo esc_html((string) $activeMinutes); ?> minutes.</td></tr>
                    <?php else : foreach ($checkoutRows as $row) : ?>
                        <tr>
                            <td>
                                <strong><span class="status-dot"></span><?php echo esc_html($row['identity']['name']); ?></strong><br>
                                <span class="muted"><?php echo esc_html($row['identity']['email'] !== '' ? $row['identity']['email'] : $row['identity']['install_id']); ?></span>
                            </td>
                            <td>₹<?php echo esc_html(number_format((float) $row['amount'], 2)); ?></td>
                            <td><?php echo esc_html($row['seen_at']); ?></td>
                        </tr>
                    <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>

            <div class="panel">
                <h2>Payment Failed</h2>
                <div class="pill"><?php echo esc_html((string) $summary['payment_failed']); ?> failures in last <?php echo esc_html((string) $paymentHours); ?> hours</div>
                <table>
                    <thead><tr><th>User</th><th>Status</th><th>Method</th><th>Amount</th></tr></thead>
                    <tbody>
                    <?php if (!$paymentFailureRows) : ?>
                        <tr><td colspan="4" class="muted">No payment failure event found.</td></tr>
                    <?php else : foreach ($paymentFailureRows as $row) : ?>
                        <tr>
                            <td>
                                <strong><?php echo esc_html($row['identity']['name']); ?></strong><br>
                                <span class="muted"><?php echo esc_html($row['identity']['email'] !== '' ? $row['identity']['email'] : $row['identity']['install_id']); ?></span>
                            </td>
                            <td class="bad"><?php echo esc_html($row['status']); ?></td>
                            <td><?php echo esc_html($row['method']); ?></td>
                            <td>₹<?php echo esc_html(number_format((float) $row['amount'], 2)); ?></td>
                        </tr>
                    <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <div class="panel wallet-table">
            <h2>Wallet Control</h2>
            <div class="muted" style="margin-bottom: 12px;">Yahan se kisi bhi user ka wallet balance kam ya zyada kar sakte hain.</div>
            <table>
                <thead>
                    <tr>
                        <th>User</th>
                        <th>App Version</th>
                        <th>Wallet</th>
                        <th>Used</th>
                        <th>Credits</th>
                        <th>Debits</th>
                        <th>Updated</th>
                        <th>Wallet Action</th>
                        <th>Push Notification</th>
                        <th>2% Coupon</th>
                        <th>Update Reminder</th>
                    </tr>
                </thead>
                <tbody>
                <?php if (!$walletRows) : ?>
                    <tr><td colspan="11" class="muted">No wallet rows found.</td></tr>
                <?php else : foreach ($walletRows as $row) :
                    $identity = yana_dashboard_actor_label((int) ($row['user_id'] ?? 0), (string) ($row['install_id'] ?? ''));
                    $currentVersion = trim((string) ($row['app_version'] ?? ''));
                    $versionSeenAt = trim((string) ($row['app_version_seen_at'] ?? ''));
                    $isOutdatedVersion = yana_dashboard_is_outdated_version($currentVersion, $versionReminderTarget);
                    $versionPushTitle = $isOutdatedVersion ? 'Old Version Detected' : 'Update Yana App';
                    $versionPushBody = $versionReminderTarget !== ''
                        ? sprintf(
                            'You are using old version %s of YanaWorldwide app. Please update to version %s from Play Store.',
                            $currentVersion !== '' ? $currentVersion : 'unknown',
                            $versionReminderTarget
                        )
                        : 'Please update YanaWorldwide app from Play Store for the latest fixes and features.';
                    ?>
                    <tr>
                        <td>
                            <strong><?php echo esc_html($identity['name']); ?></strong><br>
                            <span class="muted"><?php echo esc_html($identity['email'] !== '' ? $identity['email'] : $identity['install_id']); ?></span><br>
                            <span class="pill"><?php echo esc_html((string) ($row['actor_key'] ?? '')); ?></span>
                        </td>
                        <td>
                            <strong class="<?php echo $isOutdatedVersion ? 'bad' : 'ok'; ?>">
                                <?php echo esc_html($currentVersion !== '' ? $currentVersion : 'Unknown'); ?>
                            </strong><br>
                            <span class="muted"><?php echo esc_html($versionSeenAt !== '' ? 'Seen: ' . $versionSeenAt : 'No version telemetry yet'); ?></span>
                            <?php if ($isOutdatedVersion) : ?>
                                <br><span class="pill">Needs update to <?php echo esc_html($versionReminderTarget); ?></span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <strong><?php if (isset($activeActorKeys[(string) ($row['actor_key'] ?? '')])) : ?><span class="status-dot"></span><?php endif; ?>₹<?php echo esc_html(number_format((float) ($row['balance'] ?? 0), 2)); ?></strong><br>
                            <span class="<?php echo !empty($row['banned']) ? 'bad' : 'ok'; ?>"><?php echo !empty($row['banned']) ? 'Blocked' : 'Active'; ?></span>
                        </td>
                        <td>₹<?php echo esc_html(number_format((float) ($row['wallet_used_total'] ?? 0), 2)); ?></td>
                        <td>₹<?php echo esc_html(number_format((float) ($row['credit_total'] ?? 0), 2)); ?></td>
                        <td>₹<?php echo esc_html(number_format((float) ($row['debit_total'] ?? 0), 2)); ?></td>
                        <td><?php echo esc_html((string) ($row['updated_at'] ?? '')); ?></td>
                        <td class="actions">
                            <form method="post">
                                <?php wp_nonce_field('yana_wallet_adjust_action', 'yana_wallet_adjust_nonce'); ?>
                                <input type="hidden" name="actor_key" value="<?php echo esc_attr((string) ($row['actor_key'] ?? '')); ?>">
                                <input type="hidden" name="user_id" value="<?php echo esc_attr((string) ((int) ($row['user_id'] ?? 0))); ?>">
                                <input type="hidden" name="install_id" value="<?php echo esc_attr((string) ($row['install_id'] ?? '')); ?>">
                                <input type="text" name="delta_amount" placeholder="+200 or -100" required>
                                <input type="text" name="note" placeholder="note">
                                <button type="submit" name="wallet_adjust_submit" value="1">Update</button>
                            </form>
                        </td>
                        <td class="actions">
                            <form method="post">
                                <?php wp_nonce_field('yana_push_send_action', 'yana_push_send_nonce'); ?>
                                <input type="hidden" name="actor_key" value="<?php echo esc_attr((string) ($row['actor_key'] ?? '')); ?>">
                                <select name="push_type" style="width:100%; border:1px solid #d8cab6; border-radius:12px; padding:10px 12px; font:inherit; background:#fff;">
                                    <?php foreach (yana_dashboard_push_templates() as $templateKey => $templateValue) : ?>
                                        <option value="<?php echo esc_attr($templateKey); ?>"><?php echo esc_html($templateKey); ?></option>
                                    <?php endforeach; ?>
                                </select>
                                <input type="text" name="push_title" placeholder="title" value="Yana Update" required>
                                <input type="text" name="push_body" placeholder="message" value="Aapke liye ek update hai. App check kijiye." required>
                                <button type="submit" name="push_send_submit" value="1">Send Push</button>
                            </form>
                        </td>
                        <td class="actions">
                            <form method="post">
                                <?php wp_nonce_field('yana_coupon_push_action', 'yana_coupon_push_nonce'); ?>
                                <input type="hidden" name="actor_key" value="<?php echo esc_attr((string) ($row['actor_key'] ?? '')); ?>">
                                <input type="hidden" name="user_id" value="<?php echo esc_attr((string) ((int) ($row['user_id'] ?? 0))); ?>">
                                <input type="hidden" name="install_id" value="<?php echo esc_attr((string) ($row['install_id'] ?? '')); ?>">
                                <button type="submit" name="coupon_push_submit" value="1">Send 2% Coupon</button>
                            </form>
                        </td>
                        <td class="actions">
                            <form method="post">
                                <?php wp_nonce_field('yana_version_push_action', 'yana_version_push_nonce'); ?>
                                <input type="hidden" name="actor_key" value="<?php echo esc_attr((string) ($row['actor_key'] ?? '')); ?>">
                                <input type="hidden" name="current_version" value="<?php echo esc_attr($currentVersion); ?>">
                                <input type="hidden" name="target_version" value="<?php echo esc_attr($versionReminderTarget); ?>">
                                <input type="text" name="version_push_title" value="<?php echo esc_attr($versionPushTitle); ?>" required>
                                <input type="text" name="version_push_body" value="<?php echo esc_attr($versionPushBody); ?>" required>
                                <button type="submit" name="version_push_submit" value="1" <?php disabled($currentVersion === ''); ?>>Notify Update</button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <script>
        (function () {
            var forms = document.querySelectorAll('form');
            var templates = <?php echo wp_json_encode(yana_dashboard_push_templates()); ?>;
            var bulkTemplates = <?php echo wp_json_encode(yana_dashboard_bulk_push_templates()); ?>;
            forms.forEach(function (form) {
                var typeField = form.querySelector('select[name="push_type"]');
                var titleField = form.querySelector('input[name="push_title"]');
                var bodyField = form.querySelector('input[name="push_body"]');
                if (!typeField || !titleField || !bodyField) {
                    return;
                }
                typeField.addEventListener('change', function () {
                    var selected = templates[typeField.value];
                    if (!selected) {
                        return;
                    }
                    titleField.value = selected.title || '';
                    bodyField.value = selected.body || '';
                });
            });

            var bulkTemplateField = document.getElementById('bulk_template');
            var bulkTitleField = document.getElementById('bulk_title');
            var bulkBodyField = document.getElementById('bulk_body');
            var bulkAudienceField = document.getElementById('bulk_audience_filter');
            if (bulkTemplateField && bulkTitleField && bulkBodyField && bulkAudienceField) {
                bulkTemplateField.addEventListener('change', function () {
                    var selectedBulk = bulkTemplates[bulkTemplateField.value];
                    if (!selectedBulk) {
                        return;
                    }
                    bulkTitleField.value = selectedBulk.title || '';
                    bulkBodyField.value = selectedBulk.body || '';
                    bulkAudienceField.value = selectedBulk.audience_filter || 'any';
                });
            }
        }());

        (function () {
            var storageKey = 'yana_dashboard_layout_v1';
            var resetBtn = document.getElementById('reset_layout_btn');
            var containers = [
                { el: document.querySelector('.topbar'), key: 'topbar', maxSpan: 2 },
                { el: document.querySelector('.grid'), key: 'metrics', maxSpan: 3 },
                { el: document.querySelectorAll('.section')[0], key: 'section_primary', maxSpan: 3 },
                { el: document.querySelectorAll('.section')[1], key: 'section_live', maxSpan: 3 }
            ].filter(function (item) { return !!item.el; });

            function loadState() {
                try {
                    return JSON.parse(localStorage.getItem(storageKey) || '{}') || {};
                } catch (_) {
                    return {};
                }
            }

            function saveState(state) {
                localStorage.setItem(storageKey, JSON.stringify(state));
            }

            function childSelector(containerEl) {
                return Array.prototype.slice.call(containerEl.children).filter(function (node) {
                    return node.classList.contains('card') || node.classList.contains('panel');
                });
            }

            function ensureControls(item, maxSpan) {
                if (item.querySelector('.layout-actions')) {
                    return;
                }
                item.classList.add('layout-item');
                var controls = document.createElement('div');
                controls.className = 'layout-actions';
                controls.innerHTML =
                    '<button type="button" data-action="prev" title="Move Left">&larr;</button>' +
                    '<button type="button" data-action="next" title="Move Right">&rarr;</button>' +
                    '<button type="button" data-size="1">S</button>' +
                    '<button type="button" data-size="' + Math.min(2, maxSpan) + '">M</button>' +
                    '<button type="button" data-size="' + maxSpan + '">L</button>';
                item.insertBefore(controls, item.firstChild);
            }

            function applyState() {
                var state = loadState();
                containers.forEach(function (container, containerIndex) {
                    var items = childSelector(container.el);
                    items.forEach(function (item, itemIndex) {
                        if (!item.dataset.layoutId) {
                            item.dataset.layoutId = container.key + '_' + itemIndex;
                        }
                        ensureControls(item, container.maxSpan);
                    });

                    var saved = state[container.key] || {};
                    var itemsById = {};
                    items.forEach(function (item) {
                        itemsById[item.dataset.layoutId] = item;
                    });

                    if (Array.isArray(saved.order)) {
                        saved.order.forEach(function (id) {
                            if (itemsById[id]) {
                                container.el.appendChild(itemsById[id]);
                            }
                        });
                    }

                    childSelector(container.el).forEach(function (item) {
                        var span = saved.spans && saved.spans[item.dataset.layoutId]
                            ? parseInt(saved.spans[item.dataset.layoutId], 10)
                            : 1;
                        if (!span || span < 1) span = 1;
                        if (span > container.maxSpan) span = container.maxSpan;
                        item.style.gridColumn = 'span ' + span;

                        var buttons = item.querySelectorAll('.layout-actions button[data-size]');
                        buttons.forEach(function (btn) {
                            btn.classList.toggle('is-active', parseInt(btn.dataset.size, 10) === span);
                        });
                    });
                });
            }

            function persistContainer(container) {
                var state = loadState();
                var items = childSelector(container.el);
                state[container.key] = state[container.key] || { order: [], spans: {} };
                state[container.key].order = items.map(function (item) { return item.dataset.layoutId; });
                items.forEach(function (item) {
                    var span = 1;
                    var match = /span\s+(\d+)/.exec(item.style.gridColumn || '');
                    if (match) {
                        span = parseInt(match[1], 10) || 1;
                    }
                    state[container.key].spans[item.dataset.layoutId] = span;
                });
                saveState(state);
            }

            containers.forEach(function (container) {
                container.el.addEventListener('click', function (event) {
                    var btn = event.target.closest('.layout-actions button');
                    if (!btn) return;
                    var item = event.target.closest('.layout-item');
                    if (!item) return;

                    if (btn.dataset.action === 'prev' && item.previousElementSibling) {
                        container.el.insertBefore(item, item.previousElementSibling);
                        persistContainer(container);
                        applyState();
                        return;
                    }
                    if (btn.dataset.action === 'next' && item.nextElementSibling) {
                        container.el.insertBefore(item.nextElementSibling, item);
                        persistContainer(container);
                        applyState();
                        return;
                    }
                    if (btn.dataset.size) {
                        var span = parseInt(btn.dataset.size, 10) || 1;
                        if (span > container.maxSpan) span = container.maxSpan;
                        item.style.gridColumn = 'span ' + span;
                        persistContainer(container);
                        applyState();
                    }
                });
            });

            if (resetBtn) {
                resetBtn.addEventListener('click', function () {
                    localStorage.removeItem(storageKey);
                    window.location.reload();
                });
            }

            applyState();
        }());
        setTimeout(function () {
            if (window.location.search.indexOf('no_auto_refresh=1') !== -1) {
                return;
            }
            window.location.reload();
        }, 30000);
    </script>
</body>
</html>
