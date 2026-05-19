<?php
/**
 * Sample WordPress REST endpoints for app growth config.
 *
 * Public:
 * GET /wp-json/wp/v1/growth-config
 *
 * Admin:
 * GET  /wp-json/yana-admin/v1/growth/config
 * POST /wp-json/yana-admin/v1/growth/config
 */

add_action('rest_api_init', function () {
    register_rest_route('wp/v1', '/growth-config', [
        'methods' => 'GET',
        'callback' => function () {
            return yana_get_growth_config_payload();
        },
        'permission_callback' => '__return_true',
    ]);

    register_rest_route('yana-admin/v1', '/growth/config', [
        [
            'methods' => 'GET',
            'callback' => function () {
                return [
                    'ok' => true,
                    'settings' => yana_get_growth_config_payload(),
                ];
            },
            'permission_callback' => 'yana_admin_can_manage_growth',
        ],
        [
            'methods' => 'POST',
            'callback' => 'yana_save_growth_config',
            'permission_callback' => 'yana_admin_can_manage_growth',
        ],
    ]);
});

function yana_admin_can_manage_growth() {
    return current_user_can('manage_woocommerce') || current_user_can('manage_options');
}

function yana_get_growth_config_payload() {
    $defaults = [
        'cashback' => [
            'enabled' => false,
            'spend_amount' => 1000,
            'cashback_amount' => 50,
        ],
        'flash_deal' => [
            'enabled' => false,
            'title' => 'Limited Time Offer',
            'subtitle' => '',
            'ends_at' => '',
            'product_ids' => [],
        ],
        'cross_sell' => [
            'enabled' => false,
            'max_items' => 5,
            'product_map' => new stdClass(),
        ],
    ];

    $saved = get_option('yana_growth_config', []);
    $merged = wp_parse_args(is_array($saved) ? $saved : [], $defaults);
    return $merged;
}

function yana_save_growth_config(WP_REST_Request $request) {
    $payload = $request->get_json_params();
    if (!is_array($payload)) {
        return new WP_REST_Response([
            'ok' => false,
            'message' => 'Invalid payload',
        ], 400);
    }

    $cashback = isset($payload['cashback']) && is_array($payload['cashback']) ? $payload['cashback'] : [];
    $flash = isset($payload['flash_deal']) && is_array($payload['flash_deal']) ? $payload['flash_deal'] : [];
    $cross = isset($payload['cross_sell']) && is_array($payload['cross_sell']) ? $payload['cross_sell'] : [];

    $config = [
        'cashback' => [
            'enabled' => !empty($cashback['enabled']),
            'spend_amount' => (float) ($cashback['spend_amount'] ?? 1000),
            'cashback_amount' => (float) ($cashback['cashback_amount'] ?? 50),
        ],
        'flash_deal' => [
            'enabled' => !empty($flash['enabled']),
            'title' => sanitize_text_field($flash['title'] ?? 'Limited Time Offer'),
            'subtitle' => sanitize_text_field($flash['subtitle'] ?? ''),
            'ends_at' => sanitize_text_field($flash['ends_at'] ?? ''),
            'product_ids' => array_values(array_filter(array_map('intval', (array) ($flash['product_ids'] ?? [])))),
        ],
        'cross_sell' => [
            'enabled' => !empty($cross['enabled']),
            'max_items' => max(1, (int) ($cross['max_items'] ?? 5)),
            'product_map' => yana_sanitize_cross_sell_map($cross['product_map'] ?? []),
        ],
    ];

    update_option('yana_growth_config', $config, false);

    return [
        'ok' => true,
        'settings' => $config,
    ];
}

function yana_sanitize_cross_sell_map($raw) {
    $result = [];
    if (!is_array($raw)) {
        return $result;
    }

    foreach ($raw as $product_id => $suggested_ids) {
        $base_id = (int) $product_id;
        if ($base_id <= 0) {
            continue;
        }

        $ids = array_values(array_filter(array_map('intval', (array) $suggested_ids)));
        if (empty($ids)) {
            continue;
        }
        $result[(string) $base_id] = $ids;
    }

    return $result;
}
