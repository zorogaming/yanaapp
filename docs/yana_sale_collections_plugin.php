<?php
/**
 * Plugin Name: Yana Sale Collections
 * Description: Daily Sale aur Big Days Sale ke liye WooCommerce product toggles + app REST endpoint.
 * Version: 1.1.2
 * Author: Yana App
 */

if (!defined('ABSPATH')) {
    exit;
}

final class Yana_Sale_Collections {
    private const VERSION = '1.1.2';
    private const META_DAILY = '_yana_daily_sale';
    private const META_BIG_DAYS = '_yana_big_days_sale';
    private const NONCE_ACTION = 'yana_sale_collection_toggle';
    private const OPTION_SETTINGS = 'yana_sale_collection_settings';

    public static function bootstrap(): void {
        add_action('admin_notices', [self::class, 'render_woocommerce_notice']);
        add_action('admin_menu', [self::class, 'register_admin_menu']);
        add_action('admin_init', [self::class, 'register_settings']);
        add_action('rest_api_init', [self::class, 'register_routes']);
        add_action('woocommerce_product_options_general_product_data', [self::class, 'render_product_fields']);
        add_action('woocommerce_process_product_meta', [self::class, 'save_product_fields']);
        add_filter('manage_edit-product_columns', [self::class, 'add_product_columns'], 20);
        add_action('manage_product_posts_custom_column', [self::class, 'render_product_column'], 20, 2);
        add_action('admin_enqueue_scripts', [self::class, 'enqueue_admin_assets']);
        add_action('wp_ajax_yana_toggle_sale_collection', [self::class, 'ajax_toggle_sale_collection']);
    }

    public static function render_woocommerce_notice(): void {
        if (class_exists('WooCommerce')) {
            return;
        }

        echo '<div class="notice notice-error"><p><strong>Yana Sale Collections</strong> requires WooCommerce to be active.</p></div>';
    }

    public static function register_admin_menu(): void {
        add_menu_page(
            __('Yana Sale Collections', 'yana'),
            __('Yana Sale', 'yana'),
            'manage_woocommerce',
            'yana-sale-collections',
            [self::class, 'render_settings_page'],
            'dashicons-megaphone',
            56
        );
    }

    public static function register_settings(): void {
        register_setting(
            'yana_sale_collections',
            self::OPTION_SETTINGS,
            [
                'type' => 'array',
                'sanitize_callback' => [self::class, 'sanitize_settings'],
                'default' => self::default_settings(),
            ]
        );
    }

    public static function sanitize_settings($input): array {
        $input = is_array($input) ? $input : [];
        $festivals = [];
        foreach (self::festival_catalog() as $key => $label) {
            $row = $input['festivals'][$key] ?? [];
            $row = is_array($row) ? $row : [];
            $start = self::parse_festival_date($row['start'] ?? '');
            $end = self::parse_festival_date($row['end'] ?? '');
            $enabled = ($row['enabled'] ?? 'no') === 'yes';
            if ($enabled && (!$start || !$end || $end <= $start)) {
                add_settings_error(self::OPTION_SETTINGS, 'festival_' . $key,
                    sprintf('%s: valid start/end dates required; end must be after start. This festival was disabled.', $label));
                $enabled = false;
            }
            $festivals[$key] = [
                'enabled' => $enabled ? 'yes' : 'no',
                'start' => $start ? $start->format('Y-m-d\TH:i') : '',
                'end' => $end ? $end->format('Y-m-d\TH:i') : '',
            ];
        }
        return [
            'daily_sale_enabled' => (($input['daily_sale_enabled'] ?? 'no') === 'yes') ? 'yes' : 'no',
            'big_days_sale_enabled' => (($input['big_days_sale_enabled'] ?? 'no') === 'yes') ? 'yes' : 'no',
            'festival_schedule_enabled' => (($input['festival_schedule_enabled'] ?? 'no') === 'yes') ? 'yes' : 'no',
            'legacy_big_days_override' => (($input['legacy_big_days_override'] ?? 'no') === 'yes') ? 'yes' : 'no',
            'festivals' => $festivals,
        ];
    }

