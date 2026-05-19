<?php
header("Content-Type: application/json");

// Move these secrets to a private config file in production.
$geminiApiKey = "YOUR_GEMINI_API_KEY";
$serviceToken = "";

// Cache settings. Same bike model will reuse a recent answer for stability.
$cacheTtlSeconds = 60 * 60 * 24 * 30; // 30 days
$cacheDir = __DIR__ . "/cache/bike-service-ai";

if ($serviceToken !== "") {
  $incomingToken = isset($_SERVER["HTTP_X_SERVICE_TOKEN"])
      ? trim($_SERVER["HTTP_X_SERVICE_TOKEN"])
      : "";
  if ($incomingToken !== $serviceToken) {
    http_response_code(401);
    echo json_encode([
      "ok" => false,
      "error" => "Unauthorized"
    ]);
    exit;
  }
}

$rawInput = file_get_contents("php://input");
$input = json_decode($rawInput, true);
$bikeModel = isset($input["bikeModel"]) ? trim($input["bikeModel"]) : "";

if ($bikeModel === "") {
  http_response_code(400);
  echo json_encode([
    "ok" => false,
    "error" => "bikeModel is required"
  ]);
  exit;
}

$normalizedBikeModel = preg_replace('/\s+/', ' ', strtolower($bikeModel));
$cacheKey = preg_replace('/[^a-z0-9]+/', '-', $normalizedBikeModel);
$cacheFile = $cacheDir . "/" . trim($cacheKey, '-') . ".json";

if (!is_dir($cacheDir)) {
  @mkdir($cacheDir, 0775, true);
}

if (is_file($cacheFile)) {
  $cachedRaw = @file_get_contents($cacheFile);
  $cached = json_decode($cachedRaw, true);
  if (is_array($cached)) {
    $createdAt = isset($cached["created_at"]) ? strtotime($cached["created_at"]) : 0;
    if ($createdAt > 0 && (time() - $createdAt) < $cacheTtlSeconds) {
      echo json_encode([
        "ok" => true,
        "cached" => true,
        "data" => $cached["data"],
        "output_text" => json_encode($cached["data"])
      ]);
      exit;
    }
  }
}

function buildPrompt($bikeModel) {
  return "
Return valid JSON only. Do not use markdown. Do not wrap in code fences.

You are preparing a motorcycle service quotation for India.
Bike model: {$bikeModel}

Need the following values for a standard service quotation:
1. Engine oil quantity in litres WITH oil filter change
2. Oil filter market price in INR
3. Air filter market price in INR

Priority rules:
- Prefer official manufacturer manual/specification or trusted service manual for engine oil quantity
- Prefer India-focused ecommerce or OEM parts sources for prices
- If multiple values exist, choose the most standard service-shop value
- Keep the result stable and conservative, not speculative
- Use only numeric values for litre and prices
- If exact model is unavailable, use the nearest exact variant and mention that in notes

Return this exact JSON schema:
{
  \"bike_model\": \"{$bikeModel}\",
  \"oil_capacity_litres\": 0,
  \"oil_filter_price\": 0,
  \"air_filter_price\": 0,
  \"confidence\": \"high|medium|low\",
  \"notes\": \"short reason with exact variant if used\",
  \"sources\": [\"https://...\"]
}";
}

function callGemini($geminiApiKey, $bikeModel) {
  $url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" . urlencode($geminiApiKey);
  $payload = [
    "contents" => [[
      "parts" => [[
        "text" => buildPrompt($bikeModel)
      ]]
    ]],
    "tools" => [[
      "google_search" => new stdClass()
    ]]
  ];

  $ch = curl_init($url);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_POST, true);
  curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Content-Type: application/json"
  ]);
  curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));

  $response = curl_exec($ch);
  $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  $curlError = curl_error($ch);
  curl_close($ch);

  return [
    "http_code" => $httpCode,
    "curl_error" => $curlError,
    "raw" => $response
  ];
}

