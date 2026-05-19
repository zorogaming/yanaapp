<?php
/**
 * Sample WordPress REST endpoints for dismissible home popup.
 *
 * Public:
 * GET /wp-json/wp/v1/home-popup-status
 *
 * Admin:
 * GET  /wp-json/yana-admin/v1/home-popup
 * POST /wp-json/yana-admin/v1/home-popup
 */

add_action('rest_api_init', function () {
    register_rest_route('wp/v1', '/home-popup-status', [
        'methods' => 'GET',
        'callback' => function () {
            return yana_get_home_popup_state();
        },
        'permission_callback' => '__return_true',
    ]);

    register_rest_route('yana-admin/v1', '/home-popup', [
        [
            'methods' => 'GET',
            'callback' => function () {
                return [
                    'ok' => true,
                    'state' => yana_get_home_popup_state(),
                ];
            },
            'permission_callback' => 'yana_can_manage_home_popup',
        ],
        [
            'methods' => 'POST',
            'callback' => 'yana_handle_home_popup_save',
            'permission_callback' => 'yana_can_manage_home_popup',
        ],
    ]);
});

function yana_can_manage_home_popup() {
    return current_user_can('manage_woocommerce') || current_user_can('manage_options');
}

function yana_get_home_popup_state() {
    $raw = get_option('yana_home_popup_state', []);
    $state = is_array($raw) ? $raw : [];
    return [
        'campaign_id' => max(0, (int) ($state['campaign_id'] ?? 0)),
        'active' => !empty($state['active']),
        'title' => (string) ($state['title'] ?? 'Important Update'),
        'message' => (string) ($state['message'] ?? ''),
        'button_text' => (string) ($state['button_text'] ?? 'Got it'),
        'action_url' => (string) ($state['action_url'] ?? ''),
        'updated_at' => (string) ($state['updated_at'] ?? ''),
        'ok' => true,
    ];
}

function yana_handle_home_popup_save(WP_REST_Request $request) {
    $body = $request->get_json_params();
    if (!is_array($body)) {
        return new WP_REST_Response([
            'ok' => false,
            'message' => 'Invalid payload',
        ], 400);
    }

    $action = sanitize_key((string) ($body['action'] ?? 'activate'));
    $current = yana_get_home_popup_state();

    if ($action === 'deactivate') {
      $state = $current;
      $state['active'] = false;
      $state['updated_at'] = current_time('mysql');
      update_option('yana_home_popup_state', $state, false);
      return ['ok' => true, 'state' => $state];
    }

    $state = [
        'campaign_id' => max(0, (int) ($current['campaign_id'] ?? 0)) + 1,
        'active' => true,
        'title' => sanitize_text_field($body['title'] ?? 'Important Update'),
        'message' => sanitize_textarea_field($body['message'] ?? ''),
        'button_text' => sanitize_text_field($body['button_text'] ?? 'Got it'),
        'action_url' => esc_url_raw($body['action_url'] ?? ''),
        'updated_at' => current_time('mysql'),
    ];
    update_option('yana_home_popup_state', $state, false);

    return ['ok' => true, 'state' => $state];
}