    private static function default_settings(): array {
        return [
            'daily_sale_enabled' => 'yes',
            'big_days_sale_enabled' => 'yes',
            'festival_schedule_enabled' => 'no',
            'legacy_big_days_override' => 'no',
            'festivals' => [],
        ];
    }

    private static function get_settings(): array {
        $stored = get_option(self::OPTION_SETTINGS, []);
        return wp_parse_args(is_array($stored) ? $stored : [], self::default_settings());
    }

    public static function festival_catalog(): array {
        return [
            'sankranti' => 'Makar Sankranti / Pongal', 'republic_day' => 'Republic Day',
            'shivratri' => 'Maha Shivratri', 'holi' => 'Holi',
            'ugadi' => 'Ugadi / Gudi Padwa', 'eid_fitr' => 'Eid-ul-Fitr',
            'baisakhi' => 'Baisakhi / Vishu / Bihu', 'akshaya_tritiya' => 'Akshaya Tritiya',
            'eid_adha' => 'Eid-ul-Adha', 'rakhi' => 'Raksha Bandhan',
            'independence_day' => 'Independence Day', 'janmashtami' => 'Janmashtami',
            'ganesh' => 'Ganesh Chaturthi', 'onam' => 'Onam',
            'navratri' => 'Navratri / Durga Puja', 'dussehra' => 'Dussehra',
            'dhanteras' => 'Dhanteras', 'diwali' => 'Diwali', 'chhath' => 'Chhath Puja',
            'gurpurab' => 'Guru Nanak Jayanti', 'christmas' => 'Christmas', 'new_year' => 'New Year',
        ];
    }

