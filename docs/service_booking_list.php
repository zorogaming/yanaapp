<?php
header("Content-Type: application/json");

$requiredAppHeader = "X-Yana-App";
$requiredAppValue = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
$serviceToken = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
$bookingFile = __DIR__ . "/data/service_bookings.json";

function request_header_value($key) {
  $serverKey = "HTTP_" . strtoupper(str_replace("-", "_", $key));
  return isset($_SERVER[$serverKey]) ? trim((string) $_SERVER[$serverKey]) : "";
}

$appHeaderValue = request_header_value($requiredAppHeader);
$tokenHeader = request_header_value("X-Service-Token");
$isAdminRequest = isset($_GET["admin"]) && $_GET["admin"] === "1";

if ($appHeaderValue !== $requiredAppValue && $tokenHeader !== $serviceToken) {
  http_response_code(401);
  echo json_encode(["ok" => false, "error" => "Unauthorized"]);
  exit;
}

if ($isAdminRequest && $tokenHeader !== $serviceToken) {
  http_response_code(403);
  echo json_encode(["ok" => false, "error" => "Admin listing requires X-Service-Token"]);
  exit;
}

$bookings = [];
if (is_file($bookingFile)) {
  $decoded = json_decode((string) @file_get_contents($bookingFile), true);
  if (is_array($decoded)) {
    $bookings = $decoded;
  }
}

if (!$isAdminRequest) {
  $installId = trim((string) ($_GET["install_id"] ?? ""));
  $userId = trim((string) ($_GET["user_id"] ?? ""));
  $bookings = array_values(array_filter($bookings, function ($booking) use ($installId, $userId) {
    $bookingInstallId = trim((string) ($booking["install_id"] ?? ""));
    $bookingUserId = trim((string) ($booking["user_id"] ?? ""));
    if ($userId !== "" && $bookingUserId === $userId) {
      return true;
    }
    if ($installId !== "" && $bookingInstallId === $installId) {
      return true;
    }
    return false;
  }));
}

echo json_encode([
  "ok" => true,
  "bookings" => array_values($bookings)
]);
