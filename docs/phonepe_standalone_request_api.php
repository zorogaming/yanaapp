<?php
/**
 * request.php (for phonepe_payment_sdk package)
 *
 * Deploy as:
 *   https://yanaworldwide.store/api/phonepe/request.php
 *
 * This endpoint must return:
 *   request: JSON string with {orderId, merchantId, token, paymentMode:{type}, targetAppPackageName?}
 *
 * IMPORTANT:
 * - Do NOT return old base64 payload here.
 * - This SDK needs order token flow.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

// -------------------- Config --------------------
$PHONEPE_ENV = getenv('PHONEPE_ENV') ?: 'PRODUCTION';
$PHONEPE_MERCHANT_ID = getenv('PHONEPE_MERCHANT_ID') ?: 'M22V6F338RBBI';
$PHONEPE_APP_SCHEMA = getenv('PHONEPE_APP_SCHEMA') ?: 'yanaworldwide';
$APP_SHARED_TOKEN = getenv('APP_SHARED_TOKEN') ?: 'yana_phonepe_token_2026_secure';

/**
 * Your private backend API that generates PhonePe order token.
 * It must return JSON:
 *   { "orderId": "...", "token": "..." }
 *
 * If you do not have this yet, keep blank and pass `orderId` + `token` directly in POST body for testing.
 */
$ORDER_TOKEN_API_URL = getenv('PHONEPE_ORDER_TOKEN_API_URL') ?: '';
$ORDER_TOKEN_API_BEARER = getenv('PHONEPE_ORDER_TOKEN_API_BEARER') ?: '';

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
    $decoded = json_decode($raw, true);
    if (is_array($decoded)) return $decoded + ($_POST ?: []);
    return $_POST ?: [];
}

function s(array $arr, string $key): string
{
    $v = $arr[$key] ?? '';
    return is_scalar($v) ? trim((string)$v) : '';
}

function post_json(string $url, array $payload, string $bearer = ''): ?array
{
    $ch = curl_init($url);
    if ($ch === false) return null;
    $headers = ['Content-Type: application/json'];
    if ($bearer !== '') {
        $headers[] = 'Authorization: Bearer ' . $bearer;
    }
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_SLASHES),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 25,
    ]);
    $resp = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if (!is_string($resp) || $resp === '' || $code < 200 || $code >= 300) return null;
    $json = json_decode($resp, true);
    return is_array($json) ? $json : null;
}

// -------------------- Auth Guard --------------------
if ($APP_SHARED_TOKEN !== '') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $auth, $m) || trim($m[1]) !== $APP_SHARED_TOKEN) {
        respond(401, ['status' => 'error', 'message' => 'Unauthorized']);
    }
}

$in = body();

// Preferred flow: fetch order token from your private API.
$orderId = s($in, 'orderId');
$token = s($in, 'token');

if (($orderId === '' || $token === '') && $ORDER_TOKEN_API_URL !== '') {
    $amount = s($in, 'amount');
    $name = s($in, 'name');
    $email = s($in, 'email');
    $phone = preg_replace('/\D+/', '', s($in, 'phone'));
    $paymentType = s($in, 'payment_type');
    $device = s($in, 'device');

    $upstream = post_json($ORDER_TOKEN_API_URL, [
        'amount' => $amount,
        'name' => $name,
        'email' => $email,
        'phone' => $phone,
        'payment_type' => $paymentType,
        'device' => $device,
    ], $ORDER_TOKEN_API_BEARER);

    if (is_array($upstream)) {
        $orderId = s($upstream, 'orderId');
        $token = s($upstream, 'token');
        if ($orderId === '') $orderId = s($upstream, 'order_id');
        if ($token === '') $token = s($upstream, 'order_token');
    }
}

if ($orderId === '' || $token === '') {
    respond(400, [
        'status' => 'error',
        'message' => 'Missing orderId/token. Configure PHONEPE_ORDER_TOKEN_API_URL or pass orderId+token.',
    ]);
}

// PhonePe Flutter SDK expects paymentMode object:
// { "type": "PAY_PAGE" } for standard checkout.
$paymentModeType = strtoupper(s($in, 'paymentModeType'));
if ($paymentModeType === '') {
    $paymentModeRaw = s($in, 'paymentMode');
    if ($paymentModeRaw !== '') {
        $maybeJson = json_decode($paymentModeRaw, true);
        if (is_array($maybeJson)) {
            $paymentModeType = strtoupper(s($maybeJson, 'type'));
        } else {
            $paymentModeType = strtoupper($paymentModeRaw);
        }
    }
}
if ($paymentModeType === '') $paymentModeType = 'PAY_PAGE';

$targetApp = s($in, 'targetAppPackageName'); // optional: com.phonepe.app / com.google.android.apps.nbu.paisa.user

$request = [
    'orderId' => $orderId,
    'merchantId' => $PHONEPE_MERCHANT_ID,
    'token' => $token,
    'paymentMode' => ['type' => $paymentModeType],
];
if ($targetApp !== '') {
    $request['targetAppPackageName'] = $targetApp;
}

respond(200, [
    'status' => 'success',
    'environment' => $PHONEPE_ENV,
    'merchantId' => $PHONEPE_MERCHANT_ID,
    'appSchema' => $PHONEPE_APP_SCHEMA,
    'flowId' => 'F' . substr(hash('sha256', $orderId . microtime(true)), 0, 14),
    'request' => json_encode($request, JSON_UNESCAPED_SLASHES),
    'request_obj' => $request, // debug helper
]);