    private static function parse_festival_date($value): ?DateTimeImmutable {
        if (!is_string($value) || !preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/', $value)) return null;
        $date = DateTimeImmutable::createFromFormat('!Y-m-d\TH:i', $value, wp_timezone());
        return $date && $date->format('Y-m-d\TH:i') === $value ? $date : null;
    }

    // End is exclusive. When schedules overlap, the latest starting sale wins;
    // catalog order breaks equal-start ties, so selection is deterministic.
    public static function festival_state(array $settings, ?DateTimeImmutable $now = null): array {
        $state = ['label' => 'Big Days Sale', 'festival_key' => '', 'starts_at' => null,
            'ends_at' => null, 'next_transition_at' => null,
            'schedule_mode' => ($settings['festival_schedule_enabled'] ?? 'no') === 'yes',
            'enabled' => ($settings['big_days_sale_enabled'] ?? 'yes') === 'yes'];
        if (!$state['schedule_mode']) return $state;
        $state['enabled'] = false;
        $now = $now ?? new DateTimeImmutable('now', wp_timezone());
        $winner = null;
        $next = null;
        $upcoming = null;
        foreach (self::festival_catalog() as $key => $label) {
            $row = $settings['festivals'][$key] ?? [];
            if (($row['enabled'] ?? 'no') !== 'yes') continue;
            $start = self::parse_festival_date($row['start'] ?? '');
            $end = self::parse_festival_date($row['end'] ?? '');
            if (!$start || !$end || $end <= $start) continue;
            if ($start > $now && ($upcoming === null || $start < $upcoming['start'])) {
                $shortNames = ['sankranti' => 'Sankranti', 'ugadi' => 'Ugadi', 'baisakhi' => 'Baisakhi',
                    'eid_fitr' => 'Eid', 'eid_adha' => 'Eid', 'navratri' => 'Navratri',
                    'gurpurab' => 'Gurpurab', 'ganesh' => 'Ganesh Utsav', 'rakhi' => 'Rakhi'];
                $upcoming = [
                    'label' => ($shortNames[$key] ?? $label) . ' Sale',
                    'festival_key' => $key,
                    'start' => $start,
                    'end' => $end,
                ];
            }
            foreach ([$start, $end] as $boundary) {
                if ($boundary > $now && ($next === null || $boundary < $next)) $next = $boundary;
            }
            if ($start <= $now && $now < $end && ($winner === null || $start > $winner)) {
                $winner = $start;
                $shortNames = ['sankranti' => 'Sankranti', 'ugadi' => 'Ugadi', 'baisakhi' => 'Baisakhi',
                    'eid_fitr' => 'Eid', 'eid_adha' => 'Eid', 'navratri' => 'Navratri',
                    'gurpurab' => 'Gurpurab', 'ganesh' => 'Ganesh Utsav', 'rakhi' => 'Rakhi'];
                $state['enabled'] = true;
                $state['label'] = ($shortNames[$key] ?? $label) . ' Sale';
                $state['festival_key'] = $key;
                $state['starts_at'] = $start->format(DATE_ATOM);
                $state['ends_at'] = $end->format(DATE_ATOM);
            }
        }
        $state['next_transition_at'] = $next ? $next->format(DATE_ATOM) : null;
        if ($upcoming !== null) {
            $state['upcoming_label'] = $upcoming['label'];
            $state['upcoming_festival_key'] = $upcoming['festival_key'];
            $state['upcoming_starts_at'] = $upcoming['start']->format(DATE_ATOM);
            $state['upcoming_ends_at'] = $upcoming['end']->format(DATE_ATOM);
        }
        return $state;
    }

    public static function render_settings_page(): void {
        if (!current_user_can('manage_woocommerce')) {
            return;
        }

        $settings = self::get_settings();
        ?>
        <div class="wrap">
            <h1><?php esc_html_e('Yana Sale Collections', 'yana'); ?></h1>
            <?php settings_errors(self::OPTION_SETTINGS); ?>
            <p><?php esc_html_e('Yahan se app ke Daily Sale aur Big Days Sale buttons ko globally enable ya disable kar sakte hain.', 'yana'); ?></p>

            <form method="post" action="options.php">
                <?php settings_fields('yana_sale_collections'); ?>
                <table class="form-table" role="presentation">
                    <tbody>
                        <tr>
                            <th scope="row"><?php esc_html_e('Daily Sale', 'yana'); ?></th>
                            <td>
                                <label>
                                    <input
                                        type="hidden"
                                        name="<?php echo esc_attr(self::OPTION_SETTINGS); ?>[daily_sale_enabled]"
                                        value="no"
                                    />
                                    <input
                                        type="checkbox"
                                        name="<?php echo esc_attr(self::OPTION_SETTINGS); ?>[daily_sale_enabled]"
                                        value="yes"
                                        <?php checked(($settings['daily_sale_enabled'] ?? 'yes') === 'yes'); ?>
                                    />
                                    <?php esc_html_e('Enable Daily Sale for app customers', 'yana'); ?>
                                </label>
                            </td>
                        </tr>
                        <tr>
                            <th scope="row"><?php esc_html_e('Big Days Sale', 'yana'); ?></th>
                            <td>
                                <label>
                                    <input
                                        type="hidden"
                                        name="<?php echo esc_attr(self::OPTION_SETTINGS); ?>[big_days_sale_enabled]"
                                        value="no"
                                    />
                                    <input
                                        type="checkbox"
                                        name="<?php echo esc_attr(self::OPTION_SETTINGS); ?>[big_days_sale_enabled]"
                                        value="yes"
                                        <?php checked(($settings['big_days_sale_enabled'] ?? 'yes') === 'yes'); ?>
                                    />
                                    <?php esc_html_e('Enable Big Days Sale for app customers', 'yana'); ?>
                                </label>
                            </td>
                        </tr>
                    </tbody>
                </table>
                <h2>Festival Schedule — Big Days Sale</h2>
                <p>Festival tick karein aur start/end date-time set karein. Schedule mode mein selected dates ke bahar Big Days Sale band rahegi. Manual Big Days toggle sirf schedule mode OFF hone par apply hota hai.</p>
                <p><strong>Timezone: <?php echo esc_html(wp_timezone_string()); ?></strong>. End time exclusive hai. Overlap mein latest start wala festival dikhega; same start par neeche table ka pehla festival jeetega.</p>
                <label>
                    <input type="checkbox" name="<?php echo esc_attr(self::OPTION_SETTINGS); ?>[festival_schedule_enabled]" value="yes" <?php checked(($settings['festival_schedule_enabled'] ?? 'no') === 'yes'); ?> />
                    Automatically activate Big Days Sale using festival dates
                </label>
                <hr />
                <h3>Old app compatibility</h3>
                <p>Use this manual switch to tell older app versions that Big Days Sale is active, regardless of the festival schedule. Turn it off when the sale ends. Older app versions that already cached a disabled response may need to refresh/reopen the sale screen before this takes effect.</p>
                <label>
                    <input type="hidden" name="<?php echo esc_attr(self::OPTION_SETTINGS); ?>[legacy_big_days_override]" value="no" />
                    <input type="checkbox" name="<?php echo esc_attr(self::OPTION_SETTINGS); ?>[legacy_big_days_override]" value="yes" <?php checked(($settings['legacy_big_days_override'] ?? 'no') === 'yes'); ?> />
                    Manually activate Big Days Sale for old app versions
                </label>
                <table class="widefat striped" style="margin-top:16px;max-width:1000px">
                    <thead><tr><th>Enable festival</th><th>Start date/time</th><th>End date/time</th></tr></thead>
                    <tbody>
                    <?php foreach (self::festival_catalog() as $key => $label):
                        $row = $settings['festivals'][$key] ?? [];
                        $prefix = self::OPTION_SETTINGS . '[festivals][' . $key . ']'; ?>
                        <tr>
                            <td><label><input type="checkbox" name="<?php echo esc_attr($prefix . '[enabled]'); ?>" value="yes" <?php checked(($row['enabled'] ?? 'no') === 'yes'); ?> /> <?php echo esc_html($label); ?></label></td>
                            <td><input aria-label="<?php echo esc_attr($label . ' start'); ?>" type="datetime-local" name="<?php echo esc_attr($prefix . '[start]'); ?>" value="<?php echo esc_attr($row['start'] ?? ''); ?>" /></td>
                            <td><input aria-label="<?php echo esc_attr($label . ' end'); ?>" type="datetime-local" name="<?php echo esc_attr($prefix . '[end]'); ?>" value="<?php echo esc_attr($row['end'] ?? ''); ?>" /></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
                <?php submit_button(__('Save Settings', 'yana')); ?>
            </form>
        </div>
        <?php
    }

    public static function register_routes(): void {
        register_rest_route('wp/v1', '/sale-collection', [
            'methods' => 'GET',
            'callback' => [self::class, 'get_sale_collection'],
            'permission_callback' => '__return_true',
            'args' => [
                'type' => [
                    'required' => true,
                    'sanitize_callback' => 'sanitize_key',
                ],
                'page' => [
                    'required' => false,
                    'default' => 1,
                    'sanitize_callback' => 'absint',
                ],
                'per_page' => [
                    'required' => false,
                    'default' => 20,
                    'sanitize_callback' => 'absint',
                ],
            ],
        ]);
    }

    public static function render_product_fields(): void {
        echo '<div class="options_group">';

        woocommerce_wp_checkbox([
            'id' => self::META_DAILY,
            'label' => __('Daily Sale', 'yana'),
            'description' => __('App ke Daily Sale button me product dikhane ke liye enable karein.', 'yana'),
        ]);

        woocommerce_wp_checkbox([
            'id' => self::META_BIG_DAYS,
            'label' => __('Big Days Sale', 'yana'),
            'description' => __('App ke Big Days Sale button me product dikhane ke liye enable karein.', 'yana'),
        ]);

        echo '</div>';
    }

    public static function save_product_fields(int $product_id): void {
        self::save_checkbox_meta($product_id, self::META_DAILY);
        self::save_checkbox_meta($product_id, self::META_BIG_DAYS);
    }

    private static function save_checkbox_meta(int $product_id, string $meta_key): void {
        $enabled = isset($_POST[$meta_key]) ? 'yes' : 'no';
        update_post_meta($product_id, $meta_key, $enabled);
    }

    public static function add_product_columns(array $columns): array {
        $updated = [];

        foreach ($columns as $key => $label) {
            $updated[$key] = $label;
            if ($key === 'price') {
                $updated['yana_daily_sale'] = __('Daily Sale', 'yana');
                $updated['yana_big_days_sale'] = __('Big Days Sale', 'yana');
            }
        }

        if (!isset($updated['yana_daily_sale'])) {
            $updated['yana_daily_sale'] = __('Daily Sale', 'yana');
        }
        if (!isset($updated['yana_big_days_sale'])) {
            $updated['yana_big_days_sale'] = __('Big Days Sale', 'yana');
        }

        return $updated;
    }

    public static function render_product_column(string $column, int $post_id): void {
        if (!in_array($column, ['yana_daily_sale', 'yana_big_days_sale'], true)) {
            return;
        }

        if (!current_user_can('edit_post', $post_id)) {
            echo '&mdash;';
            return;
        }

        $meta_key = $column === 'yana_daily_sale' ? self::META_DAILY : self::META_BIG_DAYS;
        $checked = get_post_meta($post_id, $meta_key, true) === 'yes';
        $label = $column === 'yana_daily_sale' ? 'Daily Sale' : 'Big Days Sale';

        printf(
            '<label><input type="checkbox" class="yana-sale-toggle" data-product-id="%d" data-meta-key="%s" %s /> %s</label>',
            $post_id,
            esc_attr($meta_key),
            checked($checked, true, false),
            esc_html($label)
        );
    }

    public static function enqueue_admin_assets(string $hook): void {
        if ($hook !== 'edit.php' || (($_GET['post_type'] ?? '') !== 'product')) {
            return;
        }

        wp_enqueue_script('jquery');
        wp_add_inline_script('jquery', self::admin_script());
        wp_localize_script('jquery', 'yanaSaleCollections', [
            'ajaxUrl' => admin_url('admin-ajax.php'),
            'nonce' => wp_create_nonce(self::NONCE_ACTION),
        ]);
    }

    private static function admin_script(): string {
        return <<<JS
jQuery(function($) {
  $(document).on('change', '.yana-sale-toggle', function() {
    const checkbox = $(this);
    $.post(yanaSaleCollections.ajaxUrl, {
      action: 'yana_toggle_sale_collection',
      nonce: yanaSaleCollections.nonce,
      product_id: checkbox.data('product-id'),
      meta_key: checkbox.data('meta-key'),
      enabled: checkbox.is(':checked') ? 'yes' : 'no'
    }).fail(function() {
      checkbox.prop('checked', !checkbox.is(':checked'));
      window.alert('Sale collection update failed.');
    });
  });
});
JS;
    }

    public static function ajax_toggle_sale_collection(): void {
        check_ajax_referer(self::NONCE_ACTION, 'nonce');

        $product_id = absint($_POST['product_id'] ?? 0);
        $meta_key = sanitize_key($_POST['meta_key'] ?? '');
        $enabled = sanitize_text_field($_POST['enabled'] ?? 'no');

        if ($product_id <= 0 || !in_array($meta_key, [self::META_DAILY, self::META_BIG_DAYS], true)) {
            wp_send_json_error(['message' => 'Invalid request'], 400);
        }

        if (!current_user_can('edit_post', $product_id)) {
            wp_send_json_error(['message' => 'Permission denied'], 403);
        }

        update_post_meta($product_id, $meta_key, $enabled === 'yes' ? 'yes' : 'no');
        wp_send_json_success(['ok' => true]);
    }

    public static function get_sale_collection(WP_REST_Request $request): WP_REST_Response {
        $type = sanitize_key((string) $request->get_param('type'));
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(50, max(1, (int) $request->get_param('per_page')));
        $settings = self::get_settings();

        $festival = self::festival_state($settings);
        $legacyOverride = ($settings['legacy_big_days_override'] ?? 'no') === 'yes';
        if ($type === 'big_days_sale' && $legacyOverride) {
            // Existing clients expect the stable Big Days label and enabled flag.
            // Preserve current festival metadata when a scheduled sale is active.
            $festival['enabled'] = true;
            if (($festival['festival_key'] ?? '') === '') {
                $festival['label'] = 'Big Days Sale';
            }
        }
        $config = match ($type) {
            'daily_sale' => [
                'meta_key' => self::META_DAILY,
                'enabled' => ($settings['daily_sale_enabled'] ?? 'yes') === 'yes',
                'label' => 'Daily Sale',
            ],
            'big_days_sale' => [
                'meta_key' => self::META_BIG_DAYS,
                'enabled' => $legacyOverride || $festival['enabled'],
                'label' => $festival['label'],
            ],
            default => null,
        };

        if (!$config) {
            return new WP_REST_Response([
                'ok' => false,
                'message' => 'Invalid sale collection type',
            ], 400);
        }

        $metadata = $type === 'big_days_sale' ? $festival : ['label' => $config['label']];
        $metadata['server_now'] = (new DateTimeImmutable('now', wp_timezone()))->format(DATE_ATOM);
        if ($request->get_param('status_only') === '1') {
            return new WP_REST_Response(array_merge($metadata, [
                'ok' => true, 'enabled' => $config['enabled'], 'type' => $type,
            ]), 200, ['Cache-Control' => 'no-store, max-age=0']);
        }

        if (!$config['enabled']) {
            $disabledMessage = $type === 'big_days_sale'
                ? 'Big Days Sale is available only during special event periods. It can go live at any time, and discounts may go up to 70%. Sometimes products are offered at near-cost pricing.'
                : sprintf('%s is currently disabled by admin.', $config['label']);

            return new WP_REST_Response(array_merge($metadata, [
                'ok' => true,
                'enabled' => false,
                'type' => $type,
                'message' => $disabledMessage,
                'items' => [],
            ]), 200, ['Cache-Control' => 'no-store, max-age=0']);
        }

        $query = new WP_Query([
            'post_type' => 'product',
            'post_status' => 'publish',
            'fields' => 'ids',
            'posts_per_page' => $per_page,
            'paged' => $page,
            'meta_key' => $config['meta_key'],
            'meta_value' => 'yes',
            'orderby' => 'rand',
        ]);

        $items = [];
        foreach ($query->posts as $product_id) {
            $product = wc_get_product($product_id);
            if (!$product instanceof WC_Product || !$product->is_visible()) {
                continue;
            }

            $items[] = self::format_product_for_app($product);
        }

        return new WP_REST_Response(array_merge($metadata, [
            'ok' => true,
            'enabled' => true,
            'type' => $type,
            'page' => $page,
            'per_page' => $per_page,
            'total' => (int) $query->found_posts,
            'pages' => (int) $query->max_num_pages,
            'items' => $items,
        ]), 200, ['Cache-Control' => 'no-store, max-age=0']);
    }

    private static function format_product_for_app(WC_Product $product): array {
        $images = [];
        $main_image_id = $product->get_image_id();
        if ($main_image_id) {
            $src = wp_get_attachment_image_url($main_image_id, 'full');
            if ($src) {
                $images[] = ['src' => $src];
            }
        }

        foreach ($product->get_gallery_image_ids() as $image_id) {
            $src = wp_get_attachment_image_url($image_id, 'full');
            if ($src) {
                $images[] = ['src' => $src];
            }
        }

        return [
            'id' => $product->get_id(),
            'name' => $product->get_name(),
            'price' => (string) $product->get_price(),
            'regular_price' => (string) $product->get_regular_price(),
            'sale_price' => (string) $product->get_sale_price(),
            'description' => (string) $product->get_description(),
            'short_description' => (string) $product->get_short_description(),
            'type' => (string) $product->get_type(),
            'sku' => (string) $product->get_sku(),
            'stock_status' => (string) $product->get_stock_status(),
            'in_stock' => (bool) $product->is_in_stock(),
            'images' => $images,
        ];
    }
}

Yana_Sale_Collections::bootstrap();
