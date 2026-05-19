import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:flutter_snapmint_sdk/flutter_snapmint_sdk.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/coupon_service.dart';
import '../services/payu_service.dart';
import '../services/razorpay_service.dart';
import '../services/woo_service.dart';
import '../theme/app_theme.dart';
import 'order_success_screen.dart';

import 'package:intl_phone_field/intl_phone_field.dart';

const Color checkoutBg = Color(0xFFF3F5FB);
const Color checkoutSurface = Colors.white;
const Color checkoutAccent = Color(0xFF1E3A8A);
const Color checkoutTextMuted = Color(0xFF6B7280);
const Color checkoutTextPrimary = Color(0xFF111827);

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final WooService api = WooService();
  final PayUService _payuService = PayUService();
  final RazorpayService _razorpayService = RazorpayService();
  final CFPaymentGatewayService _cashfreeGateway = CFPaymentGatewayService();
  final bool _isCashfreeEnabled = Config.enableCashfree;
  final bool _isRazorpayEnabled = Config.enableRazorpay;
  bool _isPayuAllowedForUser = false;
  Completer<bool>? _cashfreePaymentCompleter;
  String _cashfreeLastOrderId = "";
  Map<String, dynamic>? _cachedCashfreePendingOrder;
  String _cachedCashfreePendingOrderKey = "";
  Map<String, dynamic>? _cachedRazorpayPendingOrder;
  String _cachedRazorpayPendingOrderKey = "";
  Map<String, dynamic>? _cachedSnapmintPendingOrder;
  String _cachedSnapmintPendingOrderKey = "";
  Timer? _processingStageTimer;
  bool _showProcessingOverlay = false;
  int _processingStageIndex = 0;
  static const List<String> _processingSteps = [
    "We are creating a new user",
    "Creating order",
    "Fetching user data",
    "Now processing payment options",
  ];
  static const String _savedAddressesKey = 'checkout_saved_addresses_v1';

  bool isLoading = false;
  bool isCodAvailable = false;

  List shippingMethods = [];
  String shippingMethodId = "";
  String shippingMethodTitle = "";
  String shippingTotal = "0";
  String selectedCountryCode = "IN";
  String selectedCountryName = "India";
  String selectedStateName = "";
  String completePhoneNumber = "";
  String initialPhoneNumber = "";
  List<Map<String, String>> _savedAddresses = const <Map<String, String>>[];
  String _selectedSavedAddressKey = "";
  bool _isAddingNewAddress = false;
  bool _isAddressBootstrapLoading = true;
  final List<String> indiaStates = [
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
    "Andaman and Nicobar Islands",
    "Chandigarh",
    "Dadra and Nagar Haveli and Daman and Diu",
    "Delhi",
    "Jammu and Kashmir",
    "Ladakh",
    "Lakshadweep",
    "Puducherry",
  ];
  final Map<String, String> countryList = {
    "India": "IN",
    "United States": "US",
    "United Kingdom": "GB",
    "Australia": "AU",
    "Canada": "CA",
    "Germany": "DE",
    "France": "FR",
    "Italy": "IT",
    "Spain": "ES",
    "Netherlands": "NL",
    "Brazil": "BR",
    "Russia": "RU",
    "China": "CN",
    "Japan": "JP",
    "South Korea": "KR",
    "Indonesia": "ID",
    "Malaysia": "MY",
    "Singapore": "SG",
    "Thailand": "TH",
    "United Arab Emirates": "AE",
    "Saudi Arabia": "SA",
    "South Africa": "ZA",
    "Sri Lanka": "LK",
    "Nepal": "NP",
    "Bangladesh": "BD",
    "Pakistan": "PK",
    "Mexico": "MX",
    "Argentina": "AR",
    "Turkey": "TR",
    "New Zealand": "NZ",
  };

  /// ✅ Payment Option (full, partial, snapmint)
  String selectedPaymentOption = "full";
  String selectedOnlineGateway = "razorpay";

  /// 🔹 State variables for calculations
  double totalAmount = 0.0;
  final couponController = TextEditingController();
  double discountAmount = 0.0;
  String appliedCouponCode = "";
  bool isCouponApplied = false;
  bool walletLoading = false;
  bool walletEnabled = false;
  bool walletBanned = false;
  double walletBalance = 0.0;
  double walletMinBilling = 2000.0;
  bool _cashbackEnabled = false;
  double _cashbackSpendAmount = 1000.0;
  double _cashbackRewardAmount = 50.0;

  /// Controllers
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final addressController = TextEditingController();
  final apartmentController = TextEditingController();
  final cityController = TextEditingController();
  final pinController = TextEditingController();
  final notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cashfreeGateway.setCallback(_onCashfreeVerify, _onCashfreeError);
    AnalyticsService.instance.logScreen("checkout");
    _loadGatewayAccess();
    _loadGrowthConfig();
    loadShipping();
    loadCodAvailability();
    prefillCustomerDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingCoupon();
      _loadWalletStatus();
    });
  }

  @override
  void dispose() {
    _processingStageTimer?.cancel();
    _razorpayService.dispose();
    couponController.dispose();
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    addressController.dispose();
    apartmentController.dispose();
    cityController.dispose();
    pinController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _completeCashfree(bool result) {
    if (_cashfreePaymentCompleter != null &&
        !_cashfreePaymentCompleter!.isCompleted) {
      _cashfreePaymentCompleter!.complete(result);
    }
  }

  Future<void> _loadGatewayAccess() async {
    final isPrivilegedAdmin = await AuthService().isPrivilegedAdmin();
    if (!mounted) return;
    setState(() {
      _isPayuAllowedForUser = isPrivilegedAdmin;
      if (!_isPayuAllowedForUser && selectedOnlineGateway == "payu") {
        selectedOnlineGateway = "razorpay";
      }
    });
  }

  String _buildCashfreePendingOrderKey({
    required List<CartItem> cartItems,
    required bool isPartialCashfree,
    required double finalAmount,
  }) {
    final itemKey = cartItems
        .map(
          (item) =>
              "${item.id}:${item.variationId ?? 0}:${item.quantity}",
        )
        .join("|");
    return [
      isPartialCashfree ? "partial" : "full",
      finalAmount.toStringAsFixed(2),
      itemKey,
    ].join("::");
  }

  void _clearCachedCashfreePendingOrder() {
    _cachedCashfreePendingOrder = null;
    _cachedCashfreePendingOrderKey = "";
  }

  String _buildRazorpayPendingOrderKey({
    required List<CartItem> cartItems,
    required bool isPartialRazorpay,
    required double finalAmount,
  }) {
    final itemKey = cartItems
        .map(
          (item) =>
              "${item.id}:${item.variationId ?? 0}:${item.quantity}",
        )
        .join("|");
    return [
      isPartialRazorpay ? "partial" : "full",
      finalAmount.toStringAsFixed(2),
      itemKey,
    ].join("::");
  }

  void _clearCachedRazorpayPendingOrder() {
    _cachedRazorpayPendingOrder = null;
    _cachedRazorpayPendingOrderKey = "";
  }

  String _buildOnlinePendingOrderKey({
    required List<CartItem> cartItems,
    required bool isPartialPayment,
    required double finalAmount,
  }) {
    final itemKey = cartItems
        .map(
          (item) =>
              "${item.id}:${item.variationId ?? 0}:${item.quantity}",
        )
        .join("|");
    return [
      isPartialPayment ? "partial" : "full",
      finalAmount.toStringAsFixed(2),
      itemKey,
    ].join("::");
  }

  Map<String, dynamic>? _findReusableOnlinePendingOrder({
    required String pendingOrderKey,
  }) {
    final candidates = <MapEntry<String, Map<String, dynamic>?>>[
      MapEntry(_cachedCashfreePendingOrderKey, _cachedCashfreePendingOrder),
      MapEntry(_cachedRazorpayPendingOrderKey, _cachedRazorpayPendingOrder),
    ];
    for (final candidate in candidates) {
      final order = candidate.value;
      final orderId = int.tryParse((order?["id"] ?? "").toString());
      if (candidate.key == pendingOrderKey &&
          order != null &&
          orderId != null &&
          orderId > 0) {
        return Map<String, dynamic>.from(order);
      }
    }
    return null;
  }

  void _clearAllCachedPendingOrders() {
    _clearCachedCashfreePendingOrder();
    _clearCachedRazorpayPendingOrder();
    _clearCachedSnapmintPendingOrder();
  }

  Future<bool> _waitForOrderStatus(
    int orderId, {
    required Set<String> acceptedStatuses,
    int attempts = 4,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final order = await api.fetchOrderById(orderId);
      final status = (order["status"] ?? "").toString().trim().toLowerCase();
      if (acceptedStatuses.contains(status)) {
        return true;
      }
      if (attempt < attempts - 1) {
        await Future<void>.delayed(delay);
      }
    }
    return false;
  }

  Widget _buildGatewayOptionTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final palette = context.appPalette;
    final isSelected = groupValue == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? palette.surfaceSoft : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.accent : palette.border,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: palette.accent.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: palette.accent,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              onChanged: (selected) {
                if (selected != null) onChanged(selected);
              },
            ),
            const SizedBox(width: 6),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? palette.accent.withOpacity(0.12)
                    : palette.surfaceStrong,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: palette.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSnapmintPendingOrderKey({
    required List<CartItem> cartItems,
    required double finalAmount,
  }) {
    final itemKey = cartItems
        .map(
          (item) =>
              "${item.id}:${item.variationId ?? 0}:${item.quantity}",
        )
        .join("|");
    return [
      "snapmint",
      finalAmount.toStringAsFixed(2),
      itemKey,
    ].join("::");
  }

  void _clearCachedSnapmintPendingOrder() {
    _cachedSnapmintPendingOrder = null;
    _cachedSnapmintPendingOrderKey = "";
  }

  void _beginProcessingOverlay() {
    _processingStageTimer?.cancel();
    if (mounted) {
      setState(() {
        _showProcessingOverlay = true;
        _processingStageIndex = 0;
      });
    }
    _processingStageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_processingStageIndex >= _processingSteps.length - 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _processingStageIndex++;
      });
    });
  }

  void _endProcessingOverlay() {
    _processingStageTimer?.cancel();
    _processingStageTimer = null;
    if (!mounted) return;
    setState(() {
      _showProcessingOverlay = false;
      _processingStageIndex = 0;
    });
  }

  Widget _buildProcessingOverlay({required bool isSnapmint}) {
    final palette = context.appPalette;
    final headline = isSnapmint
        ? "1st time ordering with Yanaworldwide may take 20 to 30 seconds."
        : "1st time ordering with Yanaworldwide may take 30 to 40 seconds.";
    final currentStep =
        _processingSteps[_processingStageIndex.clamp(0, _processingSteps.length - 1)];
    final progressValue = (_processingStageIndex + 1) / _processingSteps.length;
    final overlayColor = palette.textPrimary.withValues(alpha: 0.38);
    final cardColor = palette.surface;
    final borderColor = palette.border;
    final softFill = palette.surfaceStrong;
    final accentColor = palette.accent;
    final accentStrongColor = palette.accentStrong;

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: overlayColor,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: palette.textPrimary.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accentColor, accentStrongColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accentStrongColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Step ${_processingStageIndex + 1} of ${_processingSteps.length}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentStep,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please wait while we set up your order.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 8,
                      backgroundColor: softFill,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_processingSteps.length, (index) {
                      final isActive = index == _processingStageIndex;
                      final isDone = index < _processingStageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 26 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isActive || isDone
                              ? accentColor
                              : softFill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadGrowthConfig() async {
    final data = await api.fetchGrowthConfig();
    if (!mounted || data == null) return;

    final cashbackRaw = data["cashback"];
    final cashback = cashbackRaw is Map
        ? Map<String, dynamic>.from(cashbackRaw)
        : const <String, dynamic>{};

    setState(() {
      _cashbackEnabled = cashback["enabled"] == true;
      _cashbackSpendAmount =
          double.tryParse((cashback["spend_amount"] ?? "1000").toString()) ??
          1000.0;
      _cashbackRewardAmount =
          double.tryParse((cashback["cashback_amount"] ?? "50").toString()) ??
          50.0;
    });
  }

  bool _isCashbackEligible(double amount) {
    if (!_cashbackEnabled) return false;
    if (_cashbackSpendAmount <= 0 || _cashbackRewardAmount <= 0) return false;
    return amount >= _cashbackSpendAmount;
  }

  String _cashbackHint(double amount) {
    if (!_cashbackEnabled || _cashbackSpendAmount <= 0 || _cashbackRewardAmount <= 0) {
      return "";
    }
    if (_isCashbackEligible(amount)) {
      return
          "Eligible: is order par ₹${_cashbackRewardAmount.toStringAsFixed(0)} wallet cashback mil sakta hai.";
    }
    final remaining = (_cashbackSpendAmount - amount).clamp(0, _cashbackSpendAmount);
    return
        "₹${_cashbackSpendAmount.toStringAsFixed(0)} spend par ₹${_cashbackRewardAmount.toStringAsFixed(0)} cashback. Sirf ₹${remaining.toStringAsFixed(0)} aur add karo.";
  }

  void _onCashfreeVerify(String orderId) {
    _cashfreeLastOrderId = orderId.trim();
    debugPrint("[CASHFREE][FLOW] verify callback orderId=$orderId");
    _completeCashfree(true);
  }

  void _onCashfreeError(CFErrorResponse error, String orderId) {
    final rawMessage = (error.getMessage() ?? "Cashfree payment failed").trim();
    final message = _normalizePaymentFailureMessage(
      rawMessage,
      gatewayLabel: "Cashfree",
    );
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isNotEmpty) {
      _cashfreeLastOrderId = normalizedOrderId;
    }
    debugPrint(
      "[CASHFREE][FLOW] error callback orderId=$orderId message=$rawMessage code=${error.getCode()} type=${error.getType()}",
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    _completeCashfree(false);
  }

  Future<void> prefillCustomerDetails() async {
    try {
      final userIdRaw = await AuthService().getUserId();
      final userId = int.tryParse(userIdRaw ?? "");
      final authService = AuthService();
      final fallbackEmail = await authService.getUserEmail();

      if (userId == null) {
        if (!mounted) return;
        if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
          setState(() {
            emailController.text = fallbackEmail;
          });
        }
        await _loadSavedAddresses();
        return;
      }

      final customer = await api.getCustomer(userId);
      if (customer == null || !mounted) {
        await _loadSavedAddresses();
        return;
      }

      final billing = customer["billing"] as Map<String, dynamic>? ?? {};
      final firstName = (billing["first_name"] ?? customer["first_name"] ?? "")
          .toString();
      final lastName = (billing["last_name"] ?? customer["last_name"] ?? "")
          .toString();
      final email = (billing["email"] ?? customer["email"] ?? fallbackEmail ?? "")
          .toString();
      final phone = (billing["phone"] ?? "").toString();
      final address1 = (billing["address_1"] ?? "").toString();
      final address2 = (billing["address_2"] ?? "").toString();
      final city = (billing["city"] ?? "").toString();
      final state = (billing["state"] ?? "").toString();
      final postcode = (billing["postcode"] ?? "").toString();
      final countryCode = (billing["country"] ?? "").toString().toUpperCase();

      final countryName = countryList.entries
          .where((e) => e.value.toUpperCase() == countryCode)
          .map((e) => e.key)
          .cast<String?>()
          .firstWhere((name) => name != null, orElse: () => selectedCountryName);

      setState(() {
        if (email.isNotEmpty) emailController.text = email;
        if (firstName.isNotEmpty) firstNameController.text = firstName;
        if (lastName.isNotEmpty) lastNameController.text = lastName;
        if (address1.isNotEmpty) addressController.text = address1;
        if (address2.isNotEmpty) apartmentController.text = address2;
        if (city.isNotEmpty) cityController.text = city;
        if (postcode.isNotEmpty) pinController.text = postcode;
        if ((countryName ?? "").isNotEmpty) {
          selectedCountryName = countryName!;
          selectedCountryCode =
              countryList[selectedCountryName] ?? selectedCountryCode;
        }
        if (state.isNotEmpty) {
          final normalizedState = _normalizeStateForUi(
            state,
            selectedCountryName,
          );
          selectedStateName = normalizedState;
        }
        if (phone.isNotEmpty) {
          completePhoneNumber = phone;
          initialPhoneNumber = _extractPhoneForInput(phone, selectedCountryCode);
        }
      });
      await _saveCurrentAddressToBook();
      await _loadSavedAddresses();
    } finally {
      if (!mounted) return;
      setState(() {
        _isAddressBootstrapLoading = false;
      });
    }
  }

  Map<String, String> _buildAddressEntryFromCurrentForm() {
    return <String, String>{
      'first_name': firstNameController.text.trim(),
      'last_name': lastNameController.text.trim(),
      'address_1': addressController.text.trim(),
      'address_2': apartmentController.text.trim(),
      'city': cityController.text.trim(),
      'state': selectedStateName.trim(),
      'postcode': pinController.text.trim(),
      'country_code': selectedCountryCode.trim(),
      'country_name': selectedCountryName.trim(),
      'phone': completePhoneNumber.trim(),
      'label': _addressLabelFromParts(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        address1: addressController.text.trim(),
      ),
    };
  }

  String _addressLabelFromParts({
    required String firstName,
    required String lastName,
    required String address1,
  }) {
    final fullName = "$firstName $lastName".trim();
    if (fullName.isNotEmpty) return fullName;
    if (address1.isNotEmpty) {
      final words = address1.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2);
      final compact = words.join(' ').trim();
      if (compact.isNotEmpty) return compact;
    }
    return "Saved Address";
  }

  String _addressEntryKey(Map<String, String> entry) {
    return [
      (entry['address_1'] ?? '').trim().toLowerCase(),
      (entry['address_2'] ?? '').trim().toLowerCase(),
      (entry['city'] ?? '').trim().toLowerCase(),
      (entry['state'] ?? '').trim().toLowerCase(),
      (entry['postcode'] ?? '').trim().toLowerCase(),
      (entry['country_code'] ?? '').trim().toLowerCase(),
      (entry['phone'] ?? '').trim().toLowerCase(),
    ].join('|');
  }

  String _addressPreview(Map<String, String> entry) {
    return [
      (entry['address_1'] ?? '').trim(),
      (entry['address_2'] ?? '').trim(),
      (entry['city'] ?? '').trim(),
      (entry['state'] ?? '').trim(),
      (entry['postcode'] ?? '').trim(),
    ].where((part) => part.isNotEmpty).join(', ');
  }

  String _normalizePaymentFailureMessage(
    String rawMessage, {
    required String gatewayLabel,
  }) {
    final message = rawMessage.trim();
    final normalized = message.toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'undefined' ||
        normalized == 'null' ||
        normalized == 'payment failed' ||
        normalized == '$gatewayLabel payment failed'.toLowerCase()) {
      return "$gatewayLabel payment was not completed. Please retry.";
    }
    if (normalized.contains('cancel') ||
        normalized.contains('cancelled') ||
        normalized.contains('canceled') ||
        normalized.contains('back pressed') ||
        normalized.contains('user closed') ||
        normalized.contains('user aborted')) {
      return "$gatewayLabel payment was cancelled. Please retry.";
    }
    return message;
  }

  Future<void> _loadSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_savedAddressesKey) ?? const <String>[];
    final parsed = <Map<String, String>>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final entry = <String, String>{};
          for (final item in decoded.entries) {
            final key = item.key.toString().trim();
            if (key.isEmpty) continue;
            entry[key] = item.value?.toString() ?? '';
          }
          if ((entry['address_1'] ?? '').trim().isNotEmpty) {
            parsed.add(entry);
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _savedAddresses = parsed;
      if (parsed.isEmpty) {
        _isAddingNewAddress = true;
      } else if (_selectedSavedAddressKey.isEmpty) {
        _selectedSavedAddressKey = _addressEntryKey(parsed.first);
        _isAddingNewAddress = false;
      }
    });
  }

  Future<void> _saveCurrentAddressToBook({bool showFeedback = false}) async {
    final entry = _buildAddressEntryFromCurrentForm();
    if ((entry['address_1'] ?? '').isEmpty ||
        (entry['city'] ?? '').isEmpty ||
        (entry['postcode'] ?? '').isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_savedAddressesKey) ?? const <String>[];
    final entries = <Map<String, String>>[];
    final newKey = _addressEntryKey(entry);

    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final current = <String, String>{};
          for (final item in decoded.entries) {
            final key = item.key.toString().trim();
            if (key.isEmpty) continue;
            current[key] = item.value?.toString() ?? '';
          }
          if (_addressEntryKey(current) != newKey) {
            entries.add(current);
          }
        }
      } catch (_) {}
    }

    entries.insert(0, entry);
    if (entries.length > 8) {
      entries.removeRange(8, entries.length);
    }

    await prefs.setStringList(
      _savedAddressesKey,
      entries.map((e) => jsonEncode(e)).toList(growable: false),
    );

    if (!mounted) return;
    setState(() {
      _savedAddresses = entries;
      _selectedSavedAddressKey = newKey;
      _isAddingNewAddress = false;
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved for next time')),
      );
    }
  }

  void _applySavedAddress(Map<String, String> entry) {
    setState(() {
      firstNameController.text = entry['first_name'] ?? '';
      lastNameController.text = entry['last_name'] ?? '';
      addressController.text = entry['address_1'] ?? '';
      apartmentController.text = entry['address_2'] ?? '';
      cityController.text = entry['city'] ?? '';
      pinController.text = entry['postcode'] ?? '';
      selectedCountryCode = (entry['country_code'] ?? 'IN').isEmpty
          ? 'IN'
          : (entry['country_code'] ?? 'IN');
      selectedCountryName = (entry['country_name'] ?? 'India').isEmpty
          ? 'India'
          : (entry['country_name'] ?? 'India');
      selectedStateName = entry['state'] ?? '';
      completePhoneNumber = entry['phone'] ?? '';
      initialPhoneNumber = _extractPhoneForInput(
        completePhoneNumber,
        selectedCountryCode,
      );
      _selectedSavedAddressKey = _addressEntryKey(entry);
      _isAddingNewAddress = false;
    });
  }

  void _startNewAddressEntry() {
    setState(() {
      addressController.clear();
      apartmentController.clear();
      cityController.clear();
      pinController.clear();
      selectedCountryCode = 'IN';
      selectedCountryName = 'India';
      selectedStateName = '';
      _selectedSavedAddressKey = '';
      _isAddingNewAddress = true;
    });
  }

  Future<void> _showSavedAddressPicker() async {
    if (_savedAddresses.isEmpty) return;
    final palette = context.appPalette;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Saved Addresses",
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _startNewAddressEntry();
                    },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text("Add New Address"),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _savedAddresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final entry = _savedAddresses[index];
                      final isSelected =
                          _selectedSavedAddressKey == _addressEntryKey(entry);
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _applySavedAddress(entry);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.surfaceStrong,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? palette.accent : palette.border,
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: palette.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry['label'] ?? 'Saved Address',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _addressPreview(entry),
                                      style: TextStyle(
                                        color: palette.textMuted,
                                        fontSize: 12.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected ? palette.accent : palette.textMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _extractPhoneForInput(String phone, String countryCode) {
    final digits = phone.replaceAll(RegExp(r"[^0-9]"), "");
    if (digits.isEmpty) return "";
    if (countryCode == "IN") {
      if (digits.length >= 10) {
        return digits.substring(digits.length - 10);
      }
    }
    return digits;
  }

  String _normalizeStateForUi(String rawState, String countryName) {
    final trimmed = rawState.trim();
    if (trimmed.isEmpty) return "";

    if (countryName != "India") return trimmed;

    const indiaStateCodeMap = {
      "AN": "Andaman and Nicobar Islands",
      "AP": "Andhra Pradesh",
      "AR": "Arunachal Pradesh",
      "AS": "Assam",
      "BR": "Bihar",
      "CH": "Chandigarh",
      "CT": "Chhattisgarh",
      "DN": "Dadra and Nagar Haveli and Daman and Diu",
      "DD": "Dadra and Nagar Haveli and Daman and Diu",
      "DL": "Delhi",
      "GA": "Goa",
      "GJ": "Gujarat",
      "HR": "Haryana",
      "HP": "Himachal Pradesh",
      "JK": "Jammu and Kashmir",
      "JH": "Jharkhand",
      "KA": "Karnataka",
      "KL": "Kerala",
      "LA": "Ladakh",
      "LD": "Lakshadweep",
      "MP": "Madhya Pradesh",
      "MH": "Maharashtra",
      "MN": "Manipur",
      "ML": "Meghalaya",
      "MZ": "Mizoram",
      "NL": "Nagaland",
      "OR": "Odisha",
      "OD": "Odisha",
      "PY": "Puducherry",
      "PB": "Punjab",
      "RJ": "Rajasthan",
      "SK": "Sikkim",
      "TN": "Tamil Nadu",
      "TS": "Telangana",
      "TR": "Tripura",
      "UP": "Uttar Pradesh",
      "UK": "Uttarakhand",
      "UT": "Uttarakhand",
      "WB": "West Bengal",
    };

    final upper = trimmed.toUpperCase();
    if (indiaStateCodeMap.containsKey(upper)) {
      return indiaStateCodeMap[upper]!;
    }

    final match = indiaStates.where(
      (s) => s.toLowerCase() == trimmed.toLowerCase(),
    );
    return match.isNotEmpty ? match.first : "";
  }

  Future<bool> _startCashfreePayment({
    required double amount,
    String merchantOrderId = "",
  }) async {
    debugPrint(
      "[CASHFREE][FLOW] start amount=${amount.toStringAsFixed(2)}",
    );
    final requestData = await api.createCashfreeOrderToken(
      amount: amount,
      customerName: "${firstNameController.text} ${lastNameController.text}"
          .trim(),
      customerEmail: emailController.text.trim(),
      customerPhone: completePhoneNumber.trim(),
      merchantOrderId: merchantOrderId,
    );

    if (requestData == null || requestData.isEmpty) {
      debugPrint("[CASHFREE][FLOW] requestData is null/empty");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to start Cashfree payment")),
        );
      }
      return false;
    }

    final responseStatus = int.tryParse(
      (requestData["http_status"] ?? "").toString(),
    );
    final responseMessage = (requestData["message"] ?? requestData["error"] ?? "")
        .toString()
        .trim();
    if (responseStatus != null &&
        (responseStatus < 200 || responseStatus >= 300)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseMessage.isNotEmpty
                  ? "Cashfree backend error ($responseStatus): $responseMessage"
                  : "Cashfree backend error ($responseStatus)",
            ),
          ),
        );
      }
      return false;
    }

    final orderId = (requestData["order_id"] ?? requestData["orderId"] ?? "")
        .toString()
        .trim();
    final paymentSessionId =
        (requestData["payment_session_id"] ??
                requestData["paymentSessionId"] ??
                requestData["session_id"] ??
                "")
            .toString()
            .trim();

    if (orderId.isEmpty || paymentSessionId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Cashfree backend response mismatch: order_id/payment_session_id required",
            ),
          ),
        );
      }
      return false;
    }
    _cashfreeLastOrderId = orderId;

    final envRaw = Config.cashfreeEnvironment.trim().toUpperCase();
    final env = envRaw == "SANDBOX"
        ? CFEnvironment.SANDBOX
        : CFEnvironment.PRODUCTION;

    try {
      final session = CFSessionBuilder()
          .setEnvironment(env)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final payment = CFWebCheckoutPaymentBuilder().setSession(session).build();
      _cashfreePaymentCompleter = Completer<bool>();
      _cashfreeGateway.doPayment(payment);
      return _cashfreePaymentCompleter!.future.timeout(
        const Duration(minutes: 8),
        onTimeout: () {
          debugPrint("[CASHFREE][FLOW] timeout waiting for callback");
          return false;
        },
      );
    } on CFException catch (e) {
      debugPrint("[CASHFREE][FLOW] exception=${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cashfree exception: ${e.message}")),
        );
      }
      return false;
    } catch (e) {
      debugPrint("[CASHFREE][FLOW] exception=$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cashfree error: $e")),
        );
      }
      return false;
    }
  }

  Future<RazorpayPaymentResult> _startRazorpayPayment({
    required double amount,
    String merchantOrderId = "",
  }) async {
    debugPrint(
      "[RAZORPAY][FLOW] start amount=${amount.toStringAsFixed(2)} merchantOrderId=$merchantOrderId",
    );
    final requestData = await api.createRazorpayOrder(
      amount: amount,
      customerName: "${firstNameController.text} ${lastNameController.text}"
          .trim(),
      customerEmail: emailController.text.trim(),
      customerPhone: completePhoneNumber.trim(),
      merchantOrderId: merchantOrderId,
    );

    if (requestData == null || requestData.isEmpty) {
      return const RazorpayPaymentResult(
        success: false,
        failureReason: "Unable to start Razorpay payment",
      );
    }

    final responseStatus = int.tryParse(
      (requestData["http_status"] ?? "").toString(),
    );
    final responseMessage = (requestData["message"] ??
            requestData["error"] ??
            requestData["description"] ??
            "")
        .toString()
        .trim();
    if (responseStatus != null &&
        (responseStatus < 200 || responseStatus >= 300)) {
      return RazorpayPaymentResult(
        success: false,
        failureReason: responseMessage.isNotEmpty
            ? "Razorpay backend error ($responseStatus): $responseMessage"
            : "Razorpay backend error ($responseStatus)",
      );
    }

    final razorpayOrderId = (requestData["order_id"] ??
            requestData["razorpay_order_id"] ??
            requestData["id"] ??
            "")
        .toString()
        .trim();
    final keyId = (requestData["key_id"] ??
            requestData["key"] ??
            Config.razorpayKeyId)
        .toString()
        .trim();

    if (razorpayOrderId.isEmpty || keyId.isEmpty) {
      return const RazorpayPaymentResult(
        success: false,
        failureReason: "Razorpay backend response mismatch: order_id/key_id required",
      );
    }

    return _razorpayService.startPayment(
      keyId: keyId,
      orderId: razorpayOrderId,
      amount: amount,
      name: "${firstNameController.text} ${lastNameController.text}".trim(),
      email: emailController.text.trim(),
      phone: completePhoneNumber.trim(),
    );
  }

  Future<bool> _startSnapmintPayment({
    required int orderId,
    required double amount,
    int? userId,
  }) async {
    final resolvedUserId =
        userId ?? int.tryParse((await AuthService().getUserId() ?? "").trim());
    final checkoutUrl = await api.createSnapmintCheckoutUrl(
      orderId: orderId,
      userId: resolvedUserId,
      device: Platform.isIOS ? "ios" : "android",
    );

    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to get Snapmint checkout link"),
          ),
        );
      }
      return false;
    }

    try {
      final result = await RNSnapmintCheckout.openSnapmintMerchant(
        checkoutUrl,
        options: PaymentOptions(
          onSuccess: (r) {
            debugPrint(
              "[SNAPMINT][FLOW] success status=${r.status} code=${r.statusCode} paymentId=${r.paymentId}",
            );
          },
          onError: (e) {
            debugPrint(
              "[SNAPMINT][FLOW] error status=${e.status} code=${e.statusCode} message=${e.responseMsg ?? e.message}",
            );
          },
        ),
      );

      final normalizedStatus = result.status.trim().toLowerCase();
      final normalizedCode = result.statusCode ?? 0;
      final isSuccess = normalizedStatus == "success" || normalizedCode == 200;
      if (!isSuccess) return false;

      final updated = await api.markSnapmintOrderPaid(
        orderId: orderId,
        transactionId: (result.paymentId ?? "").trim(),
      );

      final statusSynced = updated &&
          await _waitForOrderStatus(
            orderId,
            acceptedStatuses: const {"processing"},
          );

      if (!statusSynced) {
        await AnalyticsService.instance.logPaymentStatus(
          orderId: orderId,
          status: "payment_success_but_order_update_failed",
          paymentMethod: "snapmint",
          amount: amount,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Snapmint payment done, but Woo order update failed"),
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("[SNAPMINT][FLOW] exception=$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Snapmint payment failed: $e")),
        );
      }
      return false;
    }
  }

  Future<void> loadCodAvailability() async {
    final codEnabled = await api.isCodEnabled();
    if (!mounted) return;

    setState(() {
      isCodAvailable = codEnabled;
      if (!isCodAvailable && selectedPaymentOption == "cod") {
        selectedPaymentOption = "full";
      }
    });
  }

  Future<void> loadShipping() async {
    final data = await api.fetchShippingMethods();

    if (data.isNotEmpty) {
      shippingMethodId = data[0]["method_id"];
      shippingMethodTitle = data[0]["title"];
      shippingTotal = data[0]["settings"]["cost"]["value"];
    }

    setState(() {
      shippingMethods = data;
    });
  }

  double _couponEligibleTotal() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return cart.total + (double.tryParse(shippingTotal) ?? 0.0);
  }

  Future<void> _loadWalletStatus() async {
    if (!mounted) return;
    setState(() => walletLoading = true);
    final response = await api.fetchWalletStatus(orderAmount: _couponEligibleTotal());
    if (!mounted) return;

    if (response == null || response["ok"] != true) {
      setState(() {
        walletLoading = false;
        walletEnabled = false;
        walletBanned = false;
        walletBalance = 0.0;
        walletMinBilling = 2000.0;
      });
      return;
    }

    final availableRaw = (response["available_to_use"] ?? response["balance"] ?? "0").toString();
    final balanceRaw = (response["balance"] ?? "0").toString();
    final minRaw = (response["min_billing"] ?? "2000").toString();
    final banned = response["banned"] == true;

    final available = double.tryParse(availableRaw) ?? 0.0;
    final balance = double.tryParse(balanceRaw) ?? 0.0;
    final minBilling = double.tryParse(minRaw) ?? 2000.0;

    setState(() {
      walletLoading = false;
      walletBanned = banned;
      walletBalance = balance;
      walletMinBilling = minBilling;
      if (banned || available <= 0) {
        walletEnabled = false;
      }
    });
  }

  Future<void> _loadPendingCoupon() async {
    final pending = await CouponService.instance.getPendingCouponCode();
    if (!mounted || pending == null || pending.trim().isEmpty) return;

    final code = pending.trim().toUpperCase();
    final alreadyUsed = await CouponService.instance.isCouponUsed(code);
    if (alreadyUsed) {
      await CouponService.instance.clearPendingCoupon();
      return;
    }

    couponController.text = code;
    await _applyCouponCode(
      code,
      fromNotification: true,
      silentInvalid: true,
    );
  }

  Future<void> _applyCouponCode(
    String code, {
    bool fromNotification = false,
    bool silentInvalid = false,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;

    if (isCouponApplied) {
      if (appliedCouponCode.trim().toUpperCase() == normalized) return;
      if (!silentInvalid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Only one coupon can be used at a time")),
        );
      }
      return;
    }

    final alreadyUsed = await CouponService.instance.isCouponUsed(normalized);
    if (alreadyUsed) {
      if (!silentInvalid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This coupon is already used")),
        );
      }
      return;
    }

    final couponBaseTotal = _couponEligibleTotal();
    final result = await api.checkCoupon(normalized, couponBaseTotal);
    if (result == null) {
      if (!silentInvalid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Coupon")),
        );
      }
      return;
    }

    final min = double.tryParse((result["min"] ?? "0").toString()) ?? 0;
    var max =
        double.tryParse((result["max"] ?? "9999999").toString()) ?? 9999999;
    if (max <= 0) {
      max = 9999999;
    }

    if (couponBaseTotal < min) {
      if (!silentInvalid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Minimum order ₹${min.toStringAsFixed(0)} required",
            ),
          ),
        );
      }
      return;
    }

    if (couponBaseTotal > max) {
      if (!silentInvalid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Coupon valid up to ₹${max.toStringAsFixed(0)} only",
            ),
          ),
        );
      }
      return;
    }

    double nextDiscount = 0.0;
    final valueRaw = (result["value"] ?? "").toString();
    if (valueRaw.contains("%")) {
      final percent = double.tryParse(valueRaw.replaceAll("%", "").trim()) ?? 0;
      nextDiscount = couponBaseTotal * (percent / 100);
    } else {
      nextDiscount = double.tryParse(valueRaw) ?? 0;
    }
    if (nextDiscount > couponBaseTotal) {
      nextDiscount = couponBaseTotal;
    }

    if (!mounted) return;
    setState(() {
      appliedCouponCode = normalized;
      isCouponApplied = true;
      discountAmount = nextDiscount;
      couponController.text = normalized;
    });

    if (fromNotification && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Coupon auto-applied: $normalized")),
      );
    }
    _loadWalletStatus();
  }

  Future<void> _clearAppliedCoupon({bool clearPending = true}) async {
    if (clearPending) {
      await CouponService.instance.clearPendingCoupon();
    }
    if (!mounted) return;
    setState(() {
      discountAmount = 0.0;
      appliedCouponCode = "";
      isCouponApplied = false;
      couponController.clear();
    });
    _loadWalletStatus();
  }

  Future<void> _markCouponConsumedIfApplied() async {
    final code = appliedCouponCode.trim();
    if (code.isEmpty) return;
    await CouponService.instance.markCouponUsed(code);
  }

  void _applyWalletLocallyAfterOrder(double usedAmount) {
    if (usedAmount <= 0) return;
    setState(() {
      walletEnabled = false;
      walletBalance = (walletBalance - usedAmount).clamp(0, walletBalance);
    });
  }

  Future<void> startPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter phone number")),
      );
      return;
    }

    if (selectedCountryName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select country")));
      return;
    }

    if (selectedStateName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select state")));
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
      return;
    }

    // Calculate dynamic amounts based on current UI state
    double subtotal = cart.total + (double.tryParse(shippingTotal) ?? 0.0);
    double afterCouponAmount = subtotal - discountAmount;
    final walletAllowedByBill = afterCouponAmount >= walletMinBilling;
    final double maxWalletUsable = walletAllowedByBill && !walletBanned
        ? walletBalance.clamp(0, afterCouponAmount).toDouble()
        : 0.0;
    final double walletUsedAmount = walletEnabled ? maxWalletUsable : 0.0;
    double baseFinalAmount = afterCouponAmount - walletUsedAmount;
    if (baseFinalAmount < 0) {
      baseFinalAmount = 0.0;
    }
    double snapmintProcessingCharge = selectedPaymentOption == "snapmint"
        ? baseFinalAmount * 0.04
        : 0.0;
    double finalAmount = baseFinalAmount + snapmintProcessingCharge;
    final cashbackEligibleAmount = finalAmount;
    await AnalyticsService.instance.logBeginCheckout(
      itemsCount: cart.items.length,
      value: finalAmount,
    );

    if (selectedPaymentOption == "snapmint") {
      _beginProcessingOverlay();
      try {
        setState(() => isLoading = true);
        final pendingOrderKey = _buildSnapmintPendingOrderKey(
          cartItems: cart.items,
          finalAmount: finalAmount,
        );
        final cachedOrderId = int.tryParse(
          (_cachedSnapmintPendingOrder?["id"] ?? "").toString(),
        );
        final hasReusablePendingOrder =
            _cachedSnapmintPendingOrder != null &&
            _cachedSnapmintPendingOrderKey == pendingOrderKey &&
            cachedOrderId != null &&
            cachedOrderId > 0;
        final order = hasReusablePendingOrder
            ? Map<String, dynamic>.from(_cachedSnapmintPendingOrder!)
            : await api.createOrder(
                cartItems: cart.items,
                name: "${firstNameController.text} ${lastNameController.text}",
                email: emailController.text.trim(),
                phone: completePhoneNumber,
                address: "${addressController.text}, ${apartmentController.text}",
                shippingMethodId: shippingMethodId,
                shippingMethodTitle: shippingMethodTitle,
                shippingTotal: shippingTotal,
                city: cityController.text,
                state: selectedStateName,
                pincode: pinController.text,
                country: selectedCountryName,
                notes: notesController.text,
                paymentType: "snapmint",
                totalAmount: finalAmount,
                couponCode: isCouponApplied ? appliedCouponCode : "",
                walletUsedAmount: walletUsedAmount,
                cashbackThreshold: _cashbackEnabled ? _cashbackSpendAmount : 0.0,
                cashbackRewardAmount: _cashbackEnabled ? _cashbackRewardAmount : 0.0,
                cashbackEligibleAmount: cashbackEligibleAmount,
              );

        final orderId = int.tryParse((order["id"] ?? "").toString());
        if (order.isEmpty || orderId == null || orderId <= 0) {
          setState(() => isLoading = false);
          await AnalyticsService.instance.logPaymentStatus(
            orderId: null,
            status: "order_create_failed",
            paymentMethod: "snapmint",
            amount: finalAmount,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Order creation failed"),
            ),
          );
          return;
        }

        _cachedSnapmintPendingOrder = Map<String, dynamic>.from(order);
        _cachedSnapmintPendingOrderKey = pendingOrderKey;

        await AnalyticsService.instance.logPaymentStatus(
          orderId: orderId,
          status: hasReusablePendingOrder
              ? "order_reused_pending_for_retry"
              : "order_created_pending",
          paymentMethod: "snapmint",
          amount: finalAmount,
        );
        await AnalyticsService.instance.logPaymentStatus(
          orderId: orderId,
          status: "payment_initiated",
          paymentMethod: "snapmint",
          amount: finalAmount,
        );

        final paymentSuccess = await _startSnapmintPayment(
          orderId: orderId,
          amount: finalAmount,
          userId: int.tryParse((order["customer_id"] ?? "").toString()),
        );
        setState(() => isLoading = false);

        if (!paymentSuccess) {
          await AnalyticsService.instance.logPaymentStatus(
            orderId: orderId,
            status: "payment_not_completed",
            paymentMethod: "snapmint",
            amount: finalAmount,
          );
          return;
        }

        _applyWalletLocallyAfterOrder(walletUsedAmount);
        cart.clearCart();
        _navigateToOrderSuccess(orderId);
        _runPostSuccessTask(() async {
          _clearAllCachedPendingOrders();
          await _saveCurrentAddressToBook();
          await _markCouponConsumedIfApplied();
          await _syncCustomerDetailsAfterOrder(order);
          await AnalyticsService.instance.logPaymentStatus(
            orderId: orderId,
            status: "payment_success",
            paymentMethod: "snapmint",
            amount: finalAmount,
          );
          await AnalyticsService.instance.logPurchase(
            orderId: orderId,
            amount: finalAmount,
          );
          _clearCachedSnapmintPendingOrder();
        });
        return;
      } finally {
        _endProcessingOverlay();
      }
    }
    if (selectedPaymentOption == "cod") {
      _beginProcessingOverlay();
      setState(() => isLoading = true);

      final order = await api.createOrder(
        cartItems: cart.items,
        name: "${firstNameController.text} ${lastNameController.text}",
        email: emailController.text.trim(),
        phone: completePhoneNumber,
        address: "${addressController.text}, ${apartmentController.text}",
        shippingMethodId: shippingMethodId,
        shippingMethodTitle: shippingMethodTitle,
        shippingTotal: shippingTotal,
        city: cityController.text,
        state: selectedStateName,
        pincode: pinController.text,
        country: selectedCountryName,
        notes: notesController.text,
        paymentType: "cod",
        totalAmount: finalAmount,
        couponCode: isCouponApplied ? appliedCouponCode : "",
        walletUsedAmount: walletUsedAmount,
        cashbackThreshold: _cashbackEnabled ? _cashbackSpendAmount : 0.0,
        cashbackRewardAmount: _cashbackEnabled ? _cashbackRewardAmount : 0.0,
        cashbackEligibleAmount: cashbackEligibleAmount,
      );

      setState(() => isLoading = false);
      _endProcessingOverlay();

      if (order.isNotEmpty) {
        final createdOrderId = int.tryParse(order["id"].toString()) ?? 0;
        _clearAllCachedPendingOrders();
        _applyWalletLocallyAfterOrder(walletUsedAmount);
        cart.clearCart();
        _navigateToOrderSuccess(createdOrderId);
        _runPostSuccessTask(() async {
          await _saveCurrentAddressToBook();
          await _markCouponConsumedIfApplied();
          await AnalyticsService.instance.logPaymentStatus(
            orderId: createdOrderId,
            status: "cod_order_created",
            paymentMethod: "cod",
            amount: finalAmount,
          );
          await AnalyticsService.instance.logPurchase(
            orderId: createdOrderId,
            amount: finalAmount,
          );
          await _syncCustomerDetailsAfterOrder(order);
        });
      } else {
        await AnalyticsService.instance.logPaymentStatus(
          orderId: null,
          status: "order_create_failed",
          paymentMethod: "cod",
          amount: finalAmount,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Order Creation Failed")));
      }
      return;
    }
    // --- Normal Prepaid/Partial Flow ---
    double payableAmount = selectedPaymentOption == "full"
        ? finalAmount
        : WooService.partialAdvanceAmount(finalAmount);

    final payName = "${firstNameController.text} ${lastNameController.text}"
        .trim();
    final payEmail = emailController.text.trim();
    final payPhone = completePhoneNumber.trim();

    // Cashfree flow via native SDK.
    if (_isCashfreeEnabled &&
        selectedOnlineGateway == "cashfree" &&
        (selectedPaymentOption == "full" ||
            selectedPaymentOption == "partial")) {
      _beginProcessingOverlay();
      try {
        setState(() => isLoading = true);
        final isPartialCashfree = selectedPaymentOption == "partial";
        final sharedPendingOrderKey = _buildOnlinePendingOrderKey(
          cartItems: cart.items,
          isPartialPayment: isPartialCashfree,
          finalAmount: finalAmount,
        );
        final pendingOrderKey = _buildCashfreePendingOrderKey(
          cartItems: cart.items,
          isPartialCashfree: isPartialCashfree,
          finalAmount: finalAmount,
        );
        final reusablePendingOrder = _findReusableOnlinePendingOrder(
          pendingOrderKey: sharedPendingOrderKey,
        );
        final hasReusablePendingOrder = reusablePendingOrder != null;
        final pendingOrder = hasReusablePendingOrder
            ? Map<String, dynamic>.from(reusablePendingOrder!)
            : await api.createOrder(
                cartItems: cart.items,
                name: "${firstNameController.text} ${lastNameController.text}",
                email: emailController.text.trim(),
                phone: completePhoneNumber,
                address: "${addressController.text}, ${apartmentController.text}",
                shippingMethodId: shippingMethodId,
                shippingMethodTitle: shippingMethodTitle,
                shippingTotal: shippingTotal,
                city: cityController.text,
                state: selectedStateName,
                pincode: pinController.text,
                country: selectedCountryName,
                notes: notesController.text,
                paymentType: isPartialCashfree
                    ? "cashfree_partial_pending"
                    : "cashfree_pending",
                totalAmount: finalAmount,
                couponCode: isCouponApplied ? appliedCouponCode : "",
                walletUsedAmount: walletUsedAmount,
                cashbackThreshold: _cashbackEnabled ? _cashbackSpendAmount : 0.0,
                cashbackRewardAmount: _cashbackEnabled ? _cashbackRewardAmount : 0.0,
                cashbackEligibleAmount: cashbackEligibleAmount,
              );

        if (pendingOrder.isEmpty) {
          setState(() => isLoading = false);
          await AnalyticsService.instance.logPaymentStatus(
            orderId: null,
            status: "order_create_failed_before_payment",
            paymentMethod: "cashfree",
            amount: finalAmount,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Unable to create order before payment")),
          );
          return;
        }

        final pendingOrderId = int.tryParse((pendingOrder["id"] ?? "").toString());
        if (pendingOrderId != null && pendingOrderId > 0) {
          _cachedCashfreePendingOrder = Map<String, dynamic>.from(pendingOrder);
          _cachedCashfreePendingOrderKey = pendingOrderKey;
        }
        await AnalyticsService.instance.logPaymentStatus(
          orderId: pendingOrderId,
          status: hasReusablePendingOrder
              ? "order_reused_pending_for_retry"
              : "order_created_pending",
          paymentMethod: "cashfree",
          amount: finalAmount,
        );
        await AnalyticsService.instance.logPaymentStatus(
          orderId: pendingOrderId,
          status: "payment_initiated",
          paymentMethod: "cashfree",
          amount: payableAmount,
        );
        final paymentSuccess = await _startCashfreePayment(
          amount: payableAmount,
          merchantOrderId: (pendingOrder["id"] ?? "").toString(),
        );
        setState(() => isLoading = false);

        final verified = _cashfreeLastOrderId.trim().isNotEmpty
            ? await api.verifyCashfreeOrderStatus(orderId: _cashfreeLastOrderId)
            : false;

        if (paymentSuccess || verified) {
          if (pendingOrderId == null || pendingOrderId <= 0) {
            await AnalyticsService.instance.logPaymentStatus(
              orderId: null,
              status: "cashfree_order_id_missing_after_success",
              paymentMethod: "cashfree",
              amount: finalAmount,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Payment verified but Woo order id missing")),
            );
            return;
          }

          setState(() => isLoading = true);
          final updated = isPartialCashfree
              ? await api.markCashfreePartialOrderPaid(
                  orderId: pendingOrderId,
                  cashfreeOrderId: _cashfreeLastOrderId,
                )
              : await api.markCashfreeOrderPaid(
                  orderId: pendingOrderId,
                  cashfreeOrderId: _cashfreeLastOrderId,
                );
          setState(() => isLoading = false);

          if (!updated) {
            await AnalyticsService.instance.logPaymentStatus(
              orderId: pendingOrderId,
              status: "payment_success_but_order_update_failed",
              paymentMethod: "cashfree",
              amount: finalAmount,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Payment verified, but Woo order update failed"),
              ),
            );
            return;
          }

          _applyWalletLocallyAfterOrder(walletUsedAmount);
          _clearAllCachedPendingOrders();
          cart.clearCart();
          _navigateToOrderSuccess(pendingOrderId);
          _runPostSuccessTask(() async {
            await _saveCurrentAddressToBook();
            final statusSynced = await _waitForOrderStatus(
              pendingOrderId,
              acceptedStatuses: isPartialCashfree
                  ? const {"on-hold"}
                  : const {"processing"},
            );
            if (!statusSynced) {
              await AnalyticsService.instance.logPaymentStatus(
                orderId: pendingOrderId,
                status: "payment_success_but_status_sync_delayed",
                paymentMethod: "cashfree",
                amount: finalAmount,
              );
            }
            await _markCouponConsumedIfApplied();
            await _syncCustomerDetailsAfterOrder(pendingOrder);
            await AnalyticsService.instance.logPaymentStatus(
              orderId: pendingOrderId,
              status: "payment_success",
              paymentMethod: "cashfree",
              amount: finalAmount,
            );
            await AnalyticsService.instance.logPurchase(
              orderId: pendingOrderId,
              amount: finalAmount,
            );
          });
          return;
        }

        await AnalyticsService.instance.logPaymentStatus(
          orderId: pendingOrderId,
          status: "payment_not_completed",
          paymentMethod: "cashfree",
          amount: finalAmount,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _normalizePaymentFailureMessage(
                "Cashfree payment was not completed",
                gatewayLabel: "Cashfree",
              ),
            ),
          ),
        );
        return;
      } finally {
        _endProcessingOverlay();
      }
    }

    if (_isRazorpayEnabled &&
        selectedOnlineGateway == "razorpay" &&
        (selectedPaymentOption == "full" ||
            selectedPaymentOption == "partial")) {
      _beginProcessingOverlay();
      try {
        setState(() => isLoading = true);
        final isPartialRazorpay = selectedPaymentOption == "partial";
        final sharedPendingOrderKey = _buildOnlinePendingOrderKey(
          cartItems: cart.items,
          isPartialPayment: isPartialRazorpay,
          finalAmount: finalAmount,
        );
        final pendingOrderKey = _buildRazorpayPendingOrderKey(
          cartItems: cart.items,
          isPartialRazorpay: isPartialRazorpay,
          finalAmount: finalAmount,
        );
        final reusablePendingOrder = _findReusableOnlinePendingOrder(
          pendingOrderKey: sharedPendingOrderKey,
        );
        final hasReusablePendingOrder = reusablePendingOrder != null;
        final pendingOrder = hasReusablePendingOrder
            ? Map<String, dynamic>.from(reusablePendingOrder!)
            : await api.createOrder(
                cartItems: cart.items,
                name: "${firstNameController.text} ${lastNameController.text}",
                email: emailController.text.trim(),
                phone: completePhoneNumber,
                address: "${addressController.text}, ${apartmentController.text}",
                shippingMethodId: shippingMethodId,
                shippingMethodTitle: shippingMethodTitle,
                shippingTotal: shippingTotal,
                city: cityController.text,
                state: selectedStateName,
                pincode: pinController.text,
                country: selectedCountryName,
                notes: notesController.text,
                paymentType: isPartialRazorpay
                    ? "razorpay_partial_pending"
                    : "razorpay_pending",
                totalAmount: finalAmount,
                couponCode: isCouponApplied ? appliedCouponCode : "",
                walletUsedAmount: walletUsedAmount,
                cashbackThreshold: _cashbackEnabled ? _cashbackSpendAmount : 0.0,
                cashbackRewardAmount: _cashbackEnabled ? _cashbackRewardAmount : 0.0,
                cashbackEligibleAmount: cashbackEligibleAmount,
              );

        if (pendingOrder.isEmpty) {
          setState(() => isLoading = false);
          await AnalyticsService.instance.logPaymentStatus(
            orderId: null,
            status: "order_create_failed_before_payment",
            paymentMethod: "razorpay",
            amount: finalAmount,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Unable to create order before payment")),
          );
          return;
        }

        final pendingOrderId = int.tryParse((pendingOrder["id"] ?? "").toString());
        if (pendingOrderId != null && pendingOrderId > 0) {
          _cachedRazorpayPendingOrder = Map<String, dynamic>.from(pendingOrder);
          _cachedRazorpayPendingOrderKey = pendingOrderKey;
        }
        await AnalyticsService.instance.logPaymentStatus(
          orderId: pendingOrderId,
          status: hasReusablePendingOrder
              ? "order_reused_pending_for_retry"
              : "order_created_pending",
          paymentMethod: "razorpay",
          amount: finalAmount,
        );
        await AnalyticsService.instance.logPaymentStatus(
          orderId: pendingOrderId,
          status: "payment_initiated",
          paymentMethod: "razorpay",
          amount: payableAmount,
        );

        final paymentResult = await _startRazorpayPayment(
          amount: payableAmount,
          merchantOrderId: (pendingOrder["id"] ?? "").toString(),
        );
        setState(() => isLoading = false);

        if (!paymentResult.success) {
          final failureMessage = _normalizePaymentFailureMessage(
            paymentResult.failureReason,
            gatewayLabel: "Razorpay",
          );
          await AnalyticsService.instance.logPaymentStatus(
            orderId: pendingOrderId,
            status: "payment_not_completed",
            paymentMethod: "razorpay",
            amount: finalAmount,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failureMessage,
              ),
            ),
          );
          return;
        }

        final verified = await api.verifyRazorpayPayment(
          razorpayOrderId: paymentResult.orderId,
          razorpayPaymentId: paymentResult.paymentId,
          razorpaySignature: paymentResult.signature,
          merchantOrderId: (pendingOrder["id"] ?? "").toString(),
        );

        if (pendingOrderId == null || pendingOrderId <= 0) {
          await AnalyticsService.instance.logPaymentStatus(
            orderId: null,
            status: "razorpay_order_id_missing_after_success",
            paymentMethod: "razorpay",
            amount: finalAmount,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Payment verified but Woo order id missing")),
          );
          return;
        }

        if (!verified) {
          await AnalyticsService.instance.logPaymentStatus(
            orderId: pendingOrderId,
            status: "payment_verification_failed",
            paymentMethod: "razorpay",
            amount: finalAmount,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Razorpay payment verification failed")),
          );
          return;
        }

        setState(() => isLoading = true);
        final updated = isPartialRazorpay
            ? await api.markRazorpayPartialOrderPaid(
                orderId: pendingOrderId,
                razorpayPaymentId: paymentResult.paymentId,
                razorpayOrderId: paymentResult.orderId,
              )
            : await api.markRazorpayOrderPaid(
                orderId: pendingOrderId,
                razorpayPaymentId: paymentResult.paymentId,
                razorpayOrderId: paymentResult.orderId,
              );
        setState(() => isLoading = false);

        if (!updated) {
          await AnalyticsService.instance.logPaymentStatus(
            orderId: pendingOrderId,
            status: "payment_success_but_order_update_failed",
            paymentMethod: "razorpay",
            amount: finalAmount,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment verified, but Woo order update failed"),
            ),
          );
          return;
        }

        _applyWalletLocallyAfterOrder(walletUsedAmount);
        _clearAllCachedPendingOrders();
        cart.clearCart();
        _navigateToOrderSuccess(pendingOrderId);
        _runPostSuccessTask(() async {
          await _saveCurrentAddressToBook();
          final statusSynced = await _waitForOrderStatus(
            pendingOrderId,
            acceptedStatuses: isPartialRazorpay
                ? const {"on-hold"}
                : const {"processing"},
          );
          if (!statusSynced) {
            await AnalyticsService.instance.logPaymentStatus(
              orderId: pendingOrderId,
              status: "payment_success_but_status_sync_delayed",
              paymentMethod: "razorpay",
              amount: finalAmount,
            );
          }
          await _markCouponConsumedIfApplied();
          await _syncCustomerDetailsAfterOrder(pendingOrder);
          await AnalyticsService.instance.logPaymentStatus(
            orderId: pendingOrderId,
            status: "payment_success",
            paymentMethod: "razorpay",
            amount: finalAmount,
          );
          await AnalyticsService.instance.logPurchase(
            orderId: pendingOrderId,
            amount: finalAmount,
          );
        });
        return;
      } finally {
        _endProcessingOverlay();
      }
    }

    if (!_isPayuAllowedForUser) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PayU is available only for admin users")),
      );
      return;
    }

    setState(() => isLoading = true);
    final isPartialPayu = selectedPaymentOption == "partial";
    final payPhoneDigits = payPhone.replaceAll(RegExp(r"[^0-9]"), "");
    if (payPhoneDigits.length < 10) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PayU requires a valid phone number"),
        ),
      );
      return;
    }
    await AnalyticsService.instance.logPaymentStatus(
      orderId: null,
      status: "payment_initiated",
      paymentMethod: "payu",
      amount: payableAmount,
    );
    final paymentSuccess = await _payuService.startPayment(
      amount: payableAmount,
      name: payName,
      email: payEmail,
      phone: payPhone,
    );
    setState(() => isLoading = false);

    if (paymentSuccess == true) {
      setState(() => isLoading = true);
      final payuPaymentType = isPartialPayu ? "payu_sdk_partial" : "payu_sdk_full";
      final order = await api.createOrder(
        cartItems: cart.items,
        name: "${firstNameController.text} ${lastNameController.text}",
        email: emailController.text.trim(),
        phone: completePhoneNumber,
        address: "${addressController.text}, ${apartmentController.text}",
        shippingMethodId: shippingMethodId,
        shippingMethodTitle: shippingMethodTitle,
        shippingTotal: shippingTotal,
        city: cityController.text,
        state: selectedStateName,
        pincode: pinController.text,
        country: selectedCountryName,
        notes: notesController.text,
        paymentType: payuPaymentType,
        totalAmount: finalAmount,
        couponCode: isCouponApplied ? appliedCouponCode : "",
        walletUsedAmount: walletUsedAmount,
        cashbackThreshold: _cashbackEnabled ? _cashbackSpendAmount : 0.0,
        cashbackRewardAmount: _cashbackEnabled ? _cashbackRewardAmount : 0.0,
        cashbackEligibleAmount: cashbackEligibleAmount,
      );
      setState(() => isLoading = false);

      if (order.isEmpty) {
        await AnalyticsService.instance.logPaymentStatus(
          orderId: null,
          status: "order_create_failed_after_payment",
          paymentMethod: "payu",
          amount: finalAmount,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment done, but order creation failed")),
        );
        return;
      }

      final createdOrderId = int.tryParse(order["id"].toString()) ?? 0;
      _clearAllCachedPendingOrders();
      _applyWalletLocallyAfterOrder(walletUsedAmount);
      cart.clearCart();
      _navigateToOrderSuccess(createdOrderId);
      _runPostSuccessTask(() async {
        await _saveCurrentAddressToBook();
        await _markCouponConsumedIfApplied();
        await AnalyticsService.instance.logPaymentStatus(
          orderId: createdOrderId,
          status: "payment_success",
          paymentMethod: "payu",
          amount: finalAmount,
        );
        await AnalyticsService.instance.logPurchase(
          orderId: createdOrderId,
          amount: finalAmount,
        );
        await _syncCustomerDetailsAfterOrder(order);
      });
    } else {
      final failureReason =
          (_payuService.lastFailureReason ?? "PayU payment was not completed").trim();
      await AnalyticsService.instance.logPaymentStatus(
        orderId: null,
        status: "payment_not_completed",
        paymentMethod: "payu",
        amount: payableAmount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureReason)),
      );
    }
  }

  Future<void> _syncCustomerDetailsAfterOrder(
    Map<String, dynamic> order,
  ) async {
    try {
      final orderCustomerId = int.tryParse(
        (order["customer_id"] ?? "").toString(),
      );
      final loginUserId = int.tryParse(
        (await AuthService().getUserId() ?? "").toString(),
      );
      final customerId = orderCustomerId != null && orderCustomerId > 0
          ? orderCustomerId
          : loginUserId;

      if (customerId == null || customerId <= 0) return;

      await api.updateAccountDetails(
        customerId: customerId,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        email: emailController.text.trim(),
        phone: completePhoneNumber.trim(),
      );

      await api.updateCustomerAddress(
        customerId: customerId,
        address: "${addressController.text}, ${apartmentController.text}"
            .trim(),
        city: cityController.text.trim(),
        state: selectedStateName.trim(),
        pincode: pinController.text.trim(),
        country: selectedCountryCode.trim(),
      );
    } catch (_) {}
  }

  void _navigateToOrderSuccess(int orderId) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(orderId: orderId),
      ),
    );
  }

  void _runPostSuccessTask(Future<void> Function() task) {
    unawaited(
      Future<void>(() async {
        try {
          await task();
        } catch (error, stackTrace) {
          debugPrint('[CHECKOUT][POST_SUCCESS] $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final cart = Provider.of<CartProvider>(context);

    // Recalculate amounts on every build to reflect coupon/shipping changes
    totalAmount = cart.total + (double.tryParse(shippingTotal) ?? 0.0);
    final afterCouponAmount = totalAmount - discountAmount;
    final walletAllowedByBill = afterCouponAmount >= walletMinBilling;
    final double maxWalletUsable = walletAllowedByBill && !walletBanned
        ? walletBalance.clamp(0, afterCouponAmount).toDouble()
        : 0.0;
    final double walletUsedAmount = walletEnabled ? maxWalletUsable : 0.0;
    double baseFinalAmount = afterCouponAmount - walletUsedAmount;
    if (baseFinalAmount < 0) {
      baseFinalAmount = 0.0;
    }
    double snapmintProcessingCharge = selectedPaymentOption == "snapmint"
        ? baseFinalAmount * 0.04
        : 0.0;
    double finalAmount = baseFinalAmount + snapmintProcessingCharge;
    final int advancePercent =
        (WooService.partialAdvanceRate(baseFinalAmount) * 100).round();
    double advanceAmount = WooService.partialAdvanceAmount(baseFinalAmount);
    double remainingAmount = WooService.partialRemainingAmount(baseFinalAmount);
    final cashbackEligible = _isCashbackEligible(finalAmount);
    final cashbackHint = _cashbackHint(finalAmount);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: palette.background,
        canvasColor: palette.surface,
        cardColor: palette.surface,
        dividerColor: palette.border,
        colorScheme: ColorScheme.dark(
          primary: palette.accent,
          secondary: palette.accent,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          onPrimary: palette.onAccent,
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return palette.accent;
            }
            return palette.textMuted;
          }),
        ),
        listTileTheme: ListTileThemeData(
          iconColor: palette.textMuted,
          textColor: palette.textPrimary,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.surface,
          labelStyle: TextStyle(color: palette.textMuted),
          hintStyle: TextStyle(color: palette.textMuted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.accent, width: 1.2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.border),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.surface,
          elevation: 0,
          title: Text(
            "Checkout",
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          iconTheme: IconThemeData(color: palette.textPrimary),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
        // --- Use Column to fix the button at the bottom ---
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Form(
                      key: _formKey,
                      child: Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.border),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Contact Information",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: "Email *",
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: "First Name *",
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? "Required" : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: "Last Name *",
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? "Required" : null,
                                ),
                              ),
                            ],
                           ),
                           const SizedBox(height: 20),
                           if (_isAddressBootstrapLoading) ...[
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(
                                 color: palette.surfaceStrong,
                                 borderRadius: BorderRadius.circular(18),
                                 border: Border.all(color: palette.border),
                               ),
                               child: Row(
                                 children: [
                                   SizedBox(
                                     width: 20,
                                     height: 20,
                                     child: CircularProgressIndicator(
                                       strokeWidth: 2.4,
                                       valueColor: AlwaysStoppedAnimation<Color>(
                                         palette.accent,
                                       ),
                                     ),
                                   ),
                                   const SizedBox(width: 12),
                                   Expanded(
                                     child: Text(
                                       "Loading your saved address...",
                                       style: TextStyle(
                                         color: palette.textPrimary,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             const SizedBox(height: 20),
                           ] else ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _savedAddresses.isNotEmpty
                                        ? "Saved Addresses"
                                        : "Address",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: palette.textPrimary,
                                          side: BorderSide(color: palette.border),
                                        ),
                                        onPressed: _startNewAddressEntry,
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text("Add New"),
                                      ),
                                      if (_savedAddresses.isNotEmpty)
                                        TextButton(
                                          onPressed: _showSavedAddressPicker,
                                          child: const Text("Choose"),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                             const SizedBox(height: 8),
                             if (_savedAddresses.isNotEmpty) ...[
                               ..._savedAddresses.take(3).map((entry) {
                                final isSelected =
                                    _selectedSavedAddressKey == _addressEntryKey(entry);
                                return Padding(
                                 padding: const EdgeInsets.only(bottom: 10),
                                 child: InkWell(
                                   borderRadius: BorderRadius.circular(18),
                                   onTap: () => _applySavedAddress(entry),
                                   child: Container(
                                     padding: const EdgeInsets.all(14),
                                     decoration: BoxDecoration(
                                       color: palette.surfaceStrong,
                                       borderRadius: BorderRadius.circular(18),
                                       border: Border.all(
                                         color: isSelected
                                             ? palette.accent
                                             : palette.border,
                                         width: isSelected ? 1.4 : 1,
                                       ),
                                     ),
                                     child: Row(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Icon(
                                           Icons.location_on_outlined,
                                           color: palette.textMuted,
                                         ),
                                         const SizedBox(width: 10),
                                         Expanded(
                                           child: Column(
                                             crossAxisAlignment:
                                                 CrossAxisAlignment.start,
                                             children: [
                                               Text(
                                                 entry['label'] ?? 'Saved Address',
                                                 style: TextStyle(
                                                   color: palette.textPrimary,
                                                   fontWeight: FontWeight.w700,
                                                 ),
                                               ),
                                               const SizedBox(height: 4),
                                               Text(
                                                 _addressPreview(entry),
                                                 style: TextStyle(
                                                   color: palette.textMuted,
                                                   fontSize: 12.5,
                                                   height: 1.35,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                         const SizedBox(width: 10),
                                         Icon(
                                           isSelected
                                               ? Icons.radio_button_checked
                                               : Icons.radio_button_off,
                                           color: isSelected
                                               ? palette.accent
                                               : palette.textMuted,
                                         ),
                                       ],
                                     ),
                                   ),
                                 ),
                                );
                               }),
                               const SizedBox(height: 8),
                             ],
                           ],
                           if (!_isAddressBootstrapLoading &&
                               _savedAddresses.isNotEmpty &&
                               !_isAddingNewAddress) ...[
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(14),
                               decoration: BoxDecoration(
                                 color: palette.surfaceStrong,
                                 borderRadius: BorderRadius.circular(18),
                                 border: Border.all(color: palette.border),
                               ),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     "Selected Shipping Address",
                                     style: TextStyle(
                                       color: palette.textPrimary,
                                       fontWeight: FontWeight.w700,
                                     ),
                                   ),
                                   const SizedBox(height: 6),
                                   Text(
                                     _addressPreview(_savedAddresses.firstWhere(
                                       (entry) =>
                                           _addressEntryKey(entry) ==
                                           _selectedSavedAddressKey,
                                       orElse: () => _savedAddresses.first,
                                     )),
                                     style: TextStyle(
                                       color: palette.textMuted,
                                       height: 1.4,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             const SizedBox(height: 20),
                            ] else if (!_isAddressBootstrapLoading) ...[
                             const Text(
                               "Shipping Address",
                               style: TextStyle(
                                 fontSize: 18,
                                 fontWeight: FontWeight.w700,
                               ),
                             ),
                             const SizedBox(height: 10),
                             TextFormField(
                               controller: addressController,
                               decoration: const InputDecoration(
                                 labelText: "Street Address *",
                                 border: OutlineInputBorder(),
                               ),
                               validator: (v) => v!.isEmpty ? "Required" : null,
                             ),
                             const SizedBox(height: 10),
                             TextFormField(
                               controller: apartmentController,
                               decoration: const InputDecoration(
                                 labelText: "Apartment, Suite, Unit (Optional)",
                                 border: OutlineInputBorder(),
                               ),
                             ),
                             const SizedBox(height: 10),
                             TextFormField(
                               controller: cityController,
                               decoration: const InputDecoration(
                                 labelText: "City *",
                                 border: OutlineInputBorder(),
                               ),
                               validator: (v) => v!.isEmpty ? "Required" : null,
                             ),
                             const SizedBox(height: 10),
                             DropdownButtonFormField<String>(
                               initialValue: selectedCountryName,
                               isExpanded: true,
                               decoration: const InputDecoration(
                                 labelText: "Country *",
                                 border: OutlineInputBorder(),
                               ),
                               items: countryList.keys.map((country) {
                                 return DropdownMenuItem<String>(
                                   value: country,
                                   child: Text(
                                     country,
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 );
                               }).toList(),
                               onChanged: (value) {
                                 setState(() {
                                   selectedCountryName = value!;
                                   selectedCountryCode = countryList[value]!;
                                   selectedStateName = "";
                                 });
                               },
                               validator: (value) => value == null || value.isEmpty
                                   ? "Please select country"
                                   : null,
                             ),
                             const SizedBox(height: 10),
                             DropdownButtonFormField<String>(
                               initialValue: selectedStateName.isEmpty
                                   ? null
                                   : selectedStateName,
                               isExpanded: true,
                               decoration: const InputDecoration(
                                 labelText: "State *",
                                 border: OutlineInputBorder(),
                               ),
                               items:
                                   (selectedCountryName == "India"
                                           ? indiaStates
                                           : ["Select State"])
                                       .map((state) {
                                         return DropdownMenuItem<String>(
                                           value: state,
                                           child: Text(
                                             state,
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         );
                                       })
                                       .toList(),
                               onChanged: (value) {
                                 setState(() {
                                   selectedStateName = value!;
                                 });
                               },
                               validator: (value) => value == null || value.isEmpty
                                   ? "Please select state"
                                   : null,
                             ),
                             const SizedBox(height: 10),
                             TextFormField(
                               controller: pinController,
                               keyboardType: TextInputType.number,
                               decoration: const InputDecoration(
                                 labelText: "PIN Code *",
                                 border: OutlineInputBorder(),
                               ),
                               validator: (v) =>
                                   v!.length < 6 ? "Invalid PIN" : null,
                             ),
                             const SizedBox(height: 10),
                             IntlPhoneField(
                               key: ValueKey(
                                 "${selectedCountryCode}_$initialPhoneNumber",
                               ),
                               decoration: const InputDecoration(
                                 labelText: 'Phone Number *',
                                 border: OutlineInputBorder(),
                               ),
                               initialCountryCode: selectedCountryCode,
                               initialValue: initialPhoneNumber,
                               onChanged: (phone) {
                                 completePhoneNumber = phone.completeNumber;
                               },
                               validator: (phone) {
                                 if (phone == null || phone.number.length < 10) {
                                   return "Invalid phone";
                                 }
                                 return null;
                               },
                             ),
                             const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: palette.textPrimary,
                                    side: BorderSide(color: palette.border),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: () => _saveCurrentAddressToBook(
                                    showFeedback: true,
                                  ),
                                  icon: const Icon(Icons.add_location_alt_outlined),
                                  label: const Text(
                                    "Save this address",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                             const SizedBox(height: 20),
                           ],
                           // --- Coupon and Total Display ---
                          const Text(
                            "Apply Coupon",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: couponController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: "Enter coupon code",
                                    hintStyle: TextStyle(color: palette.textMuted),
                                    filled: true,
                                    fillColor: palette.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: palette.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: palette.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: palette.accent,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                  style: TextStyle(color: palette.textPrimary),
                                  onChanged: (value) {
                                    couponController.value = couponController
                                        .value
                                        .copyWith(
                                          text: value.toUpperCase(),
                                          selection: TextSelection.collapsed(
                                            offset: value.length,
                                          ),
                                        );
                                  },
                                  enabled: !isCouponApplied,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: checkoutAccent,
                                  foregroundColor: palette.onAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: isCouponApplied
                                    ? null
                                    : () async {
                                        await _applyCouponCode(
                                          couponController.text.trim(),
                                        );
                                      },
                                child: const Text(
                                  "Apply",
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isCouponApplied)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: palette.accent,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF171717),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.local_offer_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "COUPON APPLIED",
                                          style: TextStyle(
                                            color: palette.onAccent.withOpacity(0.72),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "SAVE ₹${discountAmount.toStringAsFixed(0)}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: palette.onAccent,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () async {
                                      await _clearAppliedCoupon();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF202020),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        appliedCouponCode,
                                        style: const TextStyle(
                                          color: Color(0xFFD7FC70),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: palette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: palette.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "App Wallet",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: palette.textPrimary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: walletLoading ? null : _loadWalletStatus,
                                      icon: Icon(Icons.refresh, size: 18, color: palette.textMuted),
                                      tooltip: "Refresh wallet",
                                    ),
                                  ],
                                ),
                                Text(
                                  "Balance: ₹${walletBalance.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Min billing for wallet: ₹${walletMinBilling.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (walletBanned)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text(
                                      "Wallet blocked by admin for this user/device.",
                                      style: TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                  )
                                else if (!walletAllowedByBill)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      "Wallet use starts from ₹${walletMinBilling.toStringAsFixed(0)} order value.",
                                      style: TextStyle(
                                        color: palette.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                CheckboxListTile(
                                  value: walletEnabled,
                                  onChanged: (walletBanned || !walletAllowedByBill || maxWalletUsable <= 0 || walletLoading)
                                      ? null
                                      : (value) {
                                          setState(() {
                                            walletEnabled = value ?? false;
                                          });
                                        },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  checkColor: palette.onAccent,
                                  activeColor: palette.accent,
                                  title: Text(
                                    "Use Wallet (up to ₹${maxWalletUsable.toStringAsFixed(2)})",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_cashbackEnabled &&
                              _cashbackSpendAmount > 0 &&
                              _cashbackRewardAmount > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cashbackEligible
                                    ? const Color(0xFFEFFCF3)
                                    : const Color(0xFFFFF8E8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cashbackEligible
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFACC15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        cashbackEligible
                                            ? Icons.verified_rounded
                                            : Icons.account_balance_wallet_rounded,
                                        color: cashbackEligible
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Wallet Cashback Offer",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: cashbackEligible
                                                ? const Color(0xFF166534)
                                                : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "₹${_cashbackSpendAmount.toStringAsFixed(0)} spend → ₹${_cashbackRewardAmount.toStringAsFixed(0)} wallet cashback",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (cashbackHint.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      cashbackHint,
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ===== ORDER SUMMARY =====
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: palette.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Order Summary",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Subtotal",
                                      style: TextStyle(color: palette.textMuted),
                                    ),
                                    Text(
                                      "₹${cart.total.toStringAsFixed(2)}",
                                      style: TextStyle(color: palette.textPrimary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Shipping",
                                      style: TextStyle(color: palette.textMuted),
                                    ),
                                    Text(
                                      "₹${double.tryParse(shippingTotal)?.toStringAsFixed(2) ?? "0.00"}",
                                      style: TextStyle(color: palette.textPrimary),
                                    ),
                                  ],
                                ),
                                if (discountAmount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Discount",
                                          style: TextStyle(color: Color(0xFF55D66B)),
                                        ),
                                        Text(
                                          "- ₹${discountAmount.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            color: Color(0xFF55D66B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (walletUsedAmount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Wallet Used",
                                          style: TextStyle(color: Color(0xFF55D66B)),
                                        ),
                                        Text(
                                          "- ₹${walletUsedAmount.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            color: Color(0xFF55D66B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (selectedPaymentOption == "snapmint")
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Snapmint Processing Charge (4%)",
                                          style: TextStyle(
                                            color: palette.accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          "+ \u20B9${snapmintProcessingCharge.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            color: palette.accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Divider(color: palette.border),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Grand Total",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      "₹${finalAmount.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (selectedPaymentOption == "partial") ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Advance ($advancePercent%)",
                                        style: TextStyle(color: palette.textMuted),
                                      ),
                                      Text(
                                        "₹${advanceAmount.toStringAsFixed(2)}",
                                        style: TextStyle(color: palette.textPrimary),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Remaining on Delivery",
                                        style: TextStyle(color: palette.textMuted),
                                      ),
                                      Text(
                                        "₹${remainingAmount.toStringAsFixed(2)}",
                                        style: TextStyle(color: palette.textPrimary),
                                      ),
                                    ],
                                  ),
                                ] else if (selectedPaymentOption == "cod") ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Pay Now",
                                        style: TextStyle(color: palette.textMuted),
                                      ),
                                      Text(
                                        "₹0.00",
                                        style: TextStyle(color: palette.textPrimary),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Pay on Delivery",
                                        style: TextStyle(color: palette.textMuted),
                                      ),
                                      Text(
                                        "₹${finalAmount.toStringAsFixed(2)}",
                                        style: TextStyle(color: palette.textPrimary),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- Payment Options ---
                          const Text(
                            "Select Payment Option",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RadioListTile<String>(
                            value: "full",
                            groupValue: selectedPaymentOption,
                            secondary: Icon(
                              Icons.credit_card_outlined,
                              color: selectedPaymentOption == "full"
                                  ? palette.accent
                                  : palette.textMuted,
                            ),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -1),
                            selected: selectedPaymentOption == "full",
                            activeColor: palette.accent,
                            tileColor: palette.surface,
                            selectedTileColor: palette.surfaceStrong,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selectedPaymentOption == "full"
                                    ? palette.accent
                                    : palette.border,
                                width: selectedPaymentOption == "full" ? 1.5 : 1,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(
                              "Prepaid Full Payment",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              "Pay \u20B9${baseFinalAmount.toStringAsFixed(2)} now",
                              style: TextStyle(
                                color: selectedPaymentOption == "full"
                                    ? palette.textPrimary
                                    : palette.textPrimary.withOpacity(0.82),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                selectedPaymentOption = value!;
                                if (selectedPaymentOption == "partial") {
                                  selectedOnlineGateway = "razorpay";
                                } else if (!_isPayuAllowedForUser) {
                                  selectedOnlineGateway = "razorpay";
                                }
                              });
                            },
                          ),
                          // 🆕 ADDED TEXT HERE
                          const Padding(
                            padding: EdgeInsets.only(left: 18.0, bottom: 10),
                            child: Text(
                              "Credit/Debit Card & NetBanking Payment",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          RadioListTile<String>(
                            value: "partial",
                            groupValue: selectedPaymentOption,
                            secondary: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: selectedPaymentOption == "partial"
                                  ? palette.accent
                                  : palette.textMuted,
                            ),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -1),
                            selected: selectedPaymentOption == "partial",
                            activeColor: palette.accent,
                            tileColor: palette.surface,
                            selectedTileColor: palette.surfaceStrong,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selectedPaymentOption == "partial"
                                    ? palette.accent
                                    : palette.border,
                                width: selectedPaymentOption == "partial" ? 1.5 : 1,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(
                              "Advance Payment + Remaining COD",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              "Pay \u20B9${advanceAmount.toStringAsFixed(2)} now\nRemaining \u20B9${remainingAmount.toStringAsFixed(2)} on Delivery",
                              style: TextStyle(
                                color: selectedPaymentOption == "partial"
                                    ? palette.textPrimary
                                    : palette.textPrimary.withOpacity(0.82),
                              ),
                            ),
                              onChanged: (value) {
                                setState(() {
                                  selectedPaymentOption = value!;
                                  selectedOnlineGateway = "razorpay";
                                });
                              },
                            ),
                          if (isCodAvailable)
                            RadioListTile<String>(
                              value: "cod",
                              groupValue: selectedPaymentOption,
                              secondary: Icon(
                                Icons.local_shipping_outlined,
                                color: selectedPaymentOption == "cod"
                                    ? palette.accent
                                    : palette.textMuted,
                              ),
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -1),
                              selected: selectedPaymentOption == "cod",
                              activeColor: palette.accent,
                              tileColor: palette.surface,
                              selectedTileColor: palette.surfaceStrong,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: selectedPaymentOption == "cod"
                                      ? palette.accent
                                      : palette.border,
                                  width: selectedPaymentOption == "cod" ? 1.5 : 1,
                                  ),
                                ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              title: Text(
                                "Cash on Delivery",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                "Pay \u20B9${finalAmount.toStringAsFixed(2)} on delivery",
                                style: TextStyle(
                                  color: selectedPaymentOption == "cod"
                                      ? palette.textPrimary
                                      : palette.textPrimary.withOpacity(0.82),
                                ),
                              ),
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentOption = value!;
                                    selectedOnlineGateway = "razorpay";
                                  });
                                },
                              ),
                          RadioListTile<String>(
                            value: "snapmint",
                            groupValue: selectedPaymentOption,
                            secondary: Icon(
                              Icons.bolt_outlined,
                              color: selectedPaymentOption == "snapmint"
                                  ? palette.accent
                                  : palette.textMuted,
                            ),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -1),
                            selected: selectedPaymentOption == "snapmint",
                            activeColor: palette.accent,
                            tileColor: palette.surface,
                            selectedTileColor: palette.surfaceStrong,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selectedPaymentOption == "snapmint"
                                    ? palette.accent
                                    : palette.border,
                                width: selectedPaymentOption == "snapmint" ? 1.5 : 1,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(
                              "Snapmint EMI (Buy Now Pay Later)",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              "Easy Monthly Installments Available",
                              style: TextStyle(
                                color: selectedPaymentOption == "snapmint"
                                    ? palette.textPrimary
                                    : palette.textPrimary.withOpacity(0.82),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                selectedPaymentOption = value!;
                                selectedOnlineGateway = "payu";
                              });
                            },
                          ),
                          // 🆕 ADDED TEXT HERE
                          const Padding(
                            padding: EdgeInsets.only(left: 18.0, bottom: 10),
                            child: Text(
                              "Snapmint 0% EMIs • Easy Returns • 3 Monthly Payments",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selectedPaymentOption == "full" ||
                              selectedPaymentOption == "partial") ...[
                            const SizedBox(height: 6),
                            const Text(
                              "Choose Online Gateway",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                _buildGatewayOptionTile(
                                  value: "cashfree",
                                  title: "Cashfree",
                                  subtitle: "Cards, UPI and netbanking",
                                  icon: Icons.account_balance_outlined,
                                  groupValue: selectedOnlineGateway,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedOnlineGateway = value;
                                    });
                                  },
                                ),
                                if (_isRazorpayEnabled) ...[
                                  const SizedBox(height: 10),
                                  _buildGatewayOptionTile(
                                    value: "razorpay",
                                    title: "Razorpay",
                                    subtitle: "Fast UPI, cards and wallet support",
                                    icon: Icons.flash_on_outlined,
                                    groupValue: selectedOnlineGateway,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedOnlineGateway = value;
                                      });
                                    },
                                  ),
                                ],
                                if (_isPayuAllowedForUser &&
                                    selectedPaymentOption == "full") ...[
                                  const SizedBox(height: 10),
                                  _buildGatewayOptionTile(
                                    value: "payu",
                                    title: "PayU",
                                    subtitle: "Admin access checkout",
                                    icon: Icons.language_outlined,
                                    groupValue: selectedOnlineGateway,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedOnlineGateway = value;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                          // 🏍️ STEP 2 — EMI estimate (Updated)
                          if (selectedPaymentOption == "snapmint")
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                bottom: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "3 Months EMI: ₹${(finalAmount / 3).toStringAsFixed(0)} / month",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "6 Months EMI: ₹${(finalAmount / 6).toStringAsFixed(0)} / month",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 80), // Space for fixed button
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // --- Fixed Bottom Summary and Button ---
            Builder(
              builder: (context) {
                final safeBottom = MediaQuery.of(context).viewPadding.bottom;
                return Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + (safeBottom > 0 ? safeBottom : 8),
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border(top: BorderSide(color: palette.border)),
                    boxShadow: [
                      const BoxShadow(color: Color(0x1A000000), blurRadius: 12),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 360;
                      final currentPayableAmount = selectedPaymentOption == "full"
                          ? finalAmount
                          : selectedPaymentOption == "partial"
                          ? advanceAmount
                          : 0.0;

                      final totalWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Grand Total",
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.textMuted,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "\u20B9${finalAmount.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: palette.accent,
                              ),
                            ),
                          ),
                          if (selectedPaymentOption == "partial") ...[
                            const SizedBox(height: 4),
                            Text(
                              "Pay now: \u20B9${currentPayableAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Remaining COD: \u20B9${remainingAmount.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ],
                      );

                      final button = SizedBox(
                        height: 50,
                        width: compact ? double.infinity : null,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: palette.onAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isLoading ? null : startPayment,
                          child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: palette.onAccent,
                                        strokeWidth: 2.4,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "PROCESSING...",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: palette.onAccent,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  selectedPaymentOption == "snapmint"
                                      ? "PROCEED"
                                      : selectedPaymentOption == "cod"
                                      ? "PLACE ORDER"
                                      : selectedPaymentOption == "partial"
                                      ? "PAY ADVANCE \u20B9${currentPayableAmount.toStringAsFixed(0)}"
                                      : "PAY NOW",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: palette.onAccent,
                                  ),
                                ),
                        ),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            totalWidget,
                            const SizedBox(height: 10),
                            button,
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: totalWidget),
                              const SizedBox(width: 10),
                              Expanded(child: button),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
            if (_showProcessingOverlay)
              _buildProcessingOverlay(
                isSnapmint: selectedPaymentOption == "snapmint",
              ),
          ],
        ),
      ),
    );
  }
}