function decodeGeminiJson($responseBody) {
  $decoded = json_decode($responseBody, true);
  if (!is_array($decoded)) {
    return [null, null];
  }

  $text = "";
  if (isset($decoded["candidates"][0]["content"]["parts"][0]["text"])) {
    $text = trim($decoded["candidates"][0]["content"]["parts"][0]["text"]);
  }

  if ($text === "") {
    return [$decoded, null];
  }

  $clean = preg_replace('/^```[a-zA-Z0-9_-]*\s*/', '', $text);
  $clean = preg_replace('/\s*```$/', '', $clean);
  $clean = trim($clean);

  $parsed = json_decode($clean, true);
  if (!is_array($parsed)) {
    return [$decoded, null];
  }

  return [$decoded, $parsed];
}

function normalizeEstimate($bikeModel, $parsed) {
  if (!is_array($parsed)) {
    return null;
  }

  $oilLitres = isset($parsed["oil_capacity_litres"])
      ? floatval($parsed["oil_capacity_litres"])
      : 0;
  $oilFilter = isset($parsed["oil_filter_price"])
      ? floatval($parsed["oil_filter_price"])
      : 0;
  $airFilter = isset($parsed["air_filter_price"])
      ? floatval($parsed["air_filter_price"])
      : 0;

  if ($oilLitres <= 0.2 || $oilLitres > 8.0) {
    return null;
  }
  if ($oilFilter < 0 || $oilFilter > 25000) {
    return null;
  }
  if ($airFilter < 0 || $airFilter > 25000) {
    return null;
  }

  $confidence = isset($parsed["confidence"]) ? trim(strtolower($parsed["confidence"])) : "medium";
  if (!in_array($confidence, ["high", "medium", "low"], true)) {
    $confidence = "medium";
  }

  $sources = [];
  if (isset($parsed["sources"]) && is_array($parsed["sources"])) {
    foreach ($parsed["sources"] as $source) {
      $value = is_string($source) ? trim($source) : "";
      if ($value !== "") {
        $sources[] = $value;
      }
    }
  }

  return [
    "bike_model" => isset($parsed["bike_model"]) && trim($parsed["bike_model"]) !== ""
        ? trim($parsed["bike_model"])
        : $bikeModel,
    "oil_capacity_litres" => round($oilLitres, 2),
    "oil_filter_price" => round($oilFilter, 0),
    "air_filter_price" => round($airFilter, 0),
    "confidence" => $confidence,
    "notes" => isset($parsed["notes"]) ? trim($parsed["notes"]) : "",
    "sources" => array_values(array_slice(array_unique($sources), 0, 5))
  ];
}

$attempts = 0;
$finalData = null;
$lastError = null;

while ($attempts < 2 && $finalData === null) {
  $attempts++;
  $apiResult = callGemini($geminiApiKey, $bikeModel);

  if ($apiResult["curl_error"] !== "") {
    $lastError = $apiResult["curl_error"];
    continue;
  }

  if (intval($apiResult["http_code"]) >= 400) {
    $lastError = $apiResult["raw"];
    continue;
  }

  list($decodedEnvelope, $parsedOutput) = decodeGeminiJson($apiResult["raw"]);
  $normalized = normalizeEstimate($bikeModel, $parsedOutput);
  if ($normalized !== null) {
    $finalData = $normalized;
    break;
  }

  $lastError = "Unable to parse a valid estimate from Gemini response";
}

if ($finalData === null) {
  http_response_code(502);
  echo json_encode([
    "ok" => false,
    "error" => $lastError === null ? "AI estimate unavailable" : $lastError
  ]);
  exit;
}

@file_put_contents($cacheFile, json_encode([
  "created_at" => gmdate("c"),
  "data" => $finalData
]));

echo json_encode([
  "ok" => true,
  "cached" => false,
  "data" => $finalData,
  "output_text" => json_encode($finalData)
]);
