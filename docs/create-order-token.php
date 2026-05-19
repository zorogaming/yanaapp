<?php
/**
 * create-order-token.php
 *
 * Deploy as:
 *   https://yanaworldwide.store/api/phonepe/create-order-token.php
 *
 * Purpose:
 *   - Create/fetch PhonePe order token from your upstream API
 *   - Return normalized JSON:
 *       { "status":"success", "orderId":"...", "token":"..." }
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

// -------------------- Config --------------------
$APP_SHARED_TOKEN = getenv('APP_SHARED_TOKEN') ?: 'yana_phonepe_token_2026_secure';

// Upstream endpoint that actually creates order and returns order token.
$PHONEPE_ORDER_API_URL = getenv('PHONEPE_ORDER_API_URL') ?: '';

// Optional upstream auth.
$UPSTREAM_AUTH_TYPE = strtoupper(getenv('UPSTREAM_AUTH_TYPE') ?: 'BEARER'); // NONE | BEARER | BASIC | HEADER
$UPSTREAM_BEARER_TOKEN = getenv('UPSTREAM_BEARER_TOKEN') ?: '';
$UPSTREAM_BASIC_USER = getenv('UPSTREAM_BASIC_USER') ?: '';
$UPSTREAM_BASIC_PASS = getenv('UPSTREAM_BASIC_PASS') ?: '';
$UPSTREAM_HEADER_NAME = getenv('UPSTREAM_HEADER_NAME') ?: 'X-API-Key';
$UPSTREAM_HEADER_VALUE = getenv('UPSTREAM_HEADER_VALUE') ?: '';

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_SLASHES);
    exit;
}

function body(): array
{
    $raw = file_get_contents('php://input');
    if (!is_string($raw) || trim($raw) === '') {
        return $_POST ?: [];
    }
    $json = json_decode($raw, true);
    if (is_array($json)) return $json + ($_POST ?: []);
    return $_POST ?: [];
}

function s(array $arr, string $key): string
{
    $v = $arr[$key] ?? '';
    return is_scalar($v) ? trim((string)$v) : '';
}

function get_path(array $arr, array $path)
{
    $node = $arr;
    foreach ($path as $p) {
        if (!is_array($node) || !array_key_exists($p, $node)) {
            return null;
        }
        $node = $node[$p];
    }
    return $node;
}

function first_non_empty(array $arr, array $paths): string
{
    foreach ($paths as $path) {
        $val = is_array($path) ? get_path($arr, $path) : ($arr[$path] ?? null);
        if (is_scalar($val)) {
            $txt = trim((string)$val);
            if ($txt !== '') return $txt;
        }
    }
    return '';
}

function call_upstream(string $url, array $payload): array
{
    global $UPSTREAM_AUTH_TYPE, $UPSTREAM_BEARER_TOKEN, $UPSTREAM_BASIC_USER, $UPSTREAM_BASIC_PASS, $UPSTREAM_HEADER_NAME, $UPSTREAM_HEADER_VALUE;

    $headers = ['Content-Type: application/json'];
    if ($UPSTREAM_AUTH_TYPE === 'BEARER' && $UPSTREAM_BEARER_TOKEN !== '') {
        $headers[] = 'Authorization: Bearer ' . $UPSTREAM_BEARER_TOKEN;
    } elseif ($UPSTREAM_AUTH_TYPE === 'BASIC' && $UPSTREAM_BASIC_USER !== '') {
        $headers[] = 'Authorization: Basic ' . base64_encode($UPSTREAM_BASIC_USER . ':' . $UPSTREAM_BASIC_PASS);
    } elseif ($UPSTREAM_AUTH_TYPE === 'HEADER' && $UPSTREAM_HEADER_NAME !== '' && $UPSTREAM_HEADER_VALUE !== '') {
        $headers[] = $UPSTREAM_HEADER_NAME . ': ' . $UPSTREAM_HEADER_VALUE;
    }

    $ch = curl_init($url);
    if ($ch === false) {
        return ['ok' => false, 'code' => 0, 'body' => '', 'json' => null, 'curl_error' => 'curl_init_failed'];
    }

    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_SLASHES),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 30,
    ]);

    $resp = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);

    $body = is_string($resp) ? $resp : '';
    $json = json_decode($body, true);

    return [
        'ok' => ($code >= 200 && $code < 300 && is_array($json)),
        'code' => $code,
        'body' => $body,
        'json' => is_array($json) ? $json : null,
        'curl_error' => $err,
    ];
}

// -------------------- App auth guard --------------------
if ($APP_SHARED_TOKEN !== '') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $auth, $m) || trim($m[1]) !== $APP_SHARED_TOKEN) {
        respond(401, ['status' => 'error', 'message' => 'Unauthorized']);
    }
}

$in = body();
$amount = s($in, 'amount');
$name = s($in, 'name');
$email = s($in, 'email');
$phone = preg_replace('/\D+/', '', s($in, 'phone'));
$paymentType = s($in, 'payment_type');
$device = s($in, 'device');

// Quick direct mode for local testing only.
$directOrderId = first_non_empty($in, ['orderId', 'order_id']);
$directToken = first_non_empty($in, ['token', 'orderToken', 'order_token']);
if ($directOrderId !== '' && $directToken !== '') {
    respond(200, [
        'status' => 'success',
        'orderId' => $directOrderId,
        'token' => $directToken,
        'source' => 'direct',
    ]);
}

if ($PHONEPE_ORDER_API_URL === '') {
    respond(500, [
        'status' => 'error',
        'message' => 'PHONEPE_ORDER_API_URL is not configured',
    ]);
}

$upstreamPayload = [
    'amount' => $amount,
    'name' => $name,
    'email' => $email,
    'phone' => $phone,
    'payment_type' => $paymentType,
    'device' => $device,
];

$up = call_upstream($PHONEPE_ORDER_API_URL, $upstreamPayload);
if (!$up['ok']) {
    respond(502, [
        'status' => 'error',
        'message' => 'Failed to fetch token from upstream',
        'upstream_url' => $PHONEPE_ORDER_API_URL,
        'upstream_http' => $up['code'],
        'upstream_curl_error' => $up['curl_error'],
        'upstream_body_snippet' => substr((string)$up['body'], 0, 500),
    ]);
}

$u = $up['json'];
$orderId = first_non_empty($u, [
    'orderId',
    'order_id',
    ['data', 'orderId'],
    ['data', 'order_id'],
    ['result', 'orderId'],
    ['result', 'order_id'],
]);
$token = first_non_empty($u, [
    'token',
    'orderToken',
    'order_token',
    ['data', 'token'],
    ['data', 'orderToken'],
    ['data', 'order_token'],
    ['result', 'token'],
    ['result', 'orderToken'],
    ['result', 'order_token'],
]);

if ($orderId === '' || $token === '') {
    respond(502, [
        'status' => 'error',
        'message' => 'Upstream response missing orderId/token',
        'upstream_keys' => array_keys($u),
        'upstream_body_snippet' => substr((string)$up['body'], 0, 500),
    ]);
}

respond(200, [
    'status' => 'success',
    'orderId' => $orderId,
    'token' => $token,
    'source' => 'upstream',
]);
