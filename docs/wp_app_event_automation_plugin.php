<?php
/**
 * Plugin Name: Yana App Event Automation
 * Description: Hybrid notifier: topic push for order updates + token push for guest/user automations + live analytics.
 * Version: 1.2.0
 */

if (!defined('ABSPATH')) {
    exit;
}

final class Yana_App_Event_Automation {
    private const NS = 'wp/v1';
    private const ADMIN_NS = 'yana-admin/v1';
    private const ROUTE = '/app-event';
    private const MENU = 'yana-master-manager';

    private const OPT_APP_KEY = 'yana_app_ingest_key';
    private const OPT_SA_PATH = 'yana_fcm_service_account_path';
    private const OPT_UPDATE_NOTICE_STATE = 'yana_app_update_notice_state';
    private const OPT_HOME_POPUP_STATE = 'yana_home_popup_state';
    private const OPT_WALLET_SETTINGS = 'yana_wallet_settings';
    private const OPT_GATEWAY_SETTINGS = 'yana_gateway_settings';

    private const EVENTS = 'yana_app_events';
    private const TOKENS = 'yana_push_tokens';
    private const WALLETS = 'yana_wallets';
    private const WALLETS_TX = 'yana_wallet_transactions';

    private const DEF_APP_KEY = 'YANAWORLDWIDE_8f3K@29xP!mQ2026';
    private const DEF_SA_PATH = '/home/u390120805/domains/yanaworldwide.store/public_html/fire/service-account.json';
    private const DEF_UPDATE_NOTICE_URL = 'https://play.google.com/store/apps/details?id=com.yanaworldwide.shop&pcampaignid=web_share';
    private const TOKEN_CACHE = 'yana_fcm_v1_access_token';
    private const PRIVILEGED_ADMIN_EMAIL = '';
    private const CLEANUP_HOOK = 'yana_event_automation_cleanup';
    private const EVENTS_RETENTION_DAYS = 30;
    private const TOKENS_RETENTION_DAYS = 90;
    private const LIVE_REFRESH_DEFAULT = 60;
    private const MAX_ACTOR_SCAN_ROWS = 1000;
    private const MAX_CAMPAIGN_TARGETS = 1000;
    private const MAX_PUSH_TOKENS_PER_TARGET = 8;
    private const ADMIN_ORDERS_TOPIC = 'admin_orders';

    private static ?array $runtimeServiceAccount = null;
    private static ?string $runtimeAccessToken = null;

    public static function bootstrap(): void {
        add_action('rest_api_init', [self::class, 'register_routes']);
        add_action('admin_menu', [self::class, 'register_admin_menu']);
        add_action('woocommerce_new_order', [self::class, 'notify_new_order'], 10, 1);
        add_action('woocommerce_order_status_changed', [self::class, 'notify_order_status_changed'], 10, 4);
        add_action('yana_send_scheduled_campaign', [self::class, 'handle_scheduled_campaign'], 10, 1);
        add_action(self::CLEANUP_HOOK, [self::class, 'cleanup_old_data']);
        add_action('init', [self::class, 'maybe_upgrade_schema']);
    }

    public static function activate(): void {
        global $wpdb;
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';

        $charset = $wpdb->get_charset_collate();
        $events = $wpdb->prefix . self::EVENTS;
        $tokens = $wpdb->prefix . self::TOKENS;
        $wallets = $wpdb->prefix . self::WALLETS;
        $walletTx = $wpdb->prefix . self::WALLETS_TX;

        dbDelta("CREATE TABLE {$events} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            event_name VARCHAR(80) NOT NULL,
            user_id BIGINT UNSIGNED NULL,
            install_id VARCHAR(120) NULL,
            order_id BIGINT UNSIGNED NULL,
            product_id BIGINT UNSIGNED NULL,
            payload LONGTEXT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_event_name (event_name),
            KEY idx_user_id (user_id),
            KEY idx_install_id (install_id),
            KEY idx_created_at (created_at)
        ) {$charset};");

        dbDelta("CREATE TABLE {$tokens} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NULL,
            install_id VARCHAR(120) NULL,
            fcm_token VARCHAR(255) NOT NULL,
            platform VARCHAR(20) NULL,
            app_version VARCHAR(40) NULL,
            last_seen DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_fcm_token (fcm_token),
            KEY idx_user_id (user_id),
            KEY idx_install_id (install_id),
            KEY idx_last_seen (last_seen)
        ) {$charset};");

        dbDelta("CREATE TABLE {$wallets} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NULL,
            install_id VARCHAR(120) NULL,
            actor_key VARCHAR(150) NOT NULL,
            balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            banned TINYINT(1) NOT NULL DEFAULT 0,
            bonus_granted TINYINT(1) NOT NULL DEFAULT 0,
            is_merged TINYINT(1) NOT NULL DEFAULT 0,
            merged_to_actor VARCHAR(150) NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_actor_key (actor_key),
            KEY idx_user_id (user_id),
            KEY idx_install_id (install_id),
            KEY idx_banned (banned),
            KEY idx_is_merged (is_merged),
            KEY idx_merged_to_actor (merged_to_actor)
        ) {$charset};");

        dbDelta("CREATE TABLE {$walletTx} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            actor_key VARCHAR(150) NOT NULL,
            linked_actor VARCHAR(150) NULL,
            tx_type VARCHAR(40) NOT NULL,
            amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            balance_after DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            source VARCHAR(80) NOT NULL,
            meta LONGTEXT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_actor_key (actor_key),
            KEY idx_linked_actor (linked_actor),
            KEY idx_created_at (created_at)
        ) {$charset};");

        if (!get_option(self::OPT_APP_KEY)) {
            add_option(self::OPT_APP_KEY, self::DEF_APP_KEY);
        }
        if (!get_option(self::OPT_SA_PATH)) {
            add_option(self::OPT_SA_PATH, self::DEF_SA_PATH);
        }
        if (!get_option(self::OPT_UPDATE_NOTICE_STATE)) {
            add_option(self::OPT_UPDATE_NOTICE_STATE, [
                'campaign_id' => 0,
                'active' => false,
                'title' => 'Update Available',
                'message' => 'Please update the app for the best experience.',
                'url' => self::DEF_UPDATE_NOTICE_URL,
                'min_version' => '',
                'latest_version' => '',
                'force_update' => false,
                'updated_at' => current_time('mysql'),
            ]);
        }
        if (!get_option(self::OPT_HOME_POPUP_STATE)) {
            add_option(self::OPT_HOME_POPUP_STATE, [
                'campaign_id' => 0,
                'active' => false,
                'title' => 'Important Update',
                'message' => '',
                'button_text' => 'Got it',
                'action_url' => '',
                'updated_at' => current_time('mysql'),
            ]);
        }
        if (!get_option(self::OPT_WALLET_SETTINGS)) {
            add_option(self::OPT_WALLET_SETTINGS, [
                'enabled' => true,
                'signup_bonus' => 200,
                'min_billing' => 2000,
            ]);
        }
        if (!get_option(self::OPT_GATEWAY_SETTINGS)) {
            add_option(self::OPT_GATEWAY_SETTINGS, [
                'cashfree_enabled' => true,
                'payu_enabled' => true,
            ]);
        }

        if (!wp_next_scheduled(self::CLEANUP_HOOK)) {
            wp_schedule_event(time() + HOUR_IN_SECONDS, 'hourly', self::CLEANUP_HOOK);
        }
    }

