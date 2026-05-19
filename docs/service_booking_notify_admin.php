<?php
header("Content-Type: application/json");

$serviceToken = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
$queueFile = __DIR__ . "/data/service_booking_admin_notifications.json";

function request_header_value($key) {
  $serverKey = "HTTP_" . strtoupper(str_replace("-", "_", $key));
  return isset($_SERVER[$serverKey]) ? trim((string) $_SERVER[$serverKey]) : "";
}

$tokenHeader = request_header_value("X-Service-Token");
if ($tokenHeader !== $serviceToken) {
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

$dataDir = dirname($queueFile);
if (!is_dir($dataDir)) {
  @mkdir($dataDir, 0775, true);
}

$queue = [];
if (is_file($queueFile)) {
  $decoded = json_decode((string) @file_get_contents($queueFile), true);
  if (is_array($decoded)) {
    $queue = $decoded;
  }
}

array_unshift($queue, [
  "title" => "New motorcycle service booking",
  "body" => "Booking " . trim((string) ($input["booking_id"] ?? "-")) . " received for " . trim((string) ($input["bike_model"] ?? "bike")),
  "topic" => "admin_orders",
  "booking" => $input,
  "created_at" => gmdate("c")
]);
$queue = array_slice($queue, 0, 1000);
@file_put_contents($queueFile, json_encode($queue, JSON_PRETTY_PRINT));

echo json_encode([
  "ok" => true,
  "message" => "Admin booking notification queued. Connect this file to your FCM sender or WordPress push plugin."
]);
