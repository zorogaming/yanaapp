<?php
/**
 * PayU hash generation endpoint for Flutter CheckoutPro SDK.
 *
 * Deploy to:
 *   https://yanaworldwide.store/generate_hash.php
 *
 * SECURITY:
 * - Keep PAYU_SALT on server only.
 * - Do NOT put PAYU_SALT in app code.
 * - Optionally protect this endpoint with APP_SHARED_TOKEN.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

// -------------------- Server config --------------------
$PAYU_MERCHANT_KEY = getenv('PAYU_MERCHANT_KEY') ?: 'BxIXGh';
$PAYU_SALT = getenv('PAYU_SALT') ?: 'qKwG5TCwu4JxFxJHafcgcUxGd2LyXBBD';
$APP_SHARED_TOKEN = ''; // Optional: set non-empty to require Bearer token.

function respond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_SLASHES);
    exit;
}

function body_as_array(): array
{
    $raw = file_get_contents('php://input');
    if (!is_string($raw) || trim($raw) === '') {
        return $_POST ?: [];
    }

    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        return $decoded + ($_POST ?: []);
    }

    return $_POST ?: [];
}

function v(array $arr, string $key): string
{
    $value = $arr[$key] ?? '';
    if (is_scalar($value)) {
        return trim((string)$value);
    }
    return '';
}

function first_non_empty(array $arr, array $keys): string
{
    foreach ($keys as $key) {
        $value = v($arr, $key);
        if ($value !== '') return $value;
    }
    return '';
}

function payu_payment_hash(string $key, string $txnid, string $amount, string $productinfo, string $firstname, string $email, string $salt): string
{
    $sequence = implode('|', [
        $key,
        $txnid,
        $amount,
        $productinfo,
        $firstname,
        $email,
        '', '', '', '', '', // udf1-udf5
        '', '', '', '', '', // udf6-udf10
    ]);
    return strtolower(hash('sha512', $sequence . '|' . $salt));
}

// Optional token check.
if ($APP_SHARED_TOKEN !== '') {
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $authHeader, $m) || trim($m[1]) !== $APP_SHARED_TOKEN) {
        respond(401, ['status' => 'error', 'message' => 'Unauthorized']);
    }
}

if ($PAYU_MERCHANT_KEY === '' || $PAYU_SALT === '') {
    respond(500, ['status' => 'error', 'message' => 'Server PayU config missing']);
}

$input = body_as_array();

// SDK callback style: generateHash gives hashName + hashString.
$hashName = first_non_empty($input, ['hashName', 'hash_name']);
$hashString = first_non_empty($input, ['hashString', 'hash_string']);
if ($hashName !== '' && $hashString !== '') {
    $hashValue = strtolower(hash('sha512', $hashString . $PAYU_SALT));
    respond(200, [
        'status' => 'success',
        'hash' => $hashValue,
        $hashName => $hashValue,
    ]);
}

// Legacy style: direct payment hash request.
$key = v($input, 'merchant_key');
if ($key === '') {
    $key = v($input, 'key');
}
$txnid = v($input, 'txnid');
$amount = v($input, 'amount');
$productinfo = v($input, 'productinfo');
$firstname = v($input, 'firstname');
$email = v($input, 'email');

if ($key === '') {
    $key = $PAYU_MERCHANT_KEY;
}

if ($txnid === '' || $amount === '' || $productinfo === '' || $firstname === '' || $email === '') {
    respond(400, [
        'status' => 'error',
        'message' => 'Missing required fields for hash generation',
    ]);
}

if ($key !== $PAYU_MERCHANT_KEY) {
    respond(400, ['status' => 'error', 'message' => 'Invalid merchant key']);
}

$hash = payu_payment_hash($key, $txnid, $amount, $productinfo, $firstname, $email, $PAYU_SALT);
respond(200, ['status' => 'success', 'hash' => $hash]);
