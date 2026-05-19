<?php
header("Content-Type: application/json");

$requiredAppHeader = "X-Yana-App";
$requiredAppValue = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
$serviceToken = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
$dataDir = __DIR__ . "/data";
$bookingFile = $dataDir . "/service_bookings.json";
$notifyEndpoint = "https://yanaworldwide.store/api/service_booking_notify_admin.php";

function request_header_value($key) {
  $serverKey = "HTTP_" . strtoupper(str_replace("-", "_", $key));
  return isset($_SERVER[$serverKey]) ? trim((string) $_SERVER[$serverKey]) : "";
}

$appHeaderValue = request_header_value($requiredAppHeader);
$tokenHeader = request_header_value("X-Service-Token");
if ($appHeaderValue !== $requiredAppValue && $tokenHeader !== $serviceToken) {
  http_response_code(401);
  echo json_encode(["ok" => false, "error" => "Unauthorized"]);
  exit;
}

$rawInput = file_get_contents("php://input");
$input = json_decode($rawInput, true);
if (!is_array($input)) {
  http_response_code(400);
  echo json_encode(["ok" => false, "error" => "Invalid JSON body"]);
  exit;
}

$bookingId = trim((string) ($input["booking_id"] ?? ""));
$bikeModel = trim((string) ($input["bike_model"] ?? ""));
$packageTitle = trim((string) ($input["package_title"] ?? ""));

if ($bikeModel === "" || $packageTitle === "") {
  http_response_code(400);
  echo json_encode(["ok" => false, "error" => "bike_model and package_title are required"]);
  exit;
}

if ($bookingId === "") {
  $bookingId = "MSS-" . round(microtime(true) * 1000);
}

if (!is_dir($dataDir)) {
  @mkdir($dataDir, 0775, true);
}

$existing = [];
if (is_file($bookingFile)) {
  $decoded = json_decode((string) @file_get_contents($bookingFile), true);
  if (is_array($decoded)) {
    $existing = $decoded;
  }
}

$booking = [
  "booking_id" => $bookingId,
  "bike_model" => $bikeModel,
  "package_id" => trim((string) ($input["package_id"] ?? "")),
  "package_title" => $packageTitle,
  "service_date" => trim((string) ($input["service_date"] ?? "")),
  "time_slot" => trim((string) ($input["time_slot"] ?? "")),
  "service_priority" => trim((string) ($input["service_priority"] ?? "normal")),
  "pickup_and_drop" => !empty($input["pickup_and_drop"]),
  "address" => trim((string) ($input["address"] ?? "")),
  "payment_method" => trim((string) ($input["payment_method"] ?? "workshop")),
  "payment_note" => trim((string) ($input["payment_note"] ?? "")),
  "subtotal" => floatval($input["subtotal"] ?? 0),
  "discount" => floatval($input["discount"] ?? 0),
  "total" => floatval($input["total"] ?? 0),
  "customer_name" => trim((string) ($input["customer_name"] ?? "")),
  "customer_phone" => trim((string) ($input["customer_phone"] ?? "")),
  "customer_email" => trim((string) ($input["customer_email"] ?? "")),
  "workshop_address" => trim((string) ($input["workshop_address"] ?? "")),
  "workshop_phone" => trim((string) ($input["workshop_phone"] ?? "")),
  "completed_service_date" => trim((string) ($input["completed_service_date"] ?? "")),
  "service_done_km" => trim((string) ($input["service_done_km"] ?? "")),
  "next_service_due_km" => trim((string) ($input["next_service_due_km"] ?? "")),
  "air_filter_option" => trim((string) ($input["air_filter_option"] ?? "")),
  "quotation_items" => isset($input["quotation_items"]) && is_array($input["quotation_items"])
      ? array_values($input["quotation_items"])
      : [],
  "status" => trim((string) ($input["status"] ?? "Hold")),
  "install_id" => trim((string) ($input["install_id"] ?? "")),
  "user_id" => trim((string) ($input["user_id"] ?? "")),
  "created_at" => gmdate("c"),
];

array_unshift($existing, $booking);
$existing = array_slice($existing, 0, 5000);
@file_put_contents($bookingFile, json_encode($existing, JSON_PRETTY_PRINT));

$notifyResponse = null;
if ($notifyEndpoint !== "") {
  $ch = curl_init($notifyEndpoint);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_POST, true);
  curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Content-Type: application/json",
    "X-Service-Token: " . $serviceToken
  ]);
  curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($booking));
  $notifyResponse = curl_exec($ch);
  curl_close($ch);
}

echo json_encode([
  "ok" => true,
  "booking_id" => $bookingId,
  "notify_response" => $notifyResponse
]);
