<?php
header("Content-Type: application/json");

$requiredAppHeader = "X-Yana-App";
$requiredAppValue = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
$serviceToken = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
$dataDir = __DIR__ . "/data";
$bookingFile = $dataDir . "/service_bookings.json";
$allowedStatuses = ["Hold", "Processing", "Part Order", "Complete", "Canceled"];

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

if ($tokenHeader !== $serviceToken) {
  http_response_code(403);
  echo json_encode(["ok" => false, "error" => "Booking status update requires X-Service-Token"]);
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
$status = trim((string) ($input["status"] ?? ""));
$completedServiceDate = trim((string) ($input["completed_service_date"] ?? ""));
$serviceDoneKm = trim((string) ($input["service_done_km"] ?? ""));
$nextServiceDueKm = trim((string) ($input["next_service_due_km"] ?? ""));

if ($bookingId === "") {
  http_response_code(400);
  echo json_encode([
    "ok" => false,
    "error" => "booking_id is required"
  ]);
  exit;
}

if ($status !== "" && !in_array($status, $allowedStatuses, true)) {
  http_response_code(400);
  echo json_encode([
    "ok" => false,
    "error" => "Invalid status",
    "allowed_statuses" => $allowedStatuses
  ]);
  exit;
}

if (!is_dir($dataDir)) {
  @mkdir($dataDir, 0775, true);
}

$bookings = [];
if (is_file($bookingFile)) {
  $decoded = json_decode((string) @file_get_contents($bookingFile), true);
  if (is_array($decoded)) {
    $bookings = $decoded;
  }
}

$updatedBooking = null;
foreach ($bookings as &$booking) {
  $currentId = trim((string) ($booking["booking_id"] ?? ""));
  if ($currentId !== $bookingId) {
    continue;
  }
  if ($status !== "") {
    $booking["status"] = $status;
  }
  if (array_key_exists("completed_service_date", $input)) {
    $booking["completed_service_date"] = $completedServiceDate;
  }
  if (array_key_exists("service_done_km", $input)) {
    $booking["service_done_km"] = $serviceDoneKm;
  }
  if (array_key_exists("next_service_due_km", $input)) {
    $booking["next_service_due_km"] = $nextServiceDueKm;
  }
  $booking["updated_at"] = gmdate("c");
  $updatedBooking = $booking;
  break;
}
unset($booking);

if ($updatedBooking === null) {
  http_response_code(404);
  echo json_encode([
    "ok" => false,
    "error" => "Booking not found",
    "booking_id" => $bookingId
  ]);
  exit;
}

@file_put_contents($bookingFile, json_encode(array_values($bookings), JSON_PRETTY_PRINT));

echo json_encode([
  "ok" => true,
  "booking_id" => $bookingId,
  "status" => $status,
  "updated_booking" => $updatedBooking
]);
