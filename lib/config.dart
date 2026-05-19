class Config {
  static const String baseUrl =
      "https://www.yanaworldwide.store/wp-json/wc/v3/";
  static const String consumerKey =
      "ck_5fc6596a487b93c1e0794aecd0fd3cd0fb2414c0";
  static const String consumerSecret =
      "cs_e6c14fe4412ccae3ce507857d87feeb74a649633";
  static const String appHeaderKey = "X-Yana-App";
  static const String appHeaderValue = "YANAWORLDWIDE_8f3K@29xP!mQ2026";
  static const String forgotPasswordApiUrl =
      "https://yanaworldwide.store/wp-json/wp/v1/app-forgot-password";
  static const String forgotPasswordToken = "YANAWORLDWIDE_RESET_2026";

  // PayU CheckoutPro SDK config
  static const String payuMerchantKey = "BxIXGh";
  static const String payuHashApiUrl = "https://yanaworldwide.store/generate_hash.php";
  static const String payuSuccessUrl = "https://yanaworldwide.store/payu/success";
  static const String payuFailureUrl = "https://yanaworldwide.store/payu/failure";
  static const String payuEnvironment = "0"; // 0: Production, 1: Test

  // Cashfree PG SDK config
  static const bool enableCashfree = true;
  static const String cashfreeEnvironment = "PRODUCTION";
  static const String cashfreeAppId = "5719733da50189700e9d1561fb379175";
  static const String cashfreeOrderTokenUrl =
      "https://yanaworldwide.store/api/cashfree/order-token.php";
  static const String cashfreeOrderStatusUrl =
      "https://yanaworldwide.store/api/cashfree/order-status.php";
  static const String cashfreeBackendToken = "yana_phonepe_token_2026_secure";

  // Razorpay native checkout config
  static const bool enableRazorpay = true;
  static const String razorpayKeyId = "rzp_live_SZhvow8Swy6BcS";
  static const String razorpayOrderCreateUrl =
      "https://yanaworldwide.store/api/razorpay/create-order.php";
  static const String razorpayVerifyUrl =
      "https://yanaworldwide.store/api/razorpay/verify-payment.php";
  static const String razorpayBackendToken = "yana_phonepe_token_2026_secure";

  static const String snapmintCheckoutUrl =
      "https://yanaworldwide.store/api/snapmint_checkout_endpoint.php";

  // Motorcycle service AI estimate endpoint (PHP backend).
  static const String motorcycleServicePriceApiUrl =
      "https://yanaworldwide.store/api/bike_service_price.php";
  static const String motorcycleServiceApiToken =
      "YANAWORLDWIDE_8f3K@29xP!mQ2026";
  static const String motorcycleServiceBookingCreateUrl =
      "https://yanaworldwide.store/api/service_booking_create.php";
  static const String motorcycleServiceBookingListUrl =
      "https://yanaworldwide.store/api/service_booking_list.php";
  static const String motorcycleServiceBookingUpdateUrl =
      "https://yanaworldwide.store/api/service_booking_update.php";

  // Legacy PhonePe fields kept for backward compatibility in unused code paths.
  static const String phonePeBackendRequestUrl = "";
  static const String phonePeBackendToken = "";
}

