<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

/**
 * Deploy:
 *   https://yanaworldwide.store/api/cashfree/order-status.php
 *
 * Purpose:
 *   Verify Cashfree order payment status on server using:
 *   GET /pg/orders/{order_id}
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

if ($APP_SHARED_TOKEN !== '') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $auth, $m) || trim($m[1]) !== $APP_SHARED_TOKEN) {
        respond(401, ['status' => 'error', 'message' => 'Unauthorized']);
    }
}

$in = body();
$orderId = s($in, 'order_id');
if ($orderId === '') {
    respond(400, ['status' => 'error', 'message' => 'order_id is required']);
}

$requestedEnv = strtoupper(s($in, 'environment'));
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

$url = $resolvedBaseUrl . '/orders/' . rawurlencode($orderId);
$ch = curl_init($url);
if ($ch === false) {
    respond(500, ['status' => 'error', 'message' => 'curl_init_failed']);
}

curl_setopt_array($ch, [
    CURLOPT_HTTPGET => true,
    CURLOPT_HTTPHEADER => [
        'x-client-id: ' . $resolvedAppId,
        'x-client-secret: ' . $resolvedSecret,
        'x-api-version: ' . $CASHFREE_API_VERSION,
    ],
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
        'message' => 'Cashfree order fetch failed',
        'http_status' => $code,
        'body' => substr($resp, 0, 500),
    ]);
}

$orderStatus = strtoupper((string)($json['order_status'] ?? ''));
$paymentStatus = strtoupper((string)($json['payment_status'] ?? ''));
$verified = ($orderStatus === 'PAID' || $paymentStatus === 'SUCCESS' || $paymentStatus === 'PAID');

respond(200, [
    'status' => 'success',
    'verified' => $verified,
    'order_id' => (string)($json['order_id'] ?? $orderId),
    'order_status' => $orderStatus,
    'payment_status' => $paymentStatus,
    'environment' => $requestedEnv,
]);
