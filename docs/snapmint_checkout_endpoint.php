<?php
/**
 * Ready-to-paste WordPress endpoint for:
 * POST /wp-json/wp/v1/snapmint-checkout-url
 *
 * App flow:
 * 1. Flutter app creates a pending Woo order with payment_method=snapmint.
 * 2. App calls this endpoint with that order_id.
 * 3. This endpoint calls Snapmint /api/pub/carts on the server.
 * 4. Response redirectUrl is returned to the app.
 * 5. App opens redirectUrl inside Snapmint Flutter SDK directly.
 */

add_action('rest_api_init', function () {
    register_rest_route('wp/v1', 'snapmint-checkout-url', array(
        'methods'  => 'POST',
        'callback' => 'yana_snapmint_checkout_url',
    ));
});

function yana_header_value($request, $name) {
    $headers = $request->get_headers();
    $key = strtolower($name);
    if (!isset($headers[$key]) || empty($headers[$key])) {
        return '';
    }
    $value = $headers[$key];
    if (is_array($value)) {
        return (string) reset($value);
    }
    return (string) $value;
}

function yana_wc_order_owner_matches($order, $user_id) {
    $customer_id = (int) $order->get_customer_id();

    if ($customer_id > 0) {
        return $customer_id === (int) $user_id;
    }

    if ((int) $user_id <= 0) {
        return true;
    }

    $user = get_userdata((int) $user_id);
    if (!$user) {
        return false;
    }

    $user_email = strtolower(trim((string) $user->user_email));
    $order_email = strtolower(trim((string) $order->get_billing_email()));
    if (!empty($user_email) && !empty($order_email) && $user_email === $order_email) {
        return true;
    }

    $user_phone = preg_replace('/\D+/', '', (string) get_user_meta((int) $user_id, 'billing_phone', true));
    $order_phone = preg_replace('/\D+/', '', (string) $order->get_billing_phone());

    return !empty($user_phone) && !empty($order_phone) && $user_phone === $order_phone;
}

function yana_snapmint_address_from_order($order, $prefix) {
    $getter = function ($suffix) use ($order, $prefix) {
        $method = 'get_' . $prefix . '_' . $suffix;
        return method_exists($order, $method) ? (string) $order->$method() : '';
    };

    return array(
        'addressLine1' => trim($getter('address_1')),
        'addressLine2' => trim($getter('address_2')),
        'zip'          => (int) preg_replace('/\D+/', '', $getter('postcode')),
        'city'         => trim($getter('city')),
        'state'        => trim($getter('state')),
    );
}

function yana_snapmint_product_lines($order) {
    $products = array();
    foreach ($order->get_items() as $item) {
        if (!$item instanceof WC_Order_Item_Product) {
            continue;
        }

        $product = $item->get_product();
        $product_id = $product ? $product->get_id() : 0;
        $image_url = $product_id ? wp_get_attachment_image_url(get_post_thumbnail_id($product_id), 'full') : '';

        $products[] = array(
            'sku'       => $product ? (string) $product->get_sku() : '',
            'name'      => (string) $item->get_name(),
            'quantity'  => (int) $item->get_quantity(),
            'unitPrice' => wc_format_decimal((float) $item->get_total() / max(1, (int) $item->get_quantity()), 2),
            'itemUrl'   => $product_id ? get_permalink($product_id) : '',
            'imageUrl'  => $image_url ? (string) $image_url : '',
            'udf1'      => (string) $product_id,
            'udf2'      => (string) $item->get_variation_id(),
            'udf3'      => 'woocommerce',
        );
    }

    return $products;
}