    public static function maybe_upgrade_schema(): void {
        global $wpdb;

        $tokens = $wpdb->prefix . self::TOKENS;
        $tableExists = $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $tokens));
        if ($tableExists !== $tokens) {
            return;
        }

        $column = $wpdb->get_var($wpdb->prepare("SHOW COLUMNS FROM {$tokens} LIKE %s", 'app_version'));
        if ($column === 'app_version') {
            return;
        }

        $wpdb->query("ALTER TABLE {$tokens} ADD COLUMN app_version VARCHAR(40) NULL AFTER platform");
    }

    public static function deactivate(): void {
        $next = wp_next_scheduled(self::CLEANUP_HOOK);
        if ($next) {
            wp_unschedule_event($next, self::CLEANUP_HOOK);
        }
    }

    public static function register_admin_menu(): void {
        if (!self::is_privileged_admin()) {
            return;
        }
        add_menu_page('Yana Master Manager', 'Yana Master Manager', 'manage_options', self::MENU, [self::class, 'render_admin_page'], 'dashicons-megaphone', 56);
        add_submenu_page(self::MENU, 'Live Analytics', 'Live Analytics', 'manage_options', self::MENU . '-live', [self::class, 'render_live_page']);
        add_submenu_page(self::MENU, 'Bulk Campaigns', 'Bulk Campaigns', 'manage_options', self::MENU . '-bulk', [self::class, 'render_bulk_campaign_page']);
        add_submenu_page(self::MENU, 'Wallet Manager', 'Wallet Manager', 'manage_options', self::MENU . '-wallet', [self::class, 'render_wallet_page']);
        add_submenu_page(self::MENU, 'User Credits', 'User Credits', 'manage_options', self::MENU . '-user-credits', [self::class, 'render_user_credits_page']);
    }

    public static function render_admin_page(): void {
        self::enforce_privileged_admin();

        if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['yana_save_settings'])) {
            check_admin_referer('yana_save_settings', 'yana_nonce');
            update_option(self::OPT_APP_KEY, sanitize_text_field((string) wp_unslash($_POST['yana_app_key'] ?? '')));
            update_option(self::OPT_SA_PATH, sanitize_text_field((string) wp_unslash($_POST['yana_sa_path'] ?? '')));
            delete_transient(self::TOKEN_CACHE);
            echo '<div class="notice notice-success"><p>Settings saved.</p></div>';
        }

        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $tokensTable = $wpdb->prefix . self::TOKENS;
        $eventsCount = (int) $wpdb->get_var("SELECT COUNT(1) FROM {$eventsTable}");
        $tokensCount = (int) $wpdb->get_var("SELECT COUNT(1) FROM {$tokensTable}");
        $appKey = (string) get_option(self::OPT_APP_KEY, self::DEF_APP_KEY);
        $saPath = (string) get_option(self::OPT_SA_PATH, self::DEF_SA_PATH);
        ?>
        <div class="wrap">
            <h1>Yana Master Manager</h1>
            <p>Hybrid mode active: topic + token push (FCM HTTP v1).</p>
            <p><strong>Events:</strong> <?php echo esc_html((string) $eventsCount); ?> | <strong>Tokens:</strong> <?php echo esc_html((string) $tokensCount); ?></p>
            <form method="post">
                <?php wp_nonce_field('yana_save_settings', 'yana_nonce'); ?>
                <table class="form-table">
                    <tr>
                        <th>App Ingest Key</th>
                        <td><input class="regular-text" name="yana_app_key" value="<?php echo esc_attr($appKey); ?>" /></td>
                    </tr>
                    <tr>
                        <th>Service Account JSON Path</th>
                        <td><input class="regular-text" style="width:520px" name="yana_sa_path" value="<?php echo esc_attr($saPath); ?>" /></td>
                    </tr>
                </table>
                <p><button class="button button-primary" name="yana_save_settings">Save Settings</button></p>
            </form>
        </div>
        <?php
    }

    public static function render_live_page(): void {
        self::enforce_privileged_admin();
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $minutes = isset($_GET['minutes']) ? max(5, min(240, absint($_GET['minutes']))) : 30;
        $limit = isset($_GET['limit']) ? max(20, min(100, absint($_GET['limit']))) : 50;
        $shouldLoad = isset($_GET['refresh']) && (string) $_GET['refresh'] === '1';
        $rows = [];
        if ($shouldLoad) {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT id,event_name,user_id,install_id,created_at,LEFT(payload, 500) AS payload
                     FROM {$eventsTable}
                     WHERE created_at >= (NOW() - INTERVAL %d MINUTE)
                     ORDER BY id DESC LIMIT %d",
                    $minutes,
                    $limit
                ),
                ARRAY_A
            );
        }
        ?>
        <div class="wrap">
            <h1>Live Analytics</h1>
            <form method="get">
                <input type="hidden" name="page" value="<?php echo esc_attr(self::MENU . '-live'); ?>" />
                <label>Window (minutes)</label>
                <input type="number" name="minutes" value="<?php echo esc_attr((string) $minutes); ?>" />
                <label style="margin-left:12px;">Rows</label>
                <input type="number" name="limit" min="20" max="100" value="<?php echo esc_attr((string) $limit); ?>" />
                <button class="button button-primary" type="submit" name="refresh" value="1">Apply</button>
                <button class="button" type="submit" name="refresh" value="1">Refresh Now</button>
            </form>
            <p><em>Auto-refresh disabled. Data will update only when you click Refresh/Apply.</em></p>
            <?php if (!$shouldLoad) : ?>
                <p><strong>Click "Refresh Now" to load live data.</strong></p>
            <?php endif; ?>
            <table class="widefat striped">
                <thead><tr><th>ID</th><th>Time</th><th>Event</th><th>User/Install</th><th>Payload</th></tr></thead>
                <tbody>
                <?php if (!$shouldLoad) : ?>
                    <tr><td colspan="5">Data not loaded yet. Click Refresh Now.</td></tr>
                <?php elseif (empty($rows)) : ?>
                    <tr><td colspan="5">No events.</td></tr>
                <?php else : foreach ($rows as $r) : ?>
                    <tr>
                        <td><?php echo esc_html((string) $r['id']); ?></td>
                        <td><?php echo esc_html((string) $r['created_at']); ?></td>
                        <td><?php echo esc_html((string) $r['event_name']); ?></td>
                        <td><?php echo esc_html((string) (!empty($r['user_id']) ? 'u:' . $r['user_id'] : 'g:' . ($r['install_id'] ?? ''))); ?></td>
                        <td><code><?php echo esc_html(wp_trim_words((string) ($r['payload'] ?? ''), 20, '...')); ?></code></td>
                    </tr>
                <?php endforeach; endif; ?>
                </tbody>
            </table>
        </div>
        <?php
    }

    public static function render_bulk_campaign_page(): void {
        self::enforce_privileged_admin();

        $message = '';
        if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['yana_bulk_action'])) {
            check_admin_referer('yana_bulk_campaign', 'yana_bulk_nonce');
            $action = sanitize_key((string) wp_unslash($_POST['yana_bulk_action']));

            if ($action === 'cart') {
                $days = max(1, min(30, absint((int) ($_POST['cart_days'] ?? 3))));
                $result = self::send_bulk_cart_recovery($days);
                $message = sprintf(
                    'Cart recovery sent. Targets: %d, attempted: %d, skipped(no coupon): %d.',
                    $result['targets'],
                    $result['attempted'],
                    $result['skipped']
                );
            } elseif ($action === 'repeat_views') {
                $result = self::send_bulk_repeat_view_recovery();
                $message = sprintf(
                    'Repeat-view campaign sent. Targets: %d, attempted: %d, skipped(no coupon): %d.',
                    $result['targets'],
                    $result['attempted'],
                    $result['skipped']
                );
            }
        }

        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $cartCandidates = (int) $wpdb->get_var(
            "SELECT COUNT(*) FROM (
                SELECT
                    CASE
                        WHEN user_id IS NOT NULL AND user_id > 0 THEN CONCAT('u:', user_id)
                        ELSE CONCAT('g:', install_id)
                    END AS actor_key
                FROM {$eventsTable}
                WHERE event_name IN ('cart_add','add_to_cart','cart_updated')
                  AND created_at >= (NOW() - INTERVAL 3 DAY)
                  AND (
                    (user_id IS NOT NULL AND user_id > 0)
                    OR (install_id IS NOT NULL AND install_id <> '')
                  )
                GROUP BY actor_key
            ) t"
        );
        $repeatCandidates = (int) $wpdb->get_var(
            "SELECT COUNT(*) FROM (
                SELECT
                    CASE
                        WHEN user_id IS NOT NULL AND user_id > 0 THEN CONCAT('u:', user_id)
                        ELSE CONCAT('g:', install_id)
                    END AS actor_key
                FROM {$eventsTable}
                WHERE event_name IN ('product_view','view_item')
                  AND created_at >= CURDATE()
                  AND product_id IS NOT NULL
                  AND product_id > 0
                  AND (
                    (user_id IS NOT NULL AND user_id > 0)
                    OR (install_id IS NOT NULL AND install_id <> '')
                  )
                GROUP BY actor_key, product_id
                HAVING COUNT(*) >= 3
            ) t"
        );
        ?>
        <div class="wrap">
            <h1>Bulk Campaigns</h1>
            <p>2% coupon ke saath bulk notifications bhejne ke liye ye page use karein.</p>
            <?php if ($message !== '') : ?>
                <div class="notice notice-success"><p><?php echo esc_html($message); ?></p></div>
            <?php endif; ?>

            <div class="postbox" style="padding:16px; margin-top:16px;">
                <h2>Abandoned Cart Push</h2>
                <p>Estimate targets (last 3 days cart activity): <strong><?php echo esc_html((string) $cartCandidates); ?></strong></p>
                <form method="post">
                    <?php wp_nonce_field('yana_bulk_campaign', 'yana_bulk_nonce'); ?>
                    <input type="hidden" name="yana_bulk_action" value="cart" />
                    <label>Lookback Days</label>
                    <input type="number" min="1" max="30" name="cart_days" value="3" />
                    <button class="button button-primary" type="submit">Send to Cart Users with 2% Coupon</button>
                </form>
            </div>

            <div class="postbox" style="padding:16px; margin-top:16px;">
                <h2>3+ Product Views Today</h2>
                <p>Estimate targets (today, same product viewed 3+ times): <strong><?php echo esc_html((string) $repeatCandidates); ?></strong></p>
                <form method="post">
                    <?php wp_nonce_field('yana_bulk_campaign', 'yana_bulk_nonce'); ?>
                    <input type="hidden" name="yana_bulk_action" value="repeat_views" />
                    <button class="button button-primary" type="submit">Send to Repeat Viewers with 2% Coupon</button>
                </form>
            </div>
        </div>
        <?php
    }

    public static function render_wallet_page(): void {
        self::enforce_privileged_admin();
        $notice = '';
        $settings = self::get_wallet_settings();

        if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['yana_wallet_action'])) {
            check_admin_referer('yana_wallet_admin', 'yana_wallet_nonce');
            $action = sanitize_key((string) wp_unslash($_POST['yana_wallet_action']));

            if ($action === 'save_settings') {
                $settings = [
                    'enabled' => !empty($_POST['wallet_enabled']),
                    'signup_bonus' => max(0, round((float) ($_POST['signup_bonus'] ?? 200), 2)),
                    'min_billing' => max(0, round((float) ($_POST['min_billing'] ?? 2000), 2)),
                ];
                update_option(self::OPT_WALLET_SETTINGS, $settings);
                $notice = 'Wallet settings updated.';
            } else {
                $actorKeyInput = sanitize_text_field((string) wp_unslash($_POST['actor_key'] ?? ''));
                $userIdInput = absint((int) ($_POST['user_id'] ?? 0));
                $installIdInput = sanitize_text_field((string) wp_unslash($_POST['install_id'] ?? ''));
                $wallet = self::resolve_wallet_for_admin_inputs($actorKeyInput, $userIdInput, $installIdInput);
                if ($wallet === null) {
                    $notice = 'Provide actor_key or user_id/install_id.';
                } else {
                    if ($action === 'add_balance') {
                        $amount = max(0, round((float) ($_POST['amount'] ?? 0), 2));
                        if ($amount > 0) {
                            self::wallet_adjust_balance($wallet['actor_key'], $amount, 'admin_credit', [
                                'via' => 'wp_admin_wallet_page',
                            ]);
                            $notice = 'Balance added successfully.';
                        } else {
                            $notice = 'Amount must be greater than 0.';
                        }
                    } elseif ($action === 'set_ban') {
                        $isBanned = !empty($_POST['banned']) ? 1 : 0;
                        self::wallet_set_ban($wallet['actor_key'], $isBanned);
                        $notice = $isBanned ? 'Wallet blocked.' : 'Wallet unblocked.';
                    }
                }
            }
            $settings = self::get_wallet_settings();
        }

        global $wpdb;
        $table = $wpdb->prefix . self::WALLETS;
        $rows = self::table_exists($table) ? $wpdb->get_results(
            "SELECT actor_key,user_id,install_id,balance,banned,updated_at
             FROM {$table}
             ORDER BY updated_at DESC
             LIMIT 100",
            ARRAY_A
        ) : [];
        ?>
        <div class="wrap">
            <h1>Wallet Manager</h1>
            <?php if ($notice !== '') : ?>
                <div class="notice notice-success"><p><?php echo esc_html($notice); ?></p></div>
            <?php endif; ?>

            <div class="postbox" style="padding:16px; margin-top:16px;">
                <h2>Wallet Settings</h2>
                <form method="post">
                    <?php wp_nonce_field('yana_wallet_admin', 'yana_wallet_nonce'); ?>
                    <input type="hidden" name="yana_wallet_action" value="save_settings" />
                    <table class="form-table">
                        <tr>
                            <th>Wallet Enabled</th>
                            <td><label><input type="checkbox" name="wallet_enabled" value="1" <?php checked(!empty($settings['enabled'])); ?> /> Enable wallet in app checkout</label></td>
                        </tr>
                        <tr>
                            <th>Install Bonus (INR)</th>
                            <td><input type="number" step="0.01" min="0" name="signup_bonus" value="<?php echo esc_attr((string) ($settings['signup_bonus'] ?? 200)); ?>" /></td>
                        </tr>
                        <tr>
                            <th>Minimum Billing (INR)</th>
                            <td><input type="number" step="0.01" min="0" name="min_billing" value="<?php echo esc_attr((string) ($settings['min_billing'] ?? 2000)); ?>" /></td>
                        </tr>
                    </table>
                    <p><button class="button button-primary" type="submit">Save Wallet Settings</button></p>
                </form>
            </div>

            <div class="postbox" style="padding:16px; margin-top:16px;">
                <h2>Update User Wallet</h2>
                <p>Use either <code>actor_key</code> (<code>u:123</code> or <code>g:install_id</code>) or direct <code>user_id</code> and optional <code>install_id</code>.</p>
                <form method="post" style="margin-bottom:12px;">
                    <?php wp_nonce_field('yana_wallet_admin', 'yana_wallet_nonce'); ?>
                    <input type="hidden" name="yana_wallet_action" value="add_balance" />
                    <input type="text" name="actor_key" placeholder="u:123 or g:guest_xxx" style="width:320px;" />
                    <input type="number" min="0" name="user_id" placeholder="User ID" style="width:130px;" />
                    <input type="text" name="install_id" placeholder="install_id (optional)" style="width:220px;" />
                    <input type="number" step="0.01" min="0.01" name="amount" placeholder="Amount" required />
                    <button class="button button-primary" type="submit">Add Balance</button>
                </form>
                <form method="post">
                    <?php wp_nonce_field('yana_wallet_admin', 'yana_wallet_nonce'); ?>
                    <input type="hidden" name="yana_wallet_action" value="set_ban" />
                    <input type="text" name="actor_key" placeholder="u:123 or g:guest_xxx" style="width:320px;" />
                    <input type="number" min="0" name="user_id" placeholder="User ID" style="width:130px;" />
                    <input type="text" name="install_id" placeholder="install_id (optional)" style="width:220px;" />
                    <label><input type="checkbox" name="banned" value="1" /> Block wallet</label>
                    <button class="button" type="submit">Save Block Status</button>
                </form>
            </div>

            <div class="postbox" style="padding:16px; margin-top:16px;">
                <h2>Recent Wallet Accounts</h2>
                <table class="widefat striped">
                    <thead><tr><th>Actor</th><th>User ID</th><th>Install ID</th><th>Balance</th><th>Banned</th><th>Updated</th></tr></thead>
                    <tbody>
                    <?php if (empty($rows)) : ?>
                        <tr><td colspan="6">No wallet records found.</td></tr>
                    <?php else : foreach ($rows as $r) : ?>
                        <tr>
                            <td><?php echo esc_html((string) ($r['actor_key'] ?? '')); ?></td>
                            <td><?php echo esc_html((string) ($r['user_id'] ?? '0')); ?></td>
                            <td><?php echo esc_html((string) ($r['install_id'] ?? '')); ?></td>
                            <td><?php echo esc_html((string) ($r['balance'] ?? '0.00')); ?></td>
                            <td><?php echo !empty($r['banned']) ? 'Yes' : 'No'; ?></td>
                            <td><?php echo esc_html((string) ($r['updated_at'] ?? '')); ?></td>
                        </tr>
                    <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
        <?php
    }

    public static function render_user_credits_page(): void {
        self::enforce_privileged_admin();
        self::ensure_wallet_tables();
        global $wpdb;

        $walletsTable = $wpdb->prefix . self::WALLETS;
        $walletTxTable = $wpdb->prefix . self::WALLETS_TX;
        if (!self::table_exists($walletsTable)) {
            echo '<div class="wrap"><h1>User Credits</h1><p>Wallet table not found.</p></div>';
            return;
        }

        $limit = isset($_GET['limit']) ? max(20, min(500, absint($_GET['limit']))) : 100;
        $search = sanitize_text_field((string) ($_GET['q'] ?? ''));
        $searchLike = '%' . $wpdb->esc_like($search) . '%';

        $where = '';
        $params = [];
        if ($search !== '') {
            $where = "WHERE (w.actor_key LIKE %s OR w.install_id LIKE %s OR CAST(w.user_id AS CHAR) LIKE %s)";
            $params = [$searchLike, $searchLike, $searchLike];
        }

        $summarySql = "SELECT
                COUNT(*) AS total_wallets,
                SUM(w.balance) AS total_balance,
                SUM(CASE WHEN w.banned = 1 THEN 1 ELSE 0 END) AS total_banned
            FROM {$walletsTable} w
            {$where}";
        if (!empty($params)) {
            $summary = $wpdb->get_row($wpdb->prepare($summarySql, $params), ARRAY_A);
        } else {
            $summary = $wpdb->get_row($summarySql, ARRAY_A);
        }

        $rowsSql = "SELECT
                w.actor_key,
                w.user_id,
                w.install_id,
                w.balance,
                w.banned,
                w.is_merged,
                w.merged_to_actor,
                w.updated_at,
                COALESCE(tx.credit_total, 0) AS credit_total,
                COALESCE(tx.debit_total, 0) AS debit_total,
                COALESCE(tx.tx_count, 0) AS tx_count,
                tx.last_tx_at
            FROM {$walletsTable} w
            LEFT JOIN (
                SELECT
                    actor_key,
                    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS credit_total,
                    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS debit_total,
                    COUNT(*) AS tx_count,
                    MAX(created_at) AS last_tx_at
                FROM {$walletTxTable}
                GROUP BY actor_key
            ) tx ON tx.actor_key = w.actor_key
            {$where}
            ORDER BY w.updated_at DESC
            LIMIT %d";

        if (!empty($params)) {
            $queryParams = $params;
            $queryParams[] = $limit;
            $rows = $wpdb->get_results($wpdb->prepare($rowsSql, $queryParams), ARRAY_A);
        } else {
            $rows = $wpdb->get_results($wpdb->prepare($rowsSql, $limit), ARRAY_A);
        }

        $userCache = [];
        ?>
        <div class="wrap">
            <h1>User Credits</h1>
            <p>Admin-only wallet credits watch. Data is loaded directly from DB (no REST/API hit).</p>

            <form method="get" style="margin:12px 0;">
                <input type="hidden" name="page" value="<?php echo esc_attr(self::MENU . '-user-credits'); ?>" />
                <input type="text" name="q" placeholder="Search actor/user/install" value="<?php echo esc_attr($search); ?>" style="width:280px;" />
                <input type="number" name="limit" min="20" max="500" value="<?php echo esc_attr((string) $limit); ?>" />
                <button class="button button-primary" type="submit">Apply</button>
            </form>

            <p>
                <strong>Total Wallets:</strong> <?php echo esc_html((string) ((int) ($summary['total_wallets'] ?? 0))); ?> |
                <strong>Total Balance:</strong> <?php echo esc_html(number_format((float) ($summary['total_balance'] ?? 0), 2, '.', '')); ?> |
                <strong>Banned:</strong> <?php echo esc_html((string) ((int) ($summary['total_banned'] ?? 0))); ?>
            </p>

            <table class="widefat striped">
                <thead>
                    <tr>
                        <th>Actor Key</th>
                        <th>Wallet Balance</th>
                        <th>Total Credited</th>
                        <th>Total Debited</th>
                        <th>TX Count</th>
                        <th>App User ID</th>
                        <th>Install ID</th>
                        <th>WP User ID</th>
                        <th>WP Email</th>
                        <th>WP Name</th>
                        <th>Banned</th>
                        <th>Merged</th>
                        <th>Merged To</th>
                        <th>Updated</th>
                        <th>Last TX</th>
                    </tr>
                </thead>
                <tbody>
                <?php if (empty($rows)) : ?>
                    <tr><td colspan="15">No records found.</td></tr>
                <?php else : foreach ($rows as $row) :
                    $appUserId = (int) ($row['user_id'] ?? 0);
                    $wpUserId = $appUserId > 0 ? $appUserId : 0;
                    $wpEmail = '';
                    $wpName = '';
                    if ($wpUserId > 0) {
                        if (!array_key_exists($wpUserId, $userCache)) {
                            $user = get_userdata($wpUserId);
                            $userCache[$wpUserId] = ($user instanceof WP_User) ? $user : null;
                        }
                        $user = $userCache[$wpUserId];
                        if ($user instanceof WP_User) {
                            $wpEmail = (string) $user->user_email;
                            $wpName = (string) ($user->display_name ?: $user->user_login);
                        }
                    }
                    ?>
                    <tr>
                        <td><?php echo esc_html((string) ($row['actor_key'] ?? '')); ?></td>
                        <td><?php echo esc_html(number_format((float) ($row['balance'] ?? 0), 2, '.', '')); ?></td>
                        <td><?php echo esc_html(number_format((float) ($row['credit_total'] ?? 0), 2, '.', '')); ?></td>
                        <td><?php echo esc_html(number_format((float) ($row['debit_total'] ?? 0), 2, '.', '')); ?></td>
                        <td><?php echo esc_html((string) ((int) ($row['tx_count'] ?? 0))); ?></td>
                        <td><?php echo esc_html((string) $appUserId); ?></td>
                        <td><?php echo esc_html((string) ($row['install_id'] ?? '')); ?></td>
                        <td><?php echo esc_html((string) $wpUserId); ?></td>
                        <td><?php echo esc_html($wpEmail); ?></td>
                        <td><?php echo esc_html($wpName); ?></td>
                        <td><?php echo !empty($row['banned']) ? 'Yes' : 'No'; ?></td>
                        <td><?php echo !empty($row['is_merged']) ? 'Yes' : 'No'; ?></td>
                        <td><?php echo esc_html((string) ($row['merged_to_actor'] ?? '')); ?></td>
                        <td><?php echo esc_html((string) ($row['updated_at'] ?? '')); ?></td>
                        <td><?php echo esc_html((string) ($row['last_tx_at'] ?? '')); ?></td>
                    </tr>
                <?php endforeach; endif; ?>
                </tbody>
            </table>
        </div>
        <?php
    }

    public static function register_routes(): void {
        register_rest_route(self::NS, self::ROUTE, [
            'methods' => 'POST',
            'callback' => [self::class, 'ingest_event'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NS, '/app-update-status', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_public_app_update_status'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NS, '/home-popup-status', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_public_home_popup_status'],
            'permission_callback' => '__return_true',
        ]);
        register_rest_route(self::NS, '/home-popup-ack', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_public_home_popup_ack'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NS, '/wallet/status', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_public_wallet_status'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NS, '/wallet/overview', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_public_wallet_overview'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NS, '/gateway-status', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_public_gateway_status'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::ADMIN_NS, '/overview', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_overview'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/wallet/config', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_wallet_config_get'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/wallet/config', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_wallet_config_set'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/gateway/config', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_gateway_config_get'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/gateway/config', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_gateway_config_set'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/wallet/credit', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_wallet_credit'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/wallet/ban', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_wallet_ban'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);
        register_rest_route(self::ADMIN_NS, '/wallet/user-credits', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_wallet_user_credits'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/live', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_live'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/bulk/cart', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_bulk_cart'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/bulk/repeat-views', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_bulk_repeat_views'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/actors', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_actors'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/actor', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_actor'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/push/custom', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_push_custom'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/push/campaign', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_push_campaign'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/insights/user-interest', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_user_interest'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/insights/top-products', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_top_products'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/app-update', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_app_update_get'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/app-update', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_app_update_set'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/home-popup', [
            'methods' => 'GET',
            'callback' => [self::class, 'rest_admin_home_popup_get'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);

        register_rest_route(self::ADMIN_NS, '/home-popup', [
            'methods' => 'POST',
            'callback' => [self::class, 'rest_admin_home_popup_set'],
            'permission_callback' => [self::class, 'rest_admin_permission'],
        ]);
    }

    public static function rest_admin_permission(): bool {
        return self::is_privileged_admin();
    }

    public static function rest_public_app_update_status(): WP_REST_Response {
        $state = self::get_update_notice_state();
        return new WP_REST_Response([
            'ok' => true,
            'campaign_id' => (int) ($state['campaign_id'] ?? 0),
            'active' => !empty($state['active']),
            'title' => (string) ($state['title'] ?? 'Update Available'),
            'message' => (string) ($state['message'] ?? ''),
            'url' => (string) ($state['url'] ?? self::DEF_UPDATE_NOTICE_URL),
            'min_version' => (string) ($state['min_version'] ?? ''),
            'latest_version' => (string) ($state['latest_version'] ?? ''),
            'force_update' => !empty($state['force_update']),
            'updated_at' => (string) ($state['updated_at'] ?? ''),
        ], 200);
    }

    public static function rest_public_home_popup_status(WP_REST_Request $request): WP_REST_Response {
        $state = self::get_home_popup_state();
        $userId = absint((int) $request->get_param('user_id'));
        $installId = sanitize_text_field((string) $request->get_param('install_id'));
        $campaignId = (string) ($state['campaign_id'] ?? '');
        $alreadySeen = !empty($state['active'])
            && $campaignId !== ''
            && self::has_seen_home_popup_campaign($campaignId, $userId, $installId);
        $response = new WP_REST_Response([
            'ok' => true,
            'campaign_id' => $campaignId,
            'active' => !empty($state['active']) && !$alreadySeen,
            'seen' => $alreadySeen,
            'title' => (string) ($state['title'] ?? 'Important Update'),
            'message' => (string) ($state['message'] ?? ''),
            'button_text' => (string) ($state['button_text'] ?? 'Got it'),
            'action_url' => (string) ($state['action_url'] ?? ''),
            'updated_at' => (string) ($state['updated_at'] ?? ''),
        ], 200);
        $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
        $response->header('Pragma', 'no-cache');
        $response->header('Expires', 'Wed, 11 Jan 1984 05:00:00 GMT');
        return $response;
    }

    public static function rest_public_home_popup_ack(WP_REST_Request $request): WP_REST_Response {
        if (!self::is_valid_app_key_request($request)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid app key'], 403);
        }

        $body = $request->get_json_params();
        if (!is_array($body)) {
            $body = [];
        }

        $campaignId = trim((string) ($body['campaign_id'] ?? ''));
        $action = sanitize_key((string) ($body['action'] ?? 'close'));
        $userId = absint((int) ($body['user_id'] ?? 0));
        $installId = sanitize_text_field((string) ($body['install_id'] ?? ''));
        if ($campaignId === '' || ($userId <= 0 && $installId === '')) {
            return new WP_REST_Response(['ok' => false, 'message' => 'campaign_id and actor required'], 400);
        }

        $eventName = in_array($action, ['view', 'close', 'cta', 'dismiss'], true)
            ? 'home_popup_' . $action
            : 'home_popup_close';

        self::store_event($eventName, $userId, $installId, [
            'campaign_id' => $campaignId,
            'action' => $action,
        ]);

        return new WP_REST_Response(['ok' => true], 200);
    }

    public static function rest_public_wallet_status(WP_REST_Request $request): WP_REST_Response {
        if (!self::is_valid_app_key_request($request)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid app key'], 403);
        }

        $body = $request->get_json_params();
        if (!is_array($body)) {
            $body = [];
        }
        $userId = absint((int) ($body['user_id'] ?? 0));
        $installId = sanitize_text_field((string) ($body['install_id'] ?? ''));
        $orderAmount = max(0, round((float) ($body['order_amount'] ?? 0), 2));
        $wallet = self::ensure_wallet_account($userId, $installId);
        if ($wallet === null) {
            return new WP_REST_Response([
                'ok' => false,
                'message' => 'user_id or install_id required',
            ], 400);
        }

        $settings = self::get_wallet_settings();
        $minBilling = (float) ($settings['min_billing'] ?? 2000);
        $eligibleByAmount = $orderAmount >= $minBilling;
        $available = (!$settings['enabled'] || !empty($wallet['banned']) || !$eligibleByAmount)
            ? 0.0
            : min((float) ($wallet['balance'] ?? 0), $orderAmount);
        $resolvedUserId = (int) ($wallet['user_id'] ?? 0);
        if ($resolvedUserId <= 0 && $userId > 0) {
            $resolvedUserId = $userId;
        }

        return new WP_REST_Response([
            'ok' => true,
            'wallet_enabled' => !empty($settings['enabled']),
            'min_billing' => $minBilling,
            'bonus_amount' => (float) ($settings['signup_bonus'] ?? 200),
            'resolved_actor_key' => (string) ($wallet['actor_key'] ?? ''),
            'linked_from_install' => !empty($wallet['linked_from_install']),
            'actor_key' => (string) ($wallet['actor_key'] ?? ''),
            'user_id' => $resolvedUserId,
            'install_id' => (string) ($wallet['install_id'] ?? ''),
            'balance' => round((float) ($wallet['balance'] ?? 0), 2),
            'banned' => !empty($wallet['banned']),
            'order_amount' => $orderAmount,
            'eligible_by_amount' => $eligibleByAmount,
            'available_to_use' => round($available, 2),
        ], 200);
    }

    public static function rest_public_wallet_overview(WP_REST_Request $request): WP_REST_Response {
        if (!self::is_valid_app_key_request($request)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid app key'], 403);
        }
        $body = $request->get_json_params();
        if (!is_array($body)) {
            $body = [];
        }
        $userId = absint((int) ($body['user_id'] ?? 0));
        $installId = sanitize_text_field((string) ($body['install_id'] ?? ''));
        $orderAmount = max(0, round((float) ($body['order_amount'] ?? 0), 2));
        $wallet = self::ensure_wallet_account($userId, $installId);
        if ($wallet === null) {
            return new WP_REST_Response([
                'ok' => false,
                'message' => 'user_id or install_id required',
            ], 400);
        }

        $settings = self::get_wallet_settings();
        $minBilling = (float) ($settings['min_billing'] ?? 2000);
        $eligibleByAmount = $orderAmount >= $minBilling;
        $available = (!$settings['enabled'] || !empty($wallet['banned']) || !$eligibleByAmount)
            ? 0.0
            : min((float) ($wallet['balance'] ?? 0), $orderAmount);
        $resolvedUserId = (int) ($wallet['user_id'] ?? 0);
        if ($resolvedUserId <= 0 && $userId > 0) {
            $resolvedUserId = $userId;
        }

        return new WP_REST_Response([
            'ok' => true,
            'wallet_enabled' => !empty($settings['enabled']),
            'min_billing' => $minBilling,
            'bonus_amount' => (float) ($settings['signup_bonus'] ?? 200),
            'resolved_actor_key' => (string) ($wallet['actor_key'] ?? ''),
            'linked_from_install' => !empty($wallet['linked_from_install']),
            'actor_key' => (string) ($wallet['actor_key'] ?? ''),
            'user_id' => $resolvedUserId,
            'install_id' => (string) ($wallet['install_id'] ?? ''),
            'balance' => round((float) ($wallet['balance'] ?? 0), 2),
            'banned' => !empty($wallet['banned']),
            'order_amount' => $orderAmount,
            'eligible_by_amount' => $eligibleByAmount,
            'available_to_use' => round($available, 2),
            'transactions' => self::wallet_transactions_for_actor((string) ($wallet['actor_key'] ?? ''), 100),
        ], 200);
    }

    public static function rest_admin_wallet_config_get(): WP_REST_Response {
        return new WP_REST_Response([
            'ok' => true,
            'settings' => self::get_wallet_settings(),
        ], 200);
    }

    public static function rest_admin_wallet_config_set(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }
        $settings = [
            'enabled' => !empty($body['enabled']),
            'signup_bonus' => max(0, round((float) ($body['signup_bonus'] ?? 200), 2)),
            'min_billing' => max(0, round((float) ($body['min_billing'] ?? 2000), 2)),
        ];
        update_option(self::OPT_WALLET_SETTINGS, $settings);
        return new WP_REST_Response(['ok' => true, 'settings' => $settings], 200);
    }

    public static function rest_public_gateway_status(): WP_REST_Response {
        $settings = self::get_gateway_settings();
        return new WP_REST_Response([
            'ok' => true,
            'cashfree_enabled' => !empty($settings['cashfree_enabled']),
            'payu_enabled' => !empty($settings['payu_enabled']),
        ], 200);
    }

    public static function rest_admin_gateway_config_get(): WP_REST_Response {
        return new WP_REST_Response([
            'ok' => true,
            'settings' => self::get_gateway_settings(),
        ], 200);
    }

    public static function rest_admin_gateway_config_set(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }
        $settings = [
            'cashfree_enabled' => !empty($body['cashfree_enabled']),
            'payu_enabled' => !empty($body['payu_enabled']),
        ];
        update_option(self::OPT_GATEWAY_SETTINGS, $settings);
        return new WP_REST_Response(['ok' => true, 'settings' => $settings], 200);
    }

    public static function rest_admin_wallet_credit(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }
        $actorKeyInput = sanitize_text_field((string) ($body['actor_key'] ?? ''));
        $userIdInput = absint((int) ($body['user_id'] ?? 0));
        $installIdInput = sanitize_text_field((string) ($body['install_id'] ?? ''));
        $wallet = self::resolve_wallet_for_admin_inputs($actorKeyInput, $userIdInput, $installIdInput);
        $amount = max(0, round((float) ($body['amount'] ?? 0), 2));
        if ($wallet === null || $amount <= 0) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Valid actor_key or user_id/install_id and amount required'], 400);
        }
        $updated = self::wallet_adjust_balance((string) $wallet['actor_key'], $amount, 'admin_credit', [
            'via' => 'rest_admin_wallet_credit',
            'requested_actor_key' => $actorKeyInput,
            'requested_user_id' => $userIdInput,
            'requested_install_id' => $installIdInput,
        ]);
        return new WP_REST_Response([
            'ok' => true,
            'actor_key' => (string) $wallet['actor_key'],
            'resolved_actor_key' => (string) $wallet['actor_key'],
            'user_id' => (int) ($updated['user_id'] ?? 0),
            'install_id' => (string) ($updated['install_id'] ?? ''),
            'balance' => round((float) ($updated['balance'] ?? 0), 2),
        ], 200);
    }

    public static function rest_admin_wallet_ban(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }
        $actorKeyInput = sanitize_text_field((string) ($body['actor_key'] ?? ''));
        $userIdInput = absint((int) ($body['user_id'] ?? 0));
        $installIdInput = sanitize_text_field((string) ($body['install_id'] ?? ''));
        $wallet = self::resolve_wallet_for_admin_inputs($actorKeyInput, $userIdInput, $installIdInput);
        if ($wallet === null) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Valid actor_key or user_id/install_id required'], 400);
        }
        $isBanned = !empty($body['banned']) ? 1 : 0;
        $updated = self::wallet_set_ban((string) $wallet['actor_key'], $isBanned);
        return new WP_REST_Response([
            'ok' => true,
            'actor_key' => (string) $wallet['actor_key'],
            'resolved_actor_key' => (string) $wallet['actor_key'],
            'user_id' => (int) ($updated['user_id'] ?? 0),
            'install_id' => (string) ($updated['install_id'] ?? ''),
            'banned' => !empty($updated['banned']),
        ], 200);
    }

    public static function rest_admin_wallet_user_credits(WP_REST_Request $request): WP_REST_Response {
        self::ensure_wallet_tables();
        global $wpdb;
        $walletsTable = $wpdb->prefix . self::WALLETS;
        $walletTxTable = $wpdb->prefix . self::WALLETS_TX;
        if (!self::table_exists($walletsTable)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Wallet table not found'], 500);
        }

        $limit = max(20, min(500, absint((int) $request->get_param('limit'))));
        $search = sanitize_text_field((string) $request->get_param('q'));
        $searchLike = '%' . $wpdb->esc_like($search) . '%';

        $where = '';
        $params = [];
        if ($search !== '') {
            $where = "WHERE (w.actor_key LIKE %s OR w.install_id LIKE %s OR CAST(w.user_id AS CHAR) LIKE %s)";
            $params = [$searchLike, $searchLike, $searchLike];
        }

        $summarySql = "SELECT
                COUNT(*) AS total_wallets,
                SUM(w.balance) AS total_balance,
                SUM(CASE WHEN w.banned = 1 THEN 1 ELSE 0 END) AS total_banned
            FROM {$walletsTable} w
            {$where}";
        if (!empty($params)) {
            $summary = $wpdb->get_row($wpdb->prepare($summarySql, $params), ARRAY_A);
        } else {
            $summary = $wpdb->get_row($summarySql, ARRAY_A);
        }

        $rowsSql = "SELECT
                w.actor_key,
                w.user_id,
                w.install_id,
                w.balance,
                w.banned,
                w.is_merged,
                w.merged_to_actor,
                w.updated_at,
                COALESCE(tx.credit_total, 0) AS credit_total,
                COALESCE(tx.debit_total, 0) AS debit_total,
                COALESCE(tx.tx_count, 0) AS tx_count,
                tx.last_tx_at
            FROM {$walletsTable} w
            LEFT JOIN (
                SELECT
                    actor_key,
                    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS credit_total,
                    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS debit_total,
                    COUNT(*) AS tx_count,
                    MAX(created_at) AS last_tx_at
                FROM {$walletTxTable}
                GROUP BY actor_key
            ) tx ON tx.actor_key = w.actor_key
            {$where}
            ORDER BY w.updated_at DESC
            LIMIT %d";

        if (!empty($params)) {
            $queryParams = $params;
            $queryParams[] = $limit;
            $rows = $wpdb->get_results($wpdb->prepare($rowsSql, $queryParams), ARRAY_A);
        } else {
            $rows = $wpdb->get_results($wpdb->prepare($rowsSql, $limit), ARRAY_A);
        }

        $out = [];
        foreach ((array) $rows as $row) {
            $userId = (int) ($row['user_id'] ?? 0);
            $email = $userId > 0 ? self::get_user_email_by_id($userId) : null;
            $name = $userId > 0 ? self::get_user_name_by_id($userId) : null;
            $out[] = [
                'actor_key' => (string) ($row['actor_key'] ?? ''),
                'user_id' => $userId,
                'install_id' => (string) ($row['install_id'] ?? ''),
                'wp_user_id' => $userId,
                'wp_user_email' => $email,
                'wp_user_name' => $name,
                'balance' => round((float) ($row['balance'] ?? 0), 2),
                'credit_total' => round((float) ($row['credit_total'] ?? 0), 2),
                'debit_total' => round((float) ($row['debit_total'] ?? 0), 2),
                'tx_count' => (int) ($row['tx_count'] ?? 0),
                'banned' => !empty($row['banned']),
                'is_merged' => !empty($row['is_merged']),
                'merged_to_actor' => (string) ($row['merged_to_actor'] ?? ''),
                'updated_at' => (string) ($row['updated_at'] ?? ''),
                'last_tx_at' => (string) ($row['last_tx_at'] ?? ''),
            ];
        }

        return new WP_REST_Response([
            'ok' => true,
            'q' => $search,
            'limit' => $limit,
            'summary' => [
                'total_wallets' => (int) ($summary['total_wallets'] ?? 0),
                'total_balance' => round((float) ($summary['total_balance'] ?? 0), 2),
                'total_banned' => (int) ($summary['total_banned'] ?? 0),
            ],
            'rows' => $out,
        ], 200);
    }

    public static function rest_admin_app_update_get(): WP_REST_Response {
        $state = self::get_update_notice_state();
        return new WP_REST_Response([
            'ok' => true,
            'state' => $state,
        ], 200);
    }

    public static function rest_admin_app_update_set(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }

        $action = sanitize_key((string) ($body['action'] ?? ''));
        $current = self::get_update_notice_state();
        if ($action === 'deactivate') {
            $current['active'] = false;
            $current['updated_at'] = current_time('mysql');
            update_option(self::OPT_UPDATE_NOTICE_STATE, $current);
            return new WP_REST_Response(['ok' => true, 'state' => $current], 200);
        }

        $title = sanitize_text_field((string) ($body['title'] ?? 'Update Available'));
        $message = sanitize_text_field((string) ($body['message'] ?? 'Please update the app for the best experience.'));
        $url = esc_url_raw((string) ($body['url'] ?? self::DEF_UPDATE_NOTICE_URL));
        $minVersion = sanitize_text_field((string) ($body['min_version'] ?? ''));
        $latestVersion = sanitize_text_field((string) ($body['latest_version'] ?? ''));
        $forceUpdate = !empty($body['force_update']);
        if ($title === '' || $message === '' || $url === '') {
            return new WP_REST_Response(['ok' => false, 'message' => 'title, message, url required'], 400);
        }

        $nextCampaignId = max(0, (int) ($current['campaign_id'] ?? 0)) + 1;
        $state = [
            'campaign_id' => $nextCampaignId,
            'active' => true,
            'title' => $title,
            'message' => $message,
            'url' => $url,
            'min_version' => $minVersion,
            'latest_version' => $latestVersion,
            'force_update' => $forceUpdate,
            'updated_at' => current_time('mysql'),
        ];
        update_option(self::OPT_UPDATE_NOTICE_STATE, $state);

        return new WP_REST_Response([
            'ok' => true,
            'state' => $state,
        ], 200);
    }

    public static function rest_admin_home_popup_get(): WP_REST_Response {
        $state = self::get_home_popup_state();
        return new WP_REST_Response([
            'ok' => true,
            'state' => $state,
        ], 200);
    }

    public static function rest_admin_home_popup_set(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }

        $action = sanitize_key((string) ($body['action'] ?? ''));
        $current = self::get_home_popup_state();
        if ($action === 'deactivate') {
            $current['active'] = false;
            $current['updated_at'] = current_time('mysql');
            update_option(self::OPT_HOME_POPUP_STATE, $current);
            return new WP_REST_Response(['ok' => true, 'state' => $current], 200);
        }

        $title = sanitize_text_field((string) ($body['title'] ?? 'Important Update'));
        $message = sanitize_textarea_field((string) ($body['message'] ?? ''));
        $buttonText = sanitize_text_field((string) ($body['button_text'] ?? 'Got it'));
        $actionUrl = esc_url_raw((string) ($body['action_url'] ?? ''));
        if ($title === '' || $message === '' || $buttonText === '') {
            return new WP_REST_Response(['ok' => false, 'message' => 'title, message, button_text required'], 400);
        }

        $currentCampaignId = trim((string) ($current['campaign_id'] ?? ''));
        $nextCampaignId = $action === 'update_current' && $currentCampaignId !== ''
            ? $currentCampaignId
            : 'campaign_' . wp_generate_password(10, false, false) . '_' . time();
        $state = [
            'campaign_id' => $nextCampaignId,
            'active' => true,
            'title' => $title,
            'message' => $message,
            'button_text' => $buttonText,
            'action_url' => $actionUrl,
            'updated_at' => current_time('mysql'),
        ];
        update_option(self::OPT_HOME_POPUP_STATE, $state);

        return new WP_REST_Response([
            'ok' => true,
            'state' => $state,
        ], 200);
    }

    public static function rest_admin_overview(): WP_REST_Response {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $tokensTable = $wpdb->prefix . self::TOKENS;

        $eventsCount = (int) $wpdb->get_var("SELECT COUNT(1) FROM {$eventsTable}");
        $tokensCount = (int) $wpdb->get_var("SELECT COUNT(1) FROM {$tokensTable}");
        $events30m = (int) $wpdb->get_var("SELECT COUNT(1) FROM {$eventsTable} WHERE created_at >= (NOW() - INTERVAL 30 MINUTE)");

        return new WP_REST_Response([
            'ok' => true,
            'events_total' => $eventsCount,
            'events_30m' => $events30m,
            'tokens_total' => $tokensCount,
            'server_time' => current_time('mysql'),
        ], 200);
    }

    public static function rest_admin_live(WP_REST_Request $request): WP_REST_Response {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $minutes = max(5, min(240, absint((int) $request->get_param('minutes'))));
        $limitRaw = absint((int) $request->get_param('limit'));
        $limit = $limitRaw > 0 ? max(10, min(100, $limitRaw)) : 50;
        $includePayload = filter_var($request->get_param('include_payload'), FILTER_VALIDATE_BOOLEAN);

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT id,event_name,user_id,install_id,product_id,created_at" . ($includePayload ? ",LEFT(payload, 500) AS payload" : "") . "
                 FROM {$eventsTable}
                 WHERE created_at >= (NOW() - INTERVAL %d MINUTE)
                 ORDER BY id DESC
                 LIMIT %d",
                $minutes,
                $limit
            ),
            ARRAY_A
        );

        return new WP_REST_Response([
            'ok' => true,
            'minutes' => $minutes,
            'limit' => $limit,
            'include_payload' => $includePayload,
            'rows' => is_array($rows) ? $rows : [],
        ], 200);
    }

    public static function cleanup_old_data(): void {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $tokensTable = $wpdb->prefix . self::TOKENS;

        $wpdb->query(
            $wpdb->prepare(
                "DELETE FROM {$eventsTable} WHERE created_at < (NOW() - INTERVAL %d DAY)",
                self::EVENTS_RETENTION_DAYS
            )
        );
        $wpdb->query(
            $wpdb->prepare(
                "DELETE FROM {$tokensTable} WHERE last_seen < (NOW() - INTERVAL %d DAY)",
                self::TOKENS_RETENTION_DAYS
            )
        );
    }

    public static function rest_admin_bulk_cart(WP_REST_Request $request): WP_REST_Response {
        $days = max(1, min(30, absint((int) $request->get_param('days'))));
        $result = self::send_bulk_cart_recovery($days);
        return new WP_REST_Response([
            'ok' => true,
            'mode' => 'cart',
            'days' => $days,
            'result' => $result,
        ], 200);
    }

    public static function rest_admin_bulk_repeat_views(): WP_REST_Response {
        $result = self::send_bulk_repeat_view_recovery();
        return new WP_REST_Response([
            'ok' => true,
            'mode' => 'repeat_views',
            'result' => $result,
        ], 200);
    }

    public static function rest_admin_actors(WP_REST_Request $request): WP_REST_Response {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $days = max(1, min(30, absint((int) $request->get_param('days'))));
        $limit = max(10, min(300, absint((int) $request->get_param('limit'))));
        $emailCache = [];

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT id,event_name,user_id,install_id,created_at,payload
                 FROM {$eventsTable}
                 WHERE created_at >= (NOW() - INTERVAL %d DAY)
                   AND (
                    (user_id IS NOT NULL AND user_id > 0)
                    OR (install_id IS NOT NULL AND install_id <> '')
                   )
                 ORDER BY id DESC
                 LIMIT %d",
                $days,
                self::MAX_ACTOR_SCAN_ROWS
            ),
            ARRAY_A
        );

        $actors = [];
        foreach ($rows as $row) {
            $userId = absint((int) ($row['user_id'] ?? 0));
            $installId = sanitize_text_field((string) ($row['install_id'] ?? ''));
            $actorKey = $userId > 0 ? 'u:' . $userId : 'g:' . $installId;
            if ($actorKey === 'g:') {
                continue;
            }

            $payload = json_decode((string) ($row['payload'] ?? '{}'), true);
            $lastPage = '-';
            if (is_array($payload)) {
                $lastPage = sanitize_text_field((string) ($payload['screen_name'] ?? $payload['page_url'] ?? '-'));
            }

            if (!isset($actors[$actorKey])) {
                $email = null;
                if ($userId > 0) {
                    if (!array_key_exists($userId, $emailCache)) {
                        $emailCache[$userId] = self::get_user_email_by_id($userId);
                    }
                    $email = $emailCache[$userId];
                }
                $actors[$actorKey] = [
                    'actor_key' => $actorKey,
                    'user_id' => $userId > 0 ? $userId : null,
                    'user_email' => $email,
                    'install_id' => $installId !== '' ? $installId : null,
                    'last_seen' => (string) ($row['created_at'] ?? ''),
                    'last_event' => (string) ($row['event_name'] ?? ''),
                    'last_page' => $lastPage !== '' ? $lastPage : '-',
                    'events_count' => 0,
                ];
            }

            $actors[$actorKey]['events_count'] = (int) $actors[$actorKey]['events_count'] + 1;
            if ($actors[$actorKey]['last_page'] === '-' && $lastPage !== '' && $lastPage !== '-') {
                $actors[$actorKey]['last_page'] = $lastPage;
            }
        }

        $actorsOut = array_values($actors);
        if (count($actorsOut) > $limit) {
            $actorsOut = array_slice($actorsOut, 0, $limit);
        }

        return new WP_REST_Response([
            'ok' => true,
            'days' => $days,
            'limit' => $limit,
            'actors' => $actorsOut,
        ], 200);
    }

    public static function rest_admin_actor(WP_REST_Request $request): WP_REST_Response {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $actorKey = sanitize_text_field((string) $request->get_param('actor_key'));
        $minutes = max(30, min(43200, absint((int) $request->get_param('minutes'))));
        $limit = max(10, min(200, absint((int) $request->get_param('limit'))));
        $actor = self::parse_actor_key($actorKey);
        if ($actor['user_id'] <= 0 && $actor['install_id'] === '') {
            return new WP_REST_Response(['ok' => false, 'message' => 'actor_key required'], 400);
        }

        if ($actor['user_id'] > 0) {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT id,event_name,user_id,install_id,created_at,payload
                     FROM {$eventsTable}
                     WHERE user_id = %d
                       AND created_at >= (NOW() - INTERVAL %d MINUTE)
                     ORDER BY id DESC
                     LIMIT %d",
                    $actor['user_id'],
                    $minutes,
                    $limit
                ),
                ARRAY_A
            );
        } else {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT id,event_name,user_id,install_id,created_at,payload
                     FROM {$eventsTable}
                     WHERE install_id = %s
                       AND created_at >= (NOW() - INTERVAL %d MINUTE)
                     ORDER BY id DESC
                     LIMIT %d",
                    $actor['install_id'],
                    $minutes,
                    $limit
                ),
                ARRAY_A
            );
        }

        $lastPage = '-';
        foreach ($rows as $row) {
            $payload = json_decode((string) ($row['payload'] ?? '{}'), true);
            if (!is_array($payload)) {
                continue;
            }
            $page = sanitize_text_field((string) ($payload['screen_name'] ?? $payload['page_url'] ?? ''));
            if ($page !== '') {
                $lastPage = $page;
                break;
            }
        }

        return new WP_REST_Response([
            'ok' => true,
            'actor' => [
                'actor_key' => $actorKey,
                'user_id' => $actor['user_id'] > 0 ? $actor['user_id'] : null,
                'user_email' => $actor['user_id'] > 0 ? self::get_user_email_by_id((int) $actor['user_id']) : null,
                'install_id' => $actor['install_id'] !== '' ? $actor['install_id'] : null,
                'tokens_count' => count(self::resolve_tokens($actor['user_id'], $actor['install_id'])),
                'last_page' => $lastPage,
            ],
            'rows' => is_array($rows) ? $rows : [],
        ], 200);
    }

    public static function rest_admin_push_custom(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }

        $actorKey = sanitize_text_field((string) ($body['actor_key'] ?? ''));
        $title = sanitize_text_field((string) ($body['title'] ?? ''));
        $message = sanitize_text_field((string) ($body['body'] ?? ''));
        $extra = is_array($body['data'] ?? null) ? $body['data'] : [];
        $actor = self::parse_actor_key($actorKey);
        if (($actor['user_id'] <= 0 && $actor['install_id'] === '') || $title === '' || $message === '') {
            return new WP_REST_Response(['ok' => false, 'message' => 'actor_key, title, body required'], 400);
        }

        $extra['type'] = 'custom_admin_message';
        $extra['actor_key'] = $actorKey;
        self::send_targeted_push($actor['user_id'], $actor['install_id'], $title, $message, $extra);

        return new WP_REST_Response([
            'ok' => true,
            'actor_key' => $actorKey,
            'tokens_count' => count(self::resolve_tokens($actor['user_id'], $actor['install_id'])),
        ], 200);
    }

    public static function rest_admin_push_campaign(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }

        $campaign = [
            'title' => sanitize_text_field((string) ($body['title'] ?? '')),
            'body' => sanitize_text_field((string) ($body['body'] ?? '')),
            'deep_link' => esc_url_raw((string) ($body['deep_link'] ?? '')),
            'image_url' => esc_url_raw((string) ($body['image_url'] ?? '')),
            'coupon_code' => sanitize_text_field((string) ($body['coupon_code'] ?? '')),
            'target_mode' => sanitize_key((string) ($body['target_mode'] ?? 'all')),
            'actor_keys' => is_array($body['actor_keys'] ?? null) ? array_values(array_filter(array_map('sanitize_text_field', $body['actor_keys']))) : [],
            'audience_filter' => sanitize_key((string) ($body['audience_filter'] ?? 'any')),
            'product_id' => absint((int) ($body['product_id'] ?? 0)),
            'lookback_days' => max(1, min(60, absint((int) ($body['lookback_days'] ?? 7)))),
            'schedule_mode' => sanitize_key((string) ($body['schedule_mode'] ?? 'now')),
            'schedule_at' => sanitize_text_field((string) ($body['schedule_at'] ?? '')),
        ];

        if ($campaign['title'] === '' || $campaign['body'] === '') {
            return new WP_REST_Response(['ok' => false, 'message' => 'title and body required'], 400);
        }
        if (!in_array($campaign['target_mode'], ['all', 'selected', 'guest_only'], true)) {
            $campaign['target_mode'] = 'all';
        }
        if (!in_array($campaign['audience_filter'], ['any', 'cart', 'product', 'repeat_views'], true)) {
            $campaign['audience_filter'] = 'any';
        }
        if ($campaign['target_mode'] === 'selected' && empty($campaign['actor_keys'])) {
            return new WP_REST_Response(['ok' => false, 'message' => 'actor_keys required for selected target'], 400);
        }
        if ($campaign['audience_filter'] === 'product' && $campaign['product_id'] <= 0) {
            return new WP_REST_Response(['ok' => false, 'message' => 'product_id required for product filter'], 400);
        }

        $now = current_time('timestamp');
        if ($campaign['schedule_mode'] === 'later') {
            $when = strtotime($campaign['schedule_at']);
            if ($when === false || $when <= ($now + 30)) {
                return new WP_REST_Response(['ok' => false, 'message' => 'valid future schedule_at required'], 400);
            }
            wp_schedule_single_event($when, 'yana_send_scheduled_campaign', [$campaign]);
            return new WP_REST_Response([
                'ok' => true,
                'scheduled' => true,
                'scheduled_at' => wp_date('Y-m-d H:i:s', $when),
            ], 200);
        }

        $result = self::execute_campaign($campaign);
        return new WP_REST_Response([
            'ok' => true,
            'scheduled' => false,
            'result' => $result,
        ], 200);
    }

    public static function handle_scheduled_campaign(array $campaign): void {
        if (!is_array($campaign)) {
            return;
        }
        self::execute_campaign($campaign);
    }

    public static function rest_admin_user_interest(WP_REST_Request $request): WP_REST_Response {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $days = max(1, min(60, absint((int) $request->get_param('days'))));
        $limit = max(10, min(300, absint((int) $request->get_param('limit'))));

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT event_name,user_id,install_id,product_id,payload,created_at
                 FROM {$eventsTable}
                 WHERE event_name IN ('product_view','view_item','repeat_product_interest')
                   AND product_id IS NOT NULL
                   AND product_id > 0
                   AND created_at >= (NOW() - INTERVAL %d DAY)
                 ORDER BY id DESC
                 LIMIT 5000",
                $days
            ),
            ARRAY_A
        );

        $agg = [];
        foreach ($rows as $row) {
            $userId = absint((int) ($row['user_id'] ?? 0));
            $installId = sanitize_text_field((string) ($row['install_id'] ?? ''));
            $productId = absint((int) ($row['product_id'] ?? 0));
            if ($productId <= 0) {
                continue;
            }
            $actorKey = self::actor_key($userId, $installId);
            if ($actorKey === '') {
                continue;
            }
            $key = $actorKey . '|p:' . $productId;
            $payload = json_decode((string) ($row['payload'] ?? '{}'), true);
            $productName = '';
            $page = '';
            if (is_array($payload)) {
                $productName = sanitize_text_field((string) ($payload['product_name'] ?? ''));
                $page = sanitize_text_field((string) ($payload['screen_name'] ?? $payload['page_url'] ?? ''));
            }

            if (!isset($agg[$key])) {
                $agg[$key] = [
                    'actor_key' => $actorKey,
                    'user_id' => $userId > 0 ? $userId : null,
                    'user_email' => $userId > 0 ? self::get_user_email_by_id($userId) : null,
                    'user_name' => $userId > 0 ? self::get_user_name_by_id($userId) : null,
                    'install_id' => $installId !== '' ? $installId : null,
                    'product_id' => $productId,
                    'product_name' => $productName !== '' ? $productName : self::get_product_name_by_id($productId),
                    'last_page' => $page !== '' ? $page : '-',
                    'views' => 0,
                    'last_seen' => (string) ($row['created_at'] ?? ''),
                    'last_event' => (string) ($row['event_name'] ?? ''),
                ];
            }
            $agg[$key]['views'] = (int) $agg[$key]['views'] + 1;
            if ($agg[$key]['last_page'] === '-' && $page !== '') {
                $agg[$key]['last_page'] = $page;
            }
        }

        $out = array_values($agg);
        usort($out, static function ($a, $b) {
            $v = (int) ($b['views'] ?? 0) <=> (int) ($a['views'] ?? 0);
            if ($v !== 0) {
                return $v;
            }
            return strcmp((string) ($b['last_seen'] ?? ''), (string) ($a['last_seen'] ?? ''));
        });
        if (count($out) > $limit) {
            $out = array_slice($out, 0, $limit);
        }

        return new WP_REST_Response([
            'ok' => true,
            'days' => $days,
            'rows' => $out,
        ], 200);
    }

    public static function rest_admin_top_products(WP_REST_Request $request): WP_REST_Response {
        global $wpdb;
        $days = max(1, min(120, absint((int) $request->get_param('days'))));
        $limit = max(10, min(200, absint((int) $request->get_param('limit'))));

        $sales = [];
        $lookupTable = $wpdb->prefix . 'wc_order_product_lookup';
        $statsTable = $wpdb->prefix . 'wc_order_stats';
        if (self::table_exists($lookupTable) && self::table_exists($statsTable)) {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT l.product_id,
                            SUM(l.product_qty) AS sold_qty,
                            SUM(l.product_net_revenue) AS net_revenue
                     FROM {$lookupTable} l
                     INNER JOIN {$statsTable} s ON s.order_id = l.order_id
                     WHERE s.status IN ('wc-processing','wc-completed','wc-on-hold')
                       AND s.date_created >= (NOW() - INTERVAL %d DAY)
                     GROUP BY l.product_id
                     ORDER BY sold_qty DESC
                     LIMIT 500",
                    $days
                ),
                ARRAY_A
            );
            foreach ($rows as $row) {
                $pid = absint((int) ($row['product_id'] ?? 0));
                if ($pid <= 0) {
                    continue;
                }
                $sales[$pid] = [
                    'sold_qty' => (int) round((float) ($row['sold_qty'] ?? 0)),
                    'net_revenue' => (float) ($row['net_revenue'] ?? 0),
                ];
            }
        }

        $eventsTable = $wpdb->prefix . self::EVENTS;
        $viewRows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT product_id, COUNT(*) AS views
                 FROM {$eventsTable}
                 WHERE event_name IN ('product_view','view_item')
                   AND product_id IS NOT NULL
                   AND product_id > 0
                   AND created_at >= (NOW() - INTERVAL %d DAY)
                 GROUP BY product_id",
                $days
            ),
            ARRAY_A
        );

        $all = [];
        foreach ($viewRows as $row) {
            $pid = absint((int) ($row['product_id'] ?? 0));
            if ($pid <= 0) {
                continue;
            }
            $all[$pid] = [
                'product_id' => $pid,
                'product_name' => self::get_product_name_by_id($pid),
                'views' => (int) ($row['views'] ?? 0),
                'sold_qty' => isset($sales[$pid]) ? (int) $sales[$pid]['sold_qty'] : 0,
                'net_revenue' => isset($sales[$pid]) ? (float) $sales[$pid]['net_revenue'] : 0.0,
            ];
        }
        foreach ($sales as $pid => $s) {
            if (!isset($all[$pid])) {
                $all[$pid] = [
                    'product_id' => $pid,
                    'product_name' => self::get_product_name_by_id((int) $pid),
                    'views' => 0,
                    'sold_qty' => (int) ($s['sold_qty'] ?? 0),
                    'net_revenue' => (float) ($s['net_revenue'] ?? 0),
                ];
            }
        }

        $out = array_values($all);
        usort($out, static function ($a, $b) {
            $s = (int) ($b['sold_qty'] ?? 0) <=> (int) ($a['sold_qty'] ?? 0);
            if ($s !== 0) {
                return $s;
            }
            return (int) ($b['views'] ?? 0) <=> (int) ($a['views'] ?? 0);
        });
        if (count($out) > $limit) {
            $out = array_slice($out, 0, $limit);
        }

        return new WP_REST_Response([
            'ok' => true,
            'days' => $days,
            'rows' => $out,
        ], 200);
    }

    public static function ingest_event(WP_REST_Request $request): WP_REST_Response {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid JSON'], 400);
        }

        if (!self::is_valid_app_key_request($request)) {
            return new WP_REST_Response(['ok' => false, 'message' => 'Invalid app key'], 403);
        }

        $eventName = sanitize_key((string) ($body['event_name'] ?? ''));
        if ($eventName === '') {
            return new WP_REST_Response(['ok' => false, 'message' => 'event_name required'], 400);
        }

        $userId = !empty($body['user_id']) ? absint($body['user_id']) : 0;
        $installId = sanitize_text_field((string) ($body['install_id'] ?? ''));
        $fcmToken = sanitize_text_field((string) ($body['fcm_token'] ?? ''));
        $platform = sanitize_text_field((string) ($body['platform'] ?? ($body['payload']['platform'] ?? '')));
        $payload = is_array($body['payload'] ?? null) ? $body['payload'] : [];
        $appVersion = sanitize_text_field((string) ($body['app_version'] ?? ($payload['app_version'] ?? '')));

        if ($fcmToken !== '') {
            self::upsert_token($userId, $installId, $fcmToken, $platform, $appVersion);
        }
        self::store_event($eventName, $userId, $installId, $payload);
        self::dispatch_event_automation($eventName, $userId, $installId, $payload);

        return new WP_REST_Response(['ok' => true], 200);
    }

    public static function notify_new_order(int $orderId): void {
        $order = wc_get_order($orderId);
        if (!$order instanceof WC_Order) {
            return;
        }
        self::apply_wallet_to_order($order);
        self::send_admin_order_push($order);
        $paymentMethod = sanitize_key((string) $order->get_payment_method());
        $paymentType = sanitize_key((string) $order->get_meta('payment_type', true));
        $onlineGateway = sanitize_key((string) $order->get_meta('online_gateway', true));
        if ($paymentMethod === 'snapmint' || $paymentType === 'snapmint' || $onlineGateway === 'snapmint') {
            return;
        }
        $uid = (int) $order->get_customer_id();
        if ($uid <= 0) {
            return;
        }

        $title = 'Order Placed';
        $body = sprintf('Order #%d created. Status: %s', $orderId, ucfirst(str_replace('-', ' ', (string) $order->get_status())));
        $data = ['type' => 'order_created', 'order_id' => (string) $orderId, 'status' => (string) $order->get_status()];
        self::send_to_user_topic($uid, $title, $body, $data);
    }

    private static function send_admin_order_push(WC_Order $order): void {
        $orderId = (int) $order->get_id();
        if ($orderId <= 0) {
            return;
        }

        $customerId = (int) $order->get_customer_id();
        $customerName = trim((string) $order->get_formatted_billing_full_name());
        if ($customerName === '') {
            $customerName = trim((string) $order->get_billing_first_name() . ' ' . $order->get_billing_last_name());
        }
        if ($customerName === '') {
            $customerName = $customerId > 0 ? 'User #' . $customerId : 'Guest customer';
        }

        $billingEmail = trim((string) $order->get_billing_email());
        $paymentLabel = trim((string) $order->get_payment_method_title());
        $statusLabel = ucfirst(str_replace('-', ' ', (string) $order->get_status()));
        $amountLabel = wp_strip_all_tags(wp_specialchars_decode((string) $order->get_formatted_order_total(), ENT_QUOTES));

        $bodyParts = [
            'Order #' . $orderId,
            $customerName,
            $amountLabel !== '' ? $amountLabel : '',
            $statusLabel !== '' ? 'Status: ' . $statusLabel : '',
        ];
        if ($billingEmail !== '') {
            $bodyParts[] = $billingEmail;
        }
        if ($paymentLabel !== '') {
            $bodyParts[] = 'Payment: ' . $paymentLabel;
        }

        $data = [
            'type' => 'admin_order_created',
            'order_id' => (string) $orderId,
            'status' => (string) $order->get_status(),
            'customer_id' => (string) $customerId,
            'customer_email' => $billingEmail,
            'customer_name' => $customerName,
            'payment_method' => sanitize_key((string) $order->get_payment_method()),
        ];

        self::send_to_admin_topic(
            'New Order Received',
            implode(' | ', array_values(array_filter($bodyParts, static fn($part) => $part !== ''))),
            $data
        );
    }

    public static function notify_order_status_changed(int $orderId, string $oldStatus, string $newStatus, $order): void {
        if (!$order instanceof WC_Order) {
            $order = wc_get_order($orderId);
        }
        if (!$order instanceof WC_Order) {
            return;
        }

        $oldStatus = sanitize_key((string) $oldStatus);
        $newStatus = sanitize_key((string) $newStatus);

        // A newly created app checkout order starts in pending before the user
        // has had a real chance to pay. Do not send "pending" recovery pushes
        // during that initial checkout step.
        if ($newStatus === 'pending' && in_array($oldStatus, ['', 'pending', 'checkout-draft', 'draft', 'auto-draft'], true)) {
            return;
        }

        $uid = (int) $order->get_customer_id();
        $installId = sanitize_text_field((string) $order->get_meta('app_install_id', true));
        $title = 'Order Status Updated';
        $body = sprintf('Order #%d: %s -> %s', $orderId, ucfirst(str_replace('-', ' ', $oldStatus)), ucfirst(str_replace('-', ' ', $newStatus)));
        $data = ['type' => 'order_status_updated', 'order_id' => (string) $orderId, 'old_status' => $oldStatus, 'status' => $newStatus];

        if ($uid > 0) {
            self::send_to_user_topic($uid, $title, $body, $data);
        }
        self::send_to_tokens($uid, $installId, $title, $body, $data);

        if (in_array($newStatus, ['pending', 'cancelled'], true)) {
            $coupon = self::create_coupon($uid, $installId, "order_{$newStatus}");
            self::send_to_tokens($uid, $installId, '2% Coupon', "Use {$coupon} and save 2% on your next order.", ['type' => 'coupon', 'coupon_code' => $coupon]);
        }
    }

    private static function store_event(string $eventName, int $userId, string $installId, array $payload): void {
        global $wpdb;
        $table = $wpdb->prefix . self::EVENTS;
        $wpdb->insert($table, [
            'event_name' => $eventName,
            'user_id' => $userId > 0 ? $userId : null,
            'install_id' => $installId !== '' ? $installId : null,
            'order_id' => !empty($payload['order_id']) ? absint($payload['order_id']) : null,
            'product_id' => !empty($payload['product_id']) ? absint($payload['product_id']) : null,
            'payload' => wp_json_encode($payload),
            'created_at' => current_time('mysql'),
        ], ['%s', '%d', '%s', '%d', '%d', '%s', '%s']);
    }

    private static function upsert_token(int $userId, string $installId, string $token, string $platform, string $appVersion = ''): void {
        global $wpdb;
        $table = $wpdb->prefix . self::TOKENS;
        $wpdb->replace($table, [
            'user_id' => $userId > 0 ? $userId : null,
            'install_id' => $installId !== '' ? $installId : null,
            'fcm_token' => $token,
            'platform' => $platform !== '' ? $platform : null,
            'app_version' => $appVersion !== '' ? $appVersion : null,
            'last_seen' => current_time('mysql'),
        ], ['%d', '%s', '%s', '%s', '%s', '%s']);
    }

    private static function dispatch_event_automation(string $eventName, int $userId, string $installId, array $payload): void {
        if ($eventName === 'repeat_product_interest') {
            $name = sanitize_text_field((string) ($payload['product_name'] ?? 'this product'));
            $coupon = self::create_coupon($userId, $installId, 'watch');
            self::send_to_tokens($userId, $installId, 'Still interested?', "You viewed {$name} many times. Use {$coupon} for 2% OFF.", ['type' => 'repeat_watch', 'coupon_code' => $coupon]);
        }
        if ($eventName === 'payment_status') {
            $status = sanitize_key((string) ($payload['status'] ?? ''));
            if ($status === 'payment_not_completed') {
                $coupon = self::create_coupon($userId, $installId, 'payment_retry');
                self::send_to_tokens($userId, $installId, 'Complete your order', "Payment pending. Use {$coupon} for 2% OFF.", ['type' => 'payment_retry', 'coupon_code' => $coupon]);
            }
        }
    }

    private static function send_bulk_cart_recovery(int $lookbackDays): array {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT
                    CASE WHEN user_id IS NOT NULL AND user_id > 0 THEN user_id ELSE 0 END AS user_id,
                    CASE WHEN install_id IS NOT NULL THEN install_id ELSE '' END AS install_id,
                    MAX(created_at) AS last_seen
                 FROM {$eventsTable}
                 WHERE event_name IN ('cart_add','add_to_cart','cart_updated')
                   AND created_at >= (NOW() - INTERVAL %d DAY)
                   AND (
                    (user_id IS NOT NULL AND user_id > 0)
                    OR (install_id IS NOT NULL AND install_id <> '')
                   )
                 GROUP BY user_id, install_id
                 ORDER BY last_seen DESC",
                $lookbackDays
            ),
            ARRAY_A
        );

        $attempted = 0;
        $skipped = 0;
        foreach ($rows as $row) {
            $userId = absint((int) ($row['user_id'] ?? 0));
            $installId = sanitize_text_field((string) ($row['install_id'] ?? ''));
            $coupon = self::create_coupon($userId, $installId, 'bulk_cart_recovery');
            if ($coupon === '') {
                $skipped++;
                continue;
            }

            $title = 'Cart Reminder';
            $body = "You have items pending in your cart. Use {$coupon} for 2% OFF.";
            $data = ['type' => 'bulk_cart_recovery', 'coupon_code' => $coupon];
            self::send_targeted_push($userId, $installId, $title, $body, $data);
            $attempted++;
        }

        return [
            'targets' => count($rows),
            'attempted' => $attempted,
            'skipped' => $skipped,
        ];
    }

    private static function send_bulk_repeat_view_recovery(): array {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;

        $rows = $wpdb->get_results(
            "SELECT
                CASE WHEN user_id IS NOT NULL AND user_id > 0 THEN user_id ELSE 0 END AS user_id,
                CASE WHEN install_id IS NOT NULL THEN install_id ELSE '' END AS install_id,
                product_id,
                COUNT(*) AS view_count
             FROM {$eventsTable}
             WHERE event_name IN ('product_view','view_item')
               AND created_at >= CURDATE()
               AND product_id IS NOT NULL
               AND product_id > 0
               AND (
                (user_id IS NOT NULL AND user_id > 0)
                OR (install_id IS NOT NULL AND install_id <> '')
               )
             GROUP BY user_id, install_id, product_id
             HAVING COUNT(*) >= 3",
            ARRAY_A
        );

        $actors = [];
        foreach ($rows as $row) {
            $userId = absint((int) ($row['user_id'] ?? 0));
            $installId = sanitize_text_field((string) ($row['install_id'] ?? ''));
            $key = $userId > 0 ? 'u:' . $userId : 'g:' . $installId;
            if (!isset($actors[$key])) {
                $actors[$key] = [
                    'user_id' => $userId,
                    'install_id' => $installId,
                    'products' => 0,
                    'max_views' => 0,
                ];
            }
            $actors[$key]['products']++;
            $actors[$key]['max_views'] = max($actors[$key]['max_views'], (int) ($row['view_count'] ?? 0));
        }

        $attempted = 0;
        $skipped = 0;
        foreach ($actors as $actor) {
            $userId = (int) $actor['user_id'];
            $installId = (string) $actor['install_id'];
            $coupon = self::create_coupon($userId, $installId, 'bulk_repeat_views');
            if ($coupon === '') {
                $skipped++;
                continue;
            }

            $title = 'Still Interested?';
            $body = sprintf(
                'You viewed %d product(s) multiple times today. Use %s for 2%% OFF.',
                (int) $actor['products'],
                $coupon
            );
            $data = [
                'type' => 'bulk_repeat_view_recovery',
                'coupon_code' => $coupon,
                'products_count' => (string) ((int) $actor['products']),
                'max_views' => (string) ((int) $actor['max_views']),
            ];
            self::send_targeted_push($userId, $installId, $title, $body, $data);
            $attempted++;
        }

        return [
            'targets' => count($actors),
            'attempted' => $attempted,
            'skipped' => $skipped,
        ];
    }

    private static function execute_campaign(array $campaign): array {
        $targets = self::resolve_campaign_targets(
            (string) ($campaign['target_mode'] ?? 'all'),
            is_array($campaign['actor_keys'] ?? null) ? $campaign['actor_keys'] : [],
            (string) ($campaign['audience_filter'] ?? 'any'),
            (int) ($campaign['lookback_days'] ?? 7),
            (int) ($campaign['product_id'] ?? 0)
        );

        $title = sanitize_text_field((string) ($campaign['title'] ?? ''));
        $body = sanitize_text_field((string) ($campaign['body'] ?? ''));
        $deepLink = esc_url_raw((string) ($campaign['deep_link'] ?? ''));
        $imageUrl = esc_url_raw((string) ($campaign['image_url'] ?? ''));
        $couponCode = sanitize_text_field((string) ($campaign['coupon_code'] ?? ''));
        $data = [
            'type' => 'custom_campaign',
            'target_mode' => (string) ($campaign['target_mode'] ?? 'all'),
            'audience_filter' => (string) ($campaign['audience_filter'] ?? 'any'),
        ];
        if ($deepLink !== '') {
            $data['deep_link'] = $deepLink;
        }
        if ($imageUrl !== '') {
            $data['image_url'] = $imageUrl;
        }
        if ($couponCode !== '') {
            $data['coupon_code'] = $couponCode;
        }

        $attempted = 0;
        foreach ($targets as $target) {
            $userId = (int) ($target['user_id'] ?? 0);
            $installId = (string) ($target['install_id'] ?? '');
            self::send_targeted_push($userId, $installId, $title, $body, $data);
            $attempted++;
        }

        return [
            'targets' => count($targets),
            'attempted' => $attempted,
        ];
    }

    private static function resolve_campaign_targets(string $targetMode, array $actorKeys, string $audienceFilter, int $lookbackDays, int $productId): array {
        $base = self::base_targets_by_mode($targetMode, $actorKeys);
        if (empty($base) || $audienceFilter === 'any') {
            return array_values($base);
        }

        $filteredActorKeys = self::actor_keys_for_filter($audienceFilter, $lookbackDays, $productId);
        if (empty($filteredActorKeys)) {
            return [];
        }

        $out = [];
        foreach ($base as $key => $target) {
            if (isset($filteredActorKeys[$key])) {
                $out[$key] = $target;
            }
        }
        return array_values($out);
    }

    private static function base_targets_by_mode(string $targetMode, array $actorKeys): array {
        global $wpdb;
        $table = $wpdb->prefix . self::TOKENS;
        $out = [];

        if ($targetMode === 'selected') {
            foreach ($actorKeys as $k) {
                $actor = self::parse_actor_key((string) $k);
                $key = self::actor_key($actor['user_id'], $actor['install_id']);
                if ($key === '') {
                    continue;
                }
                $out[$key] = $actor;
            }
            return $out;
        }

        if ($targetMode === 'guest_only') {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT 0 AS user_id, install_id
                     FROM {$table}
                     WHERE install_id IS NOT NULL
                       AND install_id <> ''
                       AND (user_id IS NULL OR user_id = 0)
                     GROUP BY install_id
                     ORDER BY MAX(last_seen) DESC
                     LIMIT %d",
                    self::MAX_CAMPAIGN_TARGETS
                ),
                ARRAY_A
            );
        } else {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT
                        CASE WHEN user_id IS NOT NULL AND user_id > 0 THEN user_id ELSE 0 END AS user_id,
                        CASE WHEN install_id IS NOT NULL THEN install_id ELSE '' END AS install_id
                     FROM {$table}
                     GROUP BY user_id, install_id
                     ORDER BY MAX(last_seen) DESC
                     LIMIT %d",
                    self::MAX_CAMPAIGN_TARGETS
                ),
                ARRAY_A
            );
        }

        foreach ($rows as $row) {
            $userId = absint((int) ($row['user_id'] ?? 0));
            $installId = sanitize_text_field((string) ($row['install_id'] ?? ''));
            $key = self::actor_key($userId, $installId);
            if ($key === '') {
                continue;
            }
            $out[$key] = ['user_id' => $userId, 'install_id' => $installId];
        }

        return $out;
    }

    private static function actor_keys_for_filter(string $audienceFilter, int $lookbackDays, int $productId): array {
        global $wpdb;
        $eventsTable = $wpdb->prefix . self::EVENTS;
        $lookbackDays = max(1, min(60, $lookbackDays));

        if ($audienceFilter === 'cart') {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT user_id,install_id
                     FROM {$eventsTable}
                     WHERE event_name IN ('cart_add','add_to_cart','cart_updated')
                       AND created_at >= (NOW() - INTERVAL %d DAY)
                     GROUP BY user_id,install_id",
                    $lookbackDays
                ),
                ARRAY_A
            );
        } elseif ($audienceFilter === 'product') {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT user_id,install_id
                     FROM {$eventsTable}
                     WHERE event_name IN ('product_view','view_item')
                       AND product_id = %d
                       AND created_at >= (NOW() - INTERVAL %d DAY)
                     GROUP BY user_id,install_id",
                    $productId,
                    $lookbackDays
                ),
                ARRAY_A
            );
        } elseif ($audienceFilter === 'repeat_views') {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT user_id,install_id
                     FROM {$eventsTable}
                     WHERE event_name IN ('product_view','view_item')
                       AND created_at >= (NOW() - INTERVAL %d DAY)
                     GROUP BY user_id,install_id,product_id
                     HAVING COUNT(*) >= 3",
                    $lookbackDays
                ),
                ARRAY_A
            );
        } else {
            return [];
        }

        $keys = [];
        foreach ($rows as $row) {
            $key = self::actor_key(absint((int) ($row['user_id'] ?? 0)), sanitize_text_field((string) ($row['install_id'] ?? '')));
            if ($key !== '') {
                $keys[$key] = true;
            }
        }
        return $keys;
    }

    private static function create_coupon(int $userId, string $installId, string $reason): string {
        if (!class_exists('WC_Coupon')) {
            return '';
        }
        $scope = $userId > 0 ? "u{$userId}" : ($installId !== '' ? $installId : 'all');
        $cacheKey = 'yana_coupon_' . md5($scope . '_' . $reason);
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

    private static function send_targeted_push(int $userId, string $installId, string $title, string $body, array $data): void {
        if ($userId > 0) {
            self::send_to_user_topic($userId, $title, $body, $data);
        }
        self::send_to_tokens($userId, $installId, $title, $body, $data);
    }

    private static function send_to_user_topic(int $userId, string $title, string $body, array $data): void {
        $topic = 'user_' . $userId;
        self::send_v1_message('topic', $topic, $title, $body, $data);
    }

    private static function send_to_admin_topic(string $title, string $body, array $data): void {
        self::send_v1_message('topic', self::ADMIN_ORDERS_TOPIC, $title, $body, $data);
    }

    private static function send_to_tokens(int $userId, string $installId, string $title, string $body, array $data): void {
        $tokens = self::resolve_tokens($userId, $installId);
        foreach ($tokens as $token) {
            self::send_v1_message('token', $token, $title, $body, $data);
        }
    }

    private static function parse_actor_key(string $actorKey): array {
        $actorKey = trim($actorKey);
        if ($actorKey === '') {
            return ['user_id' => 0, 'install_id' => ''];
        }
        if (strpos($actorKey, 'u:') === 0) {
            return ['user_id' => absint(substr($actorKey, 2)), 'install_id' => ''];
        }
        if (strpos($actorKey, 'g:') === 0) {
            return ['user_id' => 0, 'install_id' => sanitize_text_field(substr($actorKey, 2))];
        }
        return ['user_id' => absint($actorKey), 'install_id' => ''];
    }

    private static function actor_key(int $userId, string $installId): string {
        if ($userId > 0) {
            return 'u:' . $userId;
        }
        $installId = trim($installId);
        if ($installId !== '') {
            return 'g:' . $installId;
        }
        return '';
    }

    private static function is_valid_app_key_request(WP_REST_Request $request): bool {
        $expectedKey = (string) get_option(self::OPT_APP_KEY, self::DEF_APP_KEY);
        if ($expectedKey === '') {
            return true;
        }
        $receivedKey = (string) $request->get_header('X-Yana-App');
        return hash_equals($expectedKey, $receivedKey);
    }

    private static function get_wallet_settings(): array {
        $raw = get_option(self::OPT_WALLET_SETTINGS, []);
        $state = is_array($raw) ? $raw : [];
        return [
            'enabled' => !empty($state['enabled']),
            'signup_bonus' => max(0, round((float) ($state['signup_bonus'] ?? 200), 2)),
            'min_billing' => max(0, round((float) ($state['min_billing'] ?? 2000), 2)),
        ];
    }

    private static function get_gateway_settings(): array {
        $raw = get_option(self::OPT_GATEWAY_SETTINGS, []);
        $state = is_array($raw) ? $raw : [];
        return [
            'cashfree_enabled' => !empty($state['cashfree_enabled']),
            'payu_enabled' => !empty($state['payu_enabled']),
        ];
    }

    private static function ensure_wallet_tables(): void {
        global $wpdb;
        $wallets = $wpdb->prefix . self::WALLETS;
        $walletTx = $wpdb->prefix . self::WALLETS_TX;
        if (self::table_exists($wallets) && self::table_exists($walletTx)) {
            return;
        }
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        $charset = $wpdb->get_charset_collate();

        dbDelta("CREATE TABLE {$wallets} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NULL,
            install_id VARCHAR(120) NULL,
            actor_key VARCHAR(150) NOT NULL,
            balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            banned TINYINT(1) NOT NULL DEFAULT 0,
            bonus_granted TINYINT(1) NOT NULL DEFAULT 0,
            is_merged TINYINT(1) NOT NULL DEFAULT 0,
            merged_to_actor VARCHAR(150) NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_actor_key (actor_key),
            KEY idx_user_id (user_id),
            KEY idx_install_id (install_id),
            KEY idx_banned (banned),
            KEY idx_is_merged (is_merged),
            KEY idx_merged_to_actor (merged_to_actor)
        ) {$charset};");

        dbDelta("CREATE TABLE {$walletTx} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            actor_key VARCHAR(150) NOT NULL,
            linked_actor VARCHAR(150) NULL,
            tx_type VARCHAR(40) NOT NULL,
            amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            balance_after DECIMAL(12,2) NOT NULL DEFAULT 0.00,
            source VARCHAR(80) NOT NULL,
            meta LONGTEXT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_actor_key (actor_key),
            KEY idx_linked_actor (linked_actor),
            KEY idx_created_at (created_at)
        ) {$charset};");
    }

    private static function wallet_find_by_actor(string $actorKey): ?array {
        global $wpdb;
        if ($actorKey === '') {
            return null;
        }
        $table = $wpdb->prefix . self::WALLETS;
        if (!self::table_exists($table)) {
            return null;
        }
        $row = $wpdb->get_row(
            $wpdb->prepare(
                "SELECT id,user_id,install_id,actor_key,balance,banned,bonus_granted,is_merged,merged_to_actor,created_at,updated_at
                 FROM {$table}
                 WHERE actor_key = %s
                 LIMIT 1",
                $actorKey
            ),
            ARRAY_A
        );
        if (!is_array($row)) {
            return null;
        }
        return [
            'id' => (int) ($row['id'] ?? 0),
            'user_id' => (int) ($row['user_id'] ?? 0),
            'install_id' => (string) ($row['install_id'] ?? ''),
            'actor_key' => (string) ($row['actor_key'] ?? ''),
            'balance' => (float) ($row['balance'] ?? 0),
            'banned' => !empty($row['banned']),
            'bonus_granted' => !empty($row['bonus_granted']),
            'is_merged' => !empty($row['is_merged']),
            'merged_to_actor' => (string) ($row['merged_to_actor'] ?? ''),
            'created_at' => (string) ($row['created_at'] ?? ''),
            'updated_at' => (string) ($row['updated_at'] ?? ''),
        ];
    }

    private static function ensure_wallet_account(int $userId, string $installId): ?array {
        global $wpdb;
        self::ensure_wallet_tables();
        $userId = absint($userId);
        $installId = sanitize_text_field($installId);
        if ($userId > 0) {
            $userActorKey = self::actor_key($userId, '');
            if ($userActorKey === '') {
                return null;
            }
            $userWallet = self::wallet_find_by_actor($userActorKey);
            if ($userWallet === null) {
                $userWallet = self::wallet_create_account($userId, '', 0.0, false);
            }
            if ($userWallet === null) {
                return null;
            }
            $linkedFromInstall = false;
            if ($installId !== '') {
                $guestActorKey = self::actor_key(0, $installId);
                $guestWallet = self::wallet_find_by_actor($guestActorKey);
                if ($guestWallet !== null) {
                    if (empty($guestWallet['is_merged'])) {
                        self::merge_guest_wallet_into_user($guestWallet, $userWallet);
                    }
                    $linkedFromInstall = true;
                }
            }
            $resolved = self::wallet_find_by_actor($userActorKey);
            if ($resolved === null) {
                return null;
            }
            $resolved['linked_from_install'] = $linkedFromInstall;
            return $resolved;
        }

        $actorKey = self::actor_key(0, $installId);
        if ($actorKey === '') {
            return null;
        }
        $existing = self::wallet_find_by_actor($actorKey);
        if ($existing !== null) {
            $existing['linked_from_install'] = false;
            return $existing;
        }
        $created = self::wallet_create_account(0, $installId, null, true);
        if ($created === null) {
            return null;
        }
        $created['linked_from_install'] = false;
        return $created;
    }

    private static function wallet_create_account(int $userId, string $installId, ?float $initialBonus = null, bool $withInstallBonusLog = true): ?array {
        global $wpdb;
        $table = $wpdb->prefix . self::WALLETS;
        if (!self::table_exists($table)) {
            return null;
        }
        $actorKey = self::actor_key($userId, $installId);
        if ($actorKey === '') {
            return null;
        }
        $settings = self::get_wallet_settings();
        $bonus = $initialBonus ?? (float) ($settings['signup_bonus'] ?? 200);
        $now = current_time('mysql');

        $wpdb->insert($table, [
            'user_id' => $userId > 0 ? $userId : null,
            'install_id' => $installId !== '' ? $installId : null,
            'actor_key' => $actorKey,
            'balance' => $bonus,
            'banned' => 0,
            'bonus_granted' => 1,
            'is_merged' => 0,
            'merged_to_actor' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ], ['%d', '%s', '%s', '%f', '%d', '%d', '%d', '%s', '%s', '%s']);

        if ($withInstallBonusLog && $bonus > 0) {
            self::wallet_log_tx(
                $actorKey,
                'credit',
                $bonus,
                $bonus,
                'install_bonus',
                ['user_id' => $userId, 'install_id' => $installId]
            );
        }
        return self::wallet_find_by_actor($actorKey);
    }

    private static function merge_guest_wallet_into_user(array $guestWallet, array $userWallet): void {
        global $wpdb;
        $guestActor = (string) ($guestWallet['actor_key'] ?? '');
        $userActor = (string) ($userWallet['actor_key'] ?? '');
        if ($guestActor === '' || $userActor === '' || $guestActor === $userActor) {
            return;
        }
        $guestBalance = max(0, round((float) ($guestWallet['balance'] ?? 0), 2));
        $isGuestBanned = !empty($guestWallet['banned']);

        if ($guestBalance > 0) {
            self::wallet_adjust_balance(
                $userActor,
                $guestBalance,
                'merge_from_guest',
                ['from_actor' => $guestActor]
            );
            self::wallet_log_tx(
                $guestActor,
                'debit',
                -$guestBalance,
                0.0,
                'merged_to_user',
                ['to_actor' => $userActor],
                $userActor
            );
        }
        if ($isGuestBanned && empty($userWallet['banned'])) {
            self::wallet_set_ban($userActor, 1);
        }

        $walletTable = $wpdb->prefix . self::WALLETS;
        $wpdb->update(
            $walletTable,
            [
                'balance' => 0,
                'is_merged' => 1,
                'merged_to_actor' => $userActor,
                'updated_at' => current_time('mysql'),
            ],
            ['id' => (int) ($guestWallet['id'] ?? 0)],
            ['%f', '%d', '%s', '%s'],
            ['%d']
        );

        $txTable = $wpdb->prefix . self::WALLETS_TX;
        if (self::table_exists($txTable)) {
            $wpdb->update(
                $txTable,
                ['linked_actor' => $userActor],
                ['actor_key' => $guestActor, 'linked_actor' => null],
                ['%s'],
                ['%s', '%s']
            );
        }
    }

    private static function wallet_adjust_balance(string $actorKey, float $delta, string $source = 'manual_adjust', array $meta = []): ?array {
        global $wpdb;
        $wallet = self::wallet_find_by_actor($actorKey);
        if ($wallet === null) {
            return null;
        }
        $newBalance = max(0, round(((float) $wallet['balance']) + $delta, 2));
        $table = $wpdb->prefix . self::WALLETS;
        $wpdb->update(
            $table,
            ['balance' => $newBalance, 'updated_at' => current_time('mysql')],
            ['id' => (int) $wallet['id']],
            ['%f', '%s'],
            ['%d']
        );
        self::wallet_log_tx(
            $actorKey,
            $delta >= 0 ? 'credit' : 'debit',
            $delta,
            $newBalance,
            $source,
            $meta
        );
        return self::wallet_find_by_actor($actorKey);
    }

    private static function wallet_set_ban(string $actorKey, int $banned): ?array {
        global $wpdb;
        $wallet = self::wallet_find_by_actor($actorKey);
        if ($wallet === null) {
            return null;
        }
        $table = $wpdb->prefix . self::WALLETS;
        $wpdb->update(
            $table,
            ['banned' => $banned ? 1 : 0, 'updated_at' => current_time('mysql')],
            ['id' => (int) $wallet['id']],
            ['%d', '%s'],
            ['%d']
        );
        return self::wallet_find_by_actor($actorKey);
    }

    private static function wallet_log_tx(string $actorKey, string $txType, float $amount, float $balanceAfter, string $source, array $meta = [], ?string $linkedActor = null): void {
        global $wpdb;
        self::ensure_wallet_tables();
        if ($actorKey === '') {
            return;
        }
        $table = $wpdb->prefix . self::WALLETS_TX;
        if (!self::table_exists($table)) {
            return;
        }
        $linkedActor = sanitize_text_field((string) $linkedActor);
        $wpdb->insert($table, [
            'actor_key' => $actorKey,
            'linked_actor' => $linkedActor !== '' ? $linkedActor : null,
            'tx_type' => sanitize_key($txType),
            'amount' => round($amount, 2),
            'balance_after' => round($balanceAfter, 2),
            'source' => sanitize_key($source),
            'meta' => !empty($meta) ? wp_json_encode($meta) : null,
            'created_at' => current_time('mysql'),
        ], ['%s', '%s', '%s', '%f', '%f', '%s', '%s', '%s']);
    }

    private static function wallet_transactions_for_actor(string $actorKey, int $limit = 50): array {
        global $wpdb;
        self::ensure_wallet_tables();
        if ($actorKey === '') {
            return [];
        }
        $table = $wpdb->prefix . self::WALLETS_TX;
        if (!self::table_exists($table)) {
            return [];
        }
        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT id,linked_actor,tx_type,amount,balance_after,source,meta,created_at
                 FROM {$table}
                 WHERE actor_key = %s
                 ORDER BY id DESC
                 LIMIT %d",
                $actorKey,
                max(1, min(200, $limit))
            ),
            ARRAY_A
        );
        $out = [];
        foreach ((array) $rows as $row) {
            $meta = json_decode((string) ($row['meta'] ?? ''), true);
            $out[] = [
                'id' => (int) ($row['id'] ?? 0),
                'linked_actor' => (string) ($row['linked_actor'] ?? ''),
                'tx_type' => (string) ($row['tx_type'] ?? ''),
                'amount' => round((float) ($row['amount'] ?? 0), 2),
                'balance_after' => round((float) ($row['balance_after'] ?? 0), 2),
                'source' => (string) ($row['source'] ?? ''),
                'meta' => is_array($meta) ? $meta : [],
                'created_at' => (string) ($row['created_at'] ?? ''),
            ];
        }
        return $out;
    }

    private static function resolve_wallet_for_admin_inputs(string $actorKeyInput, int $userIdInput, string $installIdInput): ?array {
        $actorKeyInput = sanitize_text_field($actorKeyInput);
        $installIdInput = sanitize_text_field($installIdInput);
        $userIdInput = absint($userIdInput);

        if ($actorKeyInput !== '') {
            $actor = self::parse_actor_key($actorKeyInput);
            return self::ensure_wallet_account((int) ($actor['user_id'] ?? 0), (string) ($actor['install_id'] ?? ''));
        }
        if ($userIdInput > 0 || $installIdInput !== '') {
            return self::ensure_wallet_account($userIdInput, $installIdInput);
        }
        return null;
    }

    private static function apply_wallet_to_order(WC_Order $order): void {
        $alreadyApplied = (int) $order->get_meta('_yana_wallet_applied', true);
        if ($alreadyApplied === 1) {
            return;
        }
        $requested = round((float) $order->get_meta('wallet_used_amount', true), 2);
        if ($requested <= 0) {
            $order->update_meta_data('_yana_wallet_applied', 1);
            $order->save_meta_data();
            return;
        }

        $userId = (int) $order->get_customer_id();
        $installId = sanitize_text_field((string) $order->get_meta('app_install_id', true));
        $wallet = self::ensure_wallet_account($userId, $installId);
        if ($wallet === null) {
            return;
        }

        $settings = self::get_wallet_settings();
        $billForRule = (float) $order->get_subtotal() + (float) $order->get_shipping_total();
        $eligible = !empty($settings['enabled']) && empty($wallet['banned']) && $billForRule >= (float) ($settings['min_billing'] ?? 0);
        $allowed = $eligible ? min($requested, (float) ($wallet['balance'] ?? 0)) : 0.0;
        $allowed = max(0, round($allowed, 2));
        $difference = max(0, round($requested - $allowed, 2));

        if ($difference > 0 && class_exists('WC_Order_Item_Fee')) {
            $fee = new WC_Order_Item_Fee();
            $fee->set_name('Wallet Validation Adjustment');
            $fee->set_amount($difference);
            $fee->set_total($difference);
            $fee->set_tax_class('');
            $fee->set_tax_status('none');
            $order->add_item($fee);
            $order->calculate_totals(false);
        }

        if ($allowed > 0) {
            self::wallet_adjust_balance((string) $wallet['actor_key'], -$allowed, 'wallet_usage', [
                'order_id' => $order->get_id(),
            ]);
        }

        $order->update_meta_data('wallet_used_amount', number_format($allowed, 2, '.', ''));
        $order->update_meta_data('wallet_actor_key', (string) $wallet['actor_key']);
        $order->update_meta_data('_yana_wallet_applied', 1);
        $order->save();
    }

    private static function get_user_email_by_id(int $userId): ?string {
        if ($userId <= 0) {
            return null;
        }
        $user = get_userdata($userId);
        if (!$user || !($user instanceof WP_User)) {
            return null;
        }
        $email = trim((string) $user->user_email);
        return $email !== '' ? $email : null;
    }

    private static function get_user_name_by_id(int $userId): ?string {
        if ($userId <= 0) {
            return null;
        }
        $user = get_userdata($userId);
        if (!$user || !($user instanceof WP_User)) {
            return null;
        }
        $name = trim((string) ($user->display_name ?: $user->user_login));
        return $name !== '' ? $name : null;
    }

    private static function get_product_name_by_id(int $productId): string {
        if ($productId <= 0) {
            return 'Product';
        }
        $title = get_the_title($productId);
        $title = is_string($title) ? trim($title) : '';
        if ($title !== '') {
            return $title;
        }
        return 'Product #' . $productId;
    }

    private static function table_exists(string $table): bool {
        global $wpdb;
        $found = $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $table));
        return is_string($found) && $found === $table;
    }

    private static function get_update_notice_state(): array {
        $raw = get_option(self::OPT_UPDATE_NOTICE_STATE, []);
        $state = is_array($raw) ? $raw : [];
        return [
            'campaign_id' => max(0, (int) ($state['campaign_id'] ?? 0)),
            'active' => !empty($state['active']),
            'title' => (string) ($state['title'] ?? 'Update Available'),
            'message' => (string) ($state['message'] ?? 'Please update the app for the best experience.'),
            'url' => (string) ($state['url'] ?? self::DEF_UPDATE_NOTICE_URL),
            'min_version' => (string) ($state['min_version'] ?? ''),
            'latest_version' => (string) ($state['latest_version'] ?? ''),
            'force_update' => !empty($state['force_update']),
            'updated_at' => (string) ($state['updated_at'] ?? ''),
        ];
    }

    private static function get_home_popup_state(): array {
        $raw = get_option(self::OPT_HOME_POPUP_STATE, []);
        $state = is_array($raw) ? $raw : [];
        return [
            'campaign_id' => trim((string) ($state['campaign_id'] ?? '')),
            'active' => !empty($state['active']),
            'title' => (string) ($state['title'] ?? 'Important Update'),
            'message' => (string) ($state['message'] ?? ''),
            'button_text' => (string) ($state['button_text'] ?? 'Got it'),
            'action_url' => (string) ($state['action_url'] ?? ''),
            'updated_at' => (string) ($state['updated_at'] ?? ''),
        ];
    }

    private static function has_seen_home_popup_campaign(string $campaignId, int $userId, string $installId): bool {
        global $wpdb;
        $campaignId = trim($campaignId);
        $installId = sanitize_text_field($installId);
        if ($campaignId === '') {
            return false;
        }

        $table = $wpdb->prefix . self::EVENTS;
        if (!self::table_exists($table)) {
            return false;
        }

        $campaignLike = '%"campaign_id":"' . $wpdb->esc_like($campaignId) . '"%';
        $eventNames = ['home_popup_view', 'home_popup_close', 'home_popup_cta', 'home_popup_dismiss'];

        if ($userId > 0 && $installId !== '') {
            $count = (int) $wpdb->get_var($wpdb->prepare(
                "SELECT COUNT(1)
                 FROM {$table}
                 WHERE event_name IN (%s, %s, %s, %s)
                   AND payload LIKE %s
                   AND (user_id = %d OR install_id = %s)",
                $eventNames[0],
                $eventNames[1],
                $eventNames[2],
                $eventNames[3],
                $campaignLike,
                $userId,
                $installId
            ));
            return $count > 0;
        }

        if ($userId > 0) {
            $count = (int) $wpdb->get_var($wpdb->prepare(
                "SELECT COUNT(1)
                 FROM {$table}
                 WHERE event_name IN (%s, %s, %s, %s)
                   AND payload LIKE %s
                   AND user_id = %d",
                $eventNames[0],
                $eventNames[1],
                $eventNames[2],
                $eventNames[3],
                $campaignLike,
                $userId
            ));
            return $count > 0;
        }

        if ($installId !== '') {
            $count = (int) $wpdb->get_var($wpdb->prepare(
                "SELECT COUNT(1)
                 FROM {$table}
                 WHERE event_name IN (%s, %s, %s, %s)
                   AND payload LIKE %s
                   AND install_id = %s",
                $eventNames[0],
                $eventNames[1],
                $eventNames[2],
                $eventNames[3],
                $campaignLike,
                $installId
            ));
            return $count > 0;
        }

        return false;
    }

    private static function resolve_tokens(int $userId, string $installId): array {
        global $wpdb;
        $table = $wpdb->prefix . self::TOKENS;
        if ($userId <= 0 && $installId === '') {
            return [];
        }

        if ($userId > 0 && $installId !== '') {
            $rows = $wpdb->get_col(
                $wpdb->prepare(
                    "SELECT fcm_token
                     FROM {$table}
                     WHERE user_id = %d OR install_id = %s
                     ORDER BY last_seen DESC
                     LIMIT %d",
                    $userId,
                    $installId,
                    self::MAX_PUSH_TOKENS_PER_TARGET
                )
            );
        } elseif ($userId > 0) {
            $rows = $wpdb->get_col(
                $wpdb->prepare(
                    "SELECT fcm_token
                     FROM {$table}
                     WHERE user_id = %d
                     ORDER BY last_seen DESC
                     LIMIT %d",
                    $userId,
                    self::MAX_PUSH_TOKENS_PER_TARGET
                )
            );
        } else {
            $rows = $wpdb->get_col(
                $wpdb->prepare(
                    "SELECT fcm_token
                     FROM {$table}
                     WHERE install_id = %s
                     ORDER BY last_seen DESC
                     LIMIT %d",
                    $installId,
                    self::MAX_PUSH_TOKENS_PER_TARGET
                )
            );
        }

        $tokens = [];
        $seen = [];
        foreach ((array) $rows as $token) {
            $token = trim((string) $token);
            if ($token === '' || isset($seen[$token])) {
                continue;
            }
            $seen[$token] = true;
            $tokens[] = $token;
        }
        return $tokens;
    }

    private static function send_v1_message(string $targetType, string $targetValue, string $title, string $body, array $data): void {
        $sa = self::get_runtime_service_account();
        if ($sa === null) {
            return;
        }

        $projectId = (string) ($sa['project_id'] ?? '');
        if ($projectId === '') {
            return;
        }

        $access = self::get_access_token($sa);
        if ($access === '') {
            return;
        }

        $message = [
            'notification' => ['title' => $title, 'body' => $body],
            'data' => self::stringify_data($data),
            'android' => ['priority' => 'HIGH', 'notification' => ['sound' => 'default']],
        ];
        $message[$targetType] = $targetValue;

        $url = 'https://fcm.googleapis.com/v1/projects/' . rawurlencode($projectId) . '/messages:send';
        wp_remote_post($url, [
            'timeout' => 20,
            'headers' => ['Authorization' => 'Bearer ' . $access, 'Content-Type' => 'application/json'],
            'body' => wp_json_encode(['message' => $message]),
        ]);
    }

    private static function load_service_account(string $path): ?array {
        if ($path === '' || !file_exists($path) || !is_readable($path)) {
            return null;
        }
        $json = file_get_contents($path);
        $data = json_decode((string) $json, true);
        if (!is_array($data) || empty($data['project_id']) || empty($data['client_email']) || empty($data['private_key'])) {
            return null;
        }
        return $data;
    }

    private static function get_runtime_service_account(): ?array {
        if (is_array(self::$runtimeServiceAccount)) {
            return self::$runtimeServiceAccount;
        }
        self::$runtimeServiceAccount = self::load_service_account((string) get_option(self::OPT_SA_PATH, self::DEF_SA_PATH));
        return self::$runtimeServiceAccount;
    }

    private static function get_access_token(array $sa): string {
        if (is_string(self::$runtimeAccessToken) && self::$runtimeAccessToken !== '') {
            return self::$runtimeAccessToken;
        }

        $cached = get_transient(self::TOKEN_CACHE);
        if (is_string($cached) && $cached !== '') {
            self::$runtimeAccessToken = $cached;
            return $cached;
        }

        $jwt = self::build_jwt($sa);
        if ($jwt === '') {
            return '';
        }

        $response = wp_remote_post('https://oauth2.googleapis.com/token', [
            'timeout' => 20,
            'headers' => ['Content-Type' => 'application/x-www-form-urlencoded'],
            'body' => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]),
        ]);
        if (is_wp_error($response)) {
            return '';
        }

        $code = (int) wp_remote_retrieve_response_code($response);
        $body = json_decode((string) wp_remote_retrieve_body($response), true);
        if ($code < 200 || $code >= 300 || empty($body['access_token'])) {
            return '';
        }

        $token = (string) $body['access_token'];
        $expiresIn = isset($body['expires_in']) ? (int) $body['expires_in'] : 3600;
        set_transient(self::TOKEN_CACHE, $token, max(300, $expiresIn - 60));
        self::$runtimeAccessToken = $token;
        return $token;
    }

    private static function build_jwt(array $sa): string {
        $now = time();
        $header = self::base64url_encode(wp_json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claim = self::base64url_encode(wp_json_encode([
            'iss' => (string) $sa['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ]));
        $input = $header . '.' . $claim;
        $signature = '';
        if (!openssl_sign($input, $signature, (string) $sa['private_key'], OPENSSL_ALGO_SHA256)) {
            return '';
        }
        return $input . '.' . self::base64url_encode($signature);
    }

    private static function stringify_data(array $data): array {
        $out = [];
        foreach ($data as $k => $v) {
            $out[(string) $k] = is_scalar($v) ? (string) $v : wp_json_encode($v);
        }
        return $out;
    }

    private static function base64url_encode(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private static function is_privileged_admin(): bool {
        if (!is_user_logged_in()) {
            return false;
        }
        $user = wp_get_current_user();
        if (!$user || !($user instanceof WP_User)) {
            return false;
        }
        $lockedEmail = strtolower(trim((string) apply_filters('yana_privileged_admin_email', self::PRIVILEGED_ADMIN_EMAIL)));
        if ($lockedEmail !== '') {
            return strtolower(trim((string) $user->user_email)) === $lockedEmail;
        }
        return current_user_can('manage_options');
    }

    private static function enforce_privileged_admin(): void {
        if (self::is_privileged_admin()) {
            return;
        }
        wp_die('Access denied. This panel is restricted.');
    }
}

register_activation_hook(__FILE__, ['Yana_App_Event_Automation', 'activate']);
register_deactivation_hook(__FILE__, ['Yana_App_Event_Automation', 'deactivate']);
Yana_App_Event_Automation::bootstrap();
