<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

/**
 * Deploy:
 *   https://yanaworldwide.store/api/cashfree/order-token.php
 *
 * Purpose:
 *   Create Cashfree order + payment_session_id on server.
 */

$APP_SHARED_TOKEN = getenv('APP_SHARED_TOKEN') ?: '';
$CASHFREE_ENV = strtoupper(getenv('CASHFREE_ENV') ?: 'PRODUCTION'); // PRODUCTION | SANDBOX
$CASHFREE_ALLOW_SANDBOX = (getenv('CASHFREE_ALLOW_SANDBOX') ?: '0') === '1';
$CASHFREE_APP_ID = getenv('CASHFREE_APP_ID') ?: '';
$CASHFREE_SECRET_KEY = getenv('CASHFREE_SECRET_KEY') ?: '';
$CASHFREE_SANDBOX_APP_ID = getenv('CASHFREE_SANDBOX_APP_ID') ?: '';
$CASHFREE_SANDBOX_SECRET_KEY = getenv('CASHFREE_SANDBOX_SECRET_KEY') ?: '';
$CASHFREE_PROD_APP_ID = getenv('CASHFREE_PROD_APP_ID') ?: '';
$CASHFREE_PROD_SECRET_KEY = getenv('CASHFREE_PROD_SECRET_KEY') ?: '';
$CASHFREE_BASE_URL = getenv('CASHFREE_BASE_URL') ?: '';
$CASHFREE_API_VERSION = '2023-08-01';

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_SLASHES);
    exit;
}

function body(): array
{
    $raw = file_get_contents('php://input');
    if (!is_string($raw) || trim($raw) === '') return $_POST ?: [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? ($decoded + ($_POST ?: [])) : ($_POST ?: []);
}

function s(array $arr, string $key): string
{
    $v = $arr[$key] ?? '';
    return is_scalar($v) ? trim((string)$v) : '';
}

function first_non_empty(array $arr, array $keys): string
{
    foreach ($keys as $key) {
        if (is_string($key)) {
            $value = s($arr, $key);
            if ($value !== '') return $value;
            continue;
        }
        if (!is_array($key)) continue;
        $cursor = $arr;
        $ok = true;
        foreach ($key as $part) {
            if (!is_array($cursor) || !array_key_exists($part, $cursor)) {
                $ok = false;
                break;
            }
            $cursor = $cursor[$part];
        }
        if ($ok && is_scalar($cursor)) {
            $value = trim((string)$cursor);
            if ($value !== '') return $value;
        }
    }
    return '';
}

if ($APP_SHARED_TOKEN !== '') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $auth, $m) || trim($m[1]) !== $APP_SHARED_TOKEN) {
        respond(401, ['status' => 'error', 'message' => 'Unauthorized']);
    }
}

$in = body();
$amount = (float) s($in, 'amount');
$customerName = s($in, 'name');
$customerEmail = s($in, 'email');
$merchantOrderId = preg_replace('/[^0-9A-Za-z_-]/', '', s($in, 'merchant_order_id'));
$customerPhone = preg_replace('/\D+/', '', s($in, 'phone'));
if (!is_string($customerPhone)) $customerPhone = '';

$requestedEnv = strtoupper(first_non_empty($in, ['environment', 'env']));
if ($requestedEnv !== 'SANDBOX' && $requestedEnv !== 'PRODUCTION') {
    $requestedEnv = $CASHFREE_ENV;
}
if (!$CASHFREE_ALLOW_SANDBOX) {
    $requestedEnv = 'PRODUCTION';
}
$isSandbox = $requestedEnv === 'SANDBOX';

$resolvedAppId = $isSandbox
    ? ($CASHFREE_SANDBOX_APP_ID !== '' ? $CASHFREE_SANDBOX_APP_ID : $CASHFREE_APP_ID)
    : ($CASHFREE_PROD_APP_ID !== '' ? $CASHFREE_PROD_APP_ID : $CASHFREE_APP_ID);
$resolvedSecret = $isSandbox
    ? ($CASHFREE_SANDBOX_SECRET_KEY !== '' ? $CASHFREE_SANDBOX_SECRET_KEY : $CASHFREE_SECRET_KEY)
    : ($CASHFREE_PROD_SECRET_KEY !== '' ? $CASHFREE_PROD_SECRET_KEY : $CASHFREE_SECRET_KEY);
$resolvedBaseUrl = $CASHFREE_BASE_URL !== ''
    ? rtrim($CASHFREE_BASE_URL, '/')
    : ($isSandbox ? 'https://sandbox.cashfree.com/pg' : 'https://api.cashfree.com/pg');

if ($resolvedAppId === '' || $resolvedSecret === '') {
    respond(500, [
        'status' => 'error',
        'message' => 'Cashfree keys not configured',
        'environment' => $requestedEnv,
    ]);
}

if ($amount <= 0 || $customerName === '' || $customerEmail === '' || $customerPhone === '') {
    respond(400, ['status' => 'error', 'message' => 'Missing required fields']);
}

$orderPrefix = $merchantOrderId !== '' ? ('WC_' . $merchantOrderId . '_') : 'CF_';
$orderId = $orderPrefix . time() . '_' . random_int(1000, 9999);
$payload = [
    'order_id' => $orderId,
    'order_amount' => round($amount, 2),
    'order_currency' => 'INR',
    'customer_details' => [
        'customer_id' => 'cust_' . substr(hash('sha256', $customerEmail), 0, 12),
        'customer_name' => $customerName,
        'customer_email' => $customerEmail,
        'customer_phone' => $customerPhone,
    ],
    'order_meta' => [
        'return_url' => 'https://yanaworldwide.store',
    ],
];

$ch = curl_init($resolvedBaseUrl . '/orders');
if ($ch === false) {
    respond(500, ['status' => 'error', 'message' => 'curl_init_failed']);
}

curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'x-client-id: ' . $resolvedAppId,
        'x-client-secret: ' . $resolvedSecret,
        'x-api-version: ' . $CASHFREE_API_VERSION,
    ],
    CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_SLASHES),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 30,
]);

$resp = curl_exec($ch);
$code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
$err = curl_error($ch);
curl_close($ch);

if (!is_string($resp) || $resp === '') {
    respond(502, ['status' => 'error', 'message' => 'Empty Cashfree response', 'curl_error' => $err]);
}

$json = json_decode($resp, true);
if ($code < 200 || $code >= 300 || !is_array($json)) {
    respond(502, [
        'status' => 'error',
        'message' => 'Cashfree order create failed',
        'http_status' => $code,
        'body' => substr($resp, 0, 500),
    ]);
}

$paymentSessionId = first_non_empty($json, [
    'payment_session_id',
    'paymentSessionId',
    ['data', 'payment_session_id'],
    ['data', 'paymentSessionId'],
    ['result', 'payment_session_id'],
    ['result', 'paymentSessionId'],
]);
$createdOrderId = first_non_empty($json, [
    'order_id',
    'orderId',
    ['data', 'order_id'],
    ['data', 'orderId'],
    ['result', 'order_id'],
    ['result', 'orderId'],
]);

if ($paymentSessionId === '' || $createdOrderId === '') {
    respond(502, [
        'status' => 'error',
        'message' => 'Cashfree response missing payment_session_id/order_id',
        'keys' => array_keys($json),
    ]);
}

respond(200, [
    'status' => 'success',
    'order_id' => $createdOrderId,
    'merchant_order_id' => $merchantOrderId,
    'payment_session_id' => $paymentSessionId,
    'environment' => $requestedEnv,
    'app_id' => $resolvedAppId,
]);