function yana_snapmint_checkout_url($request) {
    if (!class_exists('WooCommerce')) {
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'WooCommerce is not active',
        ), 500);
    }

    $expected_app_header = 'YANAWORLDWIDE_8f3K@29xP!mQ2026';
    $incoming_app_header = yana_header_value($request, 'X-Yana-App');
    if (empty($incoming_app_header) || !hash_equals($expected_app_header, $incoming_app_header)) {
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Unauthorized app request',
        ), 401);
    }

    $params = $request->get_json_params();
    $order_id = isset($params['order_id']) ? (int) $params['order_id'] : 0;
    $user_id = isset($params['user_id']) ? (int) $params['user_id'] : 0;
    $device = isset($params['device']) ? sanitize_text_field($params['device']) : 'android';
    $otp_bypass = !empty($params['otpBypass']);
    $last_otp_timestamp = isset($params['lastOtpTimestamp']) ? (string) $params['lastOtpTimestamp'] : '';

    if ($order_id <= 0) {
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Invalid order_id',
        ), 400);
    }

    $order = wc_get_order($order_id);
    if (!$order) {
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Order not found',
        ), 404);
    }

    if ($order->get_payment_method() !== 'snapmint') {
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Order payment method is not Snapmint',
        ), 400);
    }

    if (!yana_wc_order_owner_matches($order, $user_id)) {
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Order ownership validation failed',
        ), 403);
    }

    $settings = get_option('woocommerce_snapmint_settings', array());
    $merchant_id = trim((string) ($settings['merchant_id'] ?? ''));
    $merchant_password = trim((string) ($settings['merchant_password'] ?? $settings['merchant_key'] ?? ''));
    $payment_env = 'sandbox';

    if ($merchant_id === '' || $merchant_password === '') {
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Snapmint merchant settings are incomplete',
        ), 500);
    }

    $endpoint = 'https://pay.sandbox.snapmint.com/api/pub/carts';

    $billing_phone = preg_replace('/\D+/', '', (string) $order->get_billing_phone());
    $billing_email = trim((string) $order->get_billing_email());
    $billing_first_name = trim((string) $order->get_billing_first_name());
    $billing_last_name = trim((string) $order->get_billing_last_name());
    $customer_ip = method_exists($order, 'get_customer_ip_address')
        ? trim((string) $order->get_customer_ip_address())
        : '';

    $success_url = add_query_arg(array(
        'order_id' => $order_id,
        'key'      => $order->get_order_key(),
        'source'   => 'snapmint_app',
    ), home_url('/snapmint/success'));

    $failure_url = add_query_arg(array(
        'order_id' => $order_id,
        'key'      => $order->get_order_key(),
        'source'   => 'snapmint_app',
    ), home_url('/snapmint/failure'));

    $payload = array(
        'otpBypass'                => (bool) $otp_bypass,
        'ip'                       => $customer_ip !== '' ? $customer_ip : '127.0.0.1',
        'merchantPassword'         => $merchant_password,
        'merchantId'               => $merchant_id,
        'merchantConfirmationUrl'  => $success_url,
        'merchantFailureUrl'       => $failure_url,
        'mobile'                   => $billing_phone,
        'merchantOrderId'          => (string) $order_id,
        'orderValue'               => wc_format_decimal((float) $order->get_total(), 2),
        'email'                    => $billing_email,
        'first_name'               => $billing_first_name,
        'last_name'                => $billing_last_name,
        'deviceType'               => $device,
        'billingAddress'           => yana_snapmint_address_from_order($order, 'billing'),
        'shippingAddress'          => yana_snapmint_address_from_order($order, 'shipping'),
        'products'                 => yana_snapmint_product_lines($order),
        'udf1'                     => (string) $order_id,
        'udf2'                     => (string) $order->get_order_key(),
    );

    if ($payload['otpBypass'] && $last_otp_timestamp !== '') {
        $payload['lastOtpTimestamp'] = $last_otp_timestamp;
    }

    $response = wp_remote_post($endpoint, array(
        'timeout' => 30,
        'headers' => array(
            'Content-Type' => 'application/json',
        ),
        'body' => wp_json_encode($payload),
    ));

    if (is_wp_error($response)) {
        error_log('Snapmint /api/pub/carts error for order ' . $order_id . ': ' . $response->get_error_message());
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Snapmint service unavailable',
        ), 502);
    }

    $code = (int) wp_remote_retrieve_response_code($response);
    $body = wp_remote_retrieve_body($response);
    $json = json_decode($body, true);

    if ($code < 200 || $code >= 300 || !is_array($json)) {
        error_log('Snapmint /api/pub/carts bad response for order ' . $order_id . ': ' . $body);
        return new WP_REST_Response(array(
            'status'      => 'failed',
            'message'     => 'Invalid response from Snapmint',
            'http_status' => $code,
        ), 502);
    }

    $redirect_url = trim((string) ($json['redirectUrl'] ?? ''));
    if ($redirect_url === '') {
        error_log('Snapmint redirectUrl missing for order ' . $order_id . ': ' . $body);
        return new WP_REST_Response(array(
            'status'  => 'failed',
            'message' => 'Snapmint redirect URL missing',
        ), 502);
    }

    return new WP_REST_Response(array(
        'status'       => 'success',
        'checkout_url' => $redirect_url,
        'redirect_url' => $redirect_url,
        'redirectUrl'  => $redirect_url,
    ), 200);
}
