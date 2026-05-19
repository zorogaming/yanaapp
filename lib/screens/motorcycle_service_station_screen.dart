import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/motorcycle_service_booking_service.dart';
import '../services/data_manager.dart';
import '../services/motorcycle_service_api.dart';
import '../theme/app_theme.dart';

class MotorcycleServiceStationScreen extends StatefulWidget {
  const MotorcycleServiceStationScreen({super.key});

  @override
  State<MotorcycleServiceStationScreen> createState() =>
      _MotorcycleServiceStationScreenState();
}

class _MotorcycleServiceStationScreenState
    extends State<MotorcycleServiceStationScreen> {
  static const String _customBikeOptionsKey =
      "motorcycle_service_custom_bikes_v1";

  final DataManager _dataManager = DataManager();
  final AccountService _accountService = AccountService();
  final MotorcycleServiceApi _motorcycleServiceApi = MotorcycleServiceApi();
  final MotorcycleServiceBookingService _bookingService =
      MotorcycleServiceBookingService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualBikeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _loading = true;
  List<String> _bikeOptions = const <String>[];
  String _selectedBike = "";
  _ServicePackage? _selectedPackage;
  DateTime? _selectedDate;
  String _selectedTimeSlot = _timeSlots.first;
  String _servicePriority = "normal";
  bool _pickupAndDrop = false;
  bool _fetchingEstimate = false;
  MotorcycleServiceAiEstimate? _aiEstimate;
  String _estimateStatus = "";
  String _selectedAirFilterOptionId = "clean";
  bool _pickupDropEnabled = false;
  String _pickupDropCity = "Jaipur";

  static const List<String> _timeSlots = <String>[
    "09:00 AM - 11:00 AM",
    "11:00 AM - 01:00 PM",
    "02:00 PM - 04:00 PM",
    "04:00 PM - 06:00 PM",
    "06:00 PM - 08:00 PM",
  ];

  static final List<_ServicePackage> _packages = <_ServicePackage>[
    _ServicePackage(
      id: "essential",
      title: "Essential Care Service",
      accent: const Color(0xFFFFA726),
      tagline: "Perfect for regular maintenance",
      serviceCharge: 699,
      features: const <String>[
        "Motul Engine Oil (as per bike requirement)",
        "1 Engine Flushing",
        "Oil Filter Replacement (New)",
        "Air Filter Replacement (New)",
        "Petrol Cleaner (Standard)",
        "Basic Lubrication (chain, cables, joints)",
        "Bike Wash Included",
        "Brake Check Included",
        "Nut-Bolt Tightening",
      ],
    ),
    _ServicePackage(
      id: "performance",
      title: "Performance Care Service",
      accent: const Color(0xFF38BDF8),
      tagline: "Enhanced performance & smoother riding",
      serviceCharge: 1199,
      features: const <String>[
        "AMS Oil Engine Oil",
        "2 Engine Flushing (Deep Cleaning)",
        "Oil Filter Replacement",
        "Air Filter Cleaning",
        "Liqui Moly Petrol Cleaner",
        "Spark Plug Cleaning",
        "Bike Wash Included",
        "Brake Check Included",
        "Nut-Bolt Tightening",
      ],
    ),
    _ServicePackage(
      id: "ultimate",
      title: "Ultimate Care Service",
      accent: const Color(0xFFEF4444),
      tagline: "Complete bike care with smart diagnostics",
      serviceCharge: 1899,
      features: const <String>[
        "All features of Performance Care Service",
        "Full Bike Computer Diagnosis (Scanner-based)",
        "3 Months Free Diagnostic Support",
        "Chain Cleaning & Chain Lubrication",
        "Priority Service",
        "Premium Foam Wash + Finish",
        "Brake Check Included",
        "Nut-Bolt Tightening",
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualBikeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final bikeOptions = await _dataManager.getBikeGarageOptions();
    final selectedBike = await _dataManager.getSelectedBike() ?? "";
    final customer = await _accountService.fetchCustomer();
    final billing = (customer["billing"] as Map<String, dynamic>?) ?? {};
    final customBikes = await _loadCustomBikes();
    final packageCharges = await _bookingService.getPackageCharges();
    final serviceConfig = await _bookingService.getServiceConfig();

    final addressParts = <String>[
      (billing["address_1"] ?? "").toString().trim(),
      (billing["city"] ?? "").toString().trim(),
      (billing["state"] ?? "").toString().trim(),
      (billing["postcode"] ?? "").toString().trim(),
    ].where((part) => part.isNotEmpty).toList();

    final merged = <String>[
      ...customBikes,
      ...bikeOptions,
    ];
    final seen = <String>{};
    final normalized = merged.where((item) {
      final key = item.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    if (!mounted) return;
    setState(() {
      _bikeOptions = normalized;
      _selectedBike = selectedBike;
      _selectedPackage = _packages.first.copyWith(
        serviceCharge: packageCharges[_packages.first.id] ?? _packages.first.serviceCharge,
      );
      for (var i = 0; i < _packages.length; i++) {
        _packages[i] = _packages[i].copyWith(
          serviceCharge: packageCharges[_packages[i].id] ?? _packages[i].serviceCharge,
        );
      }
      _pickupDropEnabled = serviceConfig["pickup_drop_enabled"] == true;
      _pickupDropCity = (serviceConfig["pickup_drop_city"] ?? "Jaipur")
          .toString()
          .trim();
      _addressController.text = addressParts.join(", ");
      _loading = false;
    });
    if (selectedBike.trim().isNotEmpty) {
      await _refreshAiEstimate(selectedBike);
    }
  }

  Future<List<String>> _loadCustomBikes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_customBikeOptionsKey) ?? "").trim();
    if (raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const <String>[];
  }

  Future<void> _saveCustomBike(String bikeName) async {
    final prefs = await SharedPreferences.getInstance();
    final customBikes = await _loadCustomBikes();
    final merged = <String>[bikeName.trim(), ...customBikes];
    final seen = <String>{};
    final deduped = merged.where((item) {
      final key = item.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).take(40).toList();
    await prefs.setString(_customBikeOptionsKey, jsonEncode(deduped));
  }

  Future<void> _selectBike(String bikeName) async {
    await _dataManager.setSelectedBike(bikeName);
    if (!mounted) return;
    setState(() {
      _selectedBike = bikeName;
    });
    await _refreshAiEstimate(bikeName);
  }

  Future<void> _addManualBike() async {
    final bikeName = _manualBikeController.text.trim();
    if (bikeName.isEmpty) return;
    await _saveCustomBike(bikeName);
    await _dataManager.setSelectedBike(bikeName);
    final custom = await _loadCustomBikes();
    if (!mounted) return;
    setState(() {
      _selectedBike = bikeName;
      _bikeOptions = <String>[
        ...custom,
        ..._bikeOptions,
      ].toSet().toList();
      _manualBikeController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bike model saved in memory")),
    );
    await _refreshAiEstimate(bikeName);
  }

  void _selectServicePackage(_ServicePackage servicePackage) {
    setState(() {
      _selectedPackage = servicePackage;
    });
  }

  Future<void> _refreshAiEstimate(String bikeName) async {
    final normalized = bikeName.trim();
    if (normalized.isEmpty) return;

    if (mounted) {
      setState(() {
        _fetchingEstimate = true;
        _aiEstimate = null;
        _estimateStatus = "Fetching AI estimate...";
      });
    }

    final aiEstimate = await _motorcycleServiceApi.fetchEstimate(
      bikeModel: normalized,
    );
    final apiError = _motorcycleServiceApi.lastErrorMessage?.trim() ?? "";

    if (!mounted) return;
    setState(() {
      _aiEstimate = aiEstimate;
      _fetchingEstimate = false;
      _estimateStatus = aiEstimate == null
          ? (apiError.isEmpty
              ? "AI estimate unavailable"
              : "AI estimate unavailable: $apiError")
          : "AI estimate ready for $normalized";
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Select date";
    final day = date.day.toString().padLeft(2, "0");
    final month = date.month.toString().padLeft(2, "0");
    return "$day/$month/${date.year}";
  }

  bool get _isPickupDropAvailableForAddress {
    if (!_pickupDropEnabled) return false;
    final city = _pickupDropCity.trim().toLowerCase();
    final address = _addressController.text.trim().toLowerCase();
    if (city.isEmpty) return false;
    return address.contains(city);
  }

  Future<void> _continueToEstimate() async {
    if (_selectedBike.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or add a bike model first.")),
      );
      return;
    }
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a service package.")),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an appointment date.")),
      );
      return;
    }
    if (_pickupAndDrop && _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the pickup address.")),
      );
      return;
    }
    if (_pickupAndDrop && !_isPickupDropAvailableForAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Pickup & Drop is currently available only for $_pickupDropCity addresses.",
          ),
        ),
      );
      return;
    }

    if (_aiEstimate == null) {
      if (!_fetchingEstimate) {
        await _refreshAiEstimate(_selectedBike);
      }
      if (!mounted) return;
      if (_aiEstimate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "AI estimate is not available yet. Please retry.",
            ),
          ),
        );
        return;
      }
    }

    final aiEstimate = _aiEstimate;
    if (aiEstimate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("AI estimate missing. Please retry once."),
        ),
      );
      return;
    }

    final quote = _buildQuote(
      bikeModel: _selectedBike,
      servicePackage: _selectedPackage!,
      servicePriority: _servicePriority,
      pickupAndDrop: _pickupAndDrop,
      aiEstimate: aiEstimate,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MotorcycleServiceEstimateScreen(
          draft: _ServiceBookingDraft(
            bikeModel: _selectedBike,
            servicePackage: _selectedPackage!,
            quote: quote,
            serviceDate: _selectedDate!,
            timeSlot: _selectedTimeSlot,
            servicePriority: _servicePriority,
            pickupAndDrop: _pickupAndDrop,
            address: _addressController.text.trim(),
          ),
        ),
      ),
    );
  }

  _ServiceQuote _buildQuote({
    required String bikeModel,
    required _ServicePackage servicePackage,
    required String servicePriority,
    required bool pickupAndDrop,
    required MotorcycleServiceAiEstimate aiEstimate,
  }) {
    final estimate = _buildMarketEstimate(bikeModel, aiEstimate: aiEstimate);
    final airFilterOptions = _buildAirFilterOptions(estimate);
    final selectedAirFilter = airFilterOptions.firstWhere(
      (option) => option.id == _selectedAirFilterOptionId,
      orElse: () => airFilterOptions.first,
    );
    final lineItems = <_QuoteLineItem>[];

    lineItems.add(
      _QuoteLineItem(
        title: "Service charge",
        subtitle: servicePackage.title,
        amount: servicePackage.serviceCharge,
      ),
    );

    if (servicePackage.id == "essential") {
      lineItems.add(
        _QuoteLineItem(
          title: "Oil cost",
          subtitle:
              "Motul Engine Oil (${estimate.engineOilLiters.toStringAsFixed(1)}L need | ${estimate.motulOilPacks} x 1L pack)",
          amount: estimate.motulOilCost,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Engine flushing",
          subtitle: "1 cycle",
          amount: 200,
        ),
      );
      lineItems.add(
        _QuoteLineItem(
          title: "Oil filter replacement",
          subtitle: "AI market estimate",
          amount: estimate.oilFilterPrice,
        ),
      );
      lineItems.add(
        _QuoteLineItem(
          title: selectedAirFilter.isCleaning
              ? "Air filter cleaning"
              : "Air filter replacement",
          subtitle: selectedAirFilter.description,
          amount: selectedAirFilter.price,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Petrol cleaner",
          subtitle: "Standard",
          amount: 200,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Bike wash",
          subtitle: "Included",
          amount: 100,
        ),
      );
    } else if (servicePackage.id == "performance") {
      lineItems.add(
        _QuoteLineItem(
          title: "Oil cost",
          subtitle:
              "AMS Engine Oil (${estimate.engineOilLiters.toStringAsFixed(1)}L need | ${estimate.amsOilPacks} x 1L pack)",
          amount: estimate.amsOilCost,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Engine flushing",
          subtitle: "2 deep cleaning cycles",
          amount: 400,
        ),
      );
      lineItems.add(
        _QuoteLineItem(
          title: "Oil filter replacement",
          subtitle: "AI market estimate",
          amount: estimate.oilFilterPrice,
        ),
      );
      lineItems.add(
        _QuoteLineItem(
          title: selectedAirFilter.isCleaning
              ? "Air filter cleaning"
              : "Air filter replacement",
          subtitle: selectedAirFilter.description,
          amount: selectedAirFilter.price,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Petrol cleaner",
          subtitle: "Liqui Moly",
          amount: 350,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Spark plug cleaning",
          subtitle: "Performance tune",
          amount: 80,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Bike wash",
          subtitle: "Included",
          amount: 100,
        ),
      );
    } else {
      lineItems.add(
        _QuoteLineItem(
          title: "Oil cost",
          subtitle:
              "AMS Engine Oil (${estimate.engineOilLiters.toStringAsFixed(1)}L need | ${estimate.amsOilPacks} x 1L pack)",
          amount: estimate.amsOilCost,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Engine flushing",
          subtitle: "2 deep cleaning cycles",
          amount: 400,
        ),
      );
      lineItems.add(
        _QuoteLineItem(
          title: "Oil filter replacement",
          subtitle: "AI market estimate",
          amount: estimate.oilFilterPrice,
        ),
      );
      lineItems.add(
        _QuoteLineItem(
          title: selectedAirFilter.isCleaning
              ? "Air filter cleaning"
              : "Air filter replacement",
          subtitle: selectedAirFilter.description,
          amount: selectedAirFilter.price,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Petrol cleaner",
          subtitle: "Liqui Moly",
          amount: 350,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Spark plug cleaning",
          subtitle: "Performance tune",
          amount: 80,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Diagnosis",
          subtitle: "Scanner based",
          amount: 499,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Chain clean + lubrication",
          subtitle: "Premium drivetrain care",
          amount: 180,
        ),
      );
      lineItems.add(
        const _QuoteLineItem(
          title: "Premium foam wash",
          subtitle: "Finish included",
          amount: 250,
        ),
      );
    }

    if (servicePriority == "urgent") {
      lineItems.add(
        const _QuoteLineItem(
          title: "Urgent slot charge",
          subtitle: "Priority service",
          amount: 250,
        ),
      );
    }

    if (pickupAndDrop) {
      lineItems.add(
        const _QuoteLineItem(
          title: "Pickup & drop",
          subtitle: "Doorstep handling",
          amount: 149,
        ),
      );
    }

    final subtotal =
        lineItems.fold<double>(0, (sum, item) => sum + item.amount);
    const discount = 200.0;

    return _ServiceQuote(
      lineItems: lineItems,
      marketEstimate: estimate,
      airFilterOption: selectedAirFilter,
      subtotal: subtotal,
      discount: discount,
      total: (subtotal - discount).clamp(0, double.infinity),
    );
  }

  _MarketEstimate _buildMarketEstimate(
    String bikeModel, {
    MotorcycleServiceAiEstimate? aiEstimate,
  }) {
    final lower = bikeModel.toLowerCase();
    final cc = _extractEngineCc(lower);
    final fallbackLiters = _estimateFallbackOilLiters(lower, cc);

    final fallbackOilFilter = cc <= 125
        ? 140.0
        : cc <= 160
            ? 180.0
            : cc <= 220
                ? 220.0
                : cc <= 350
                    ? 320.0
                    : 450.0;

    final fallbackAirFilter = cc <= 125
        ? 190.0
        : cc <= 160
            ? 240.0
            : cc <= 220
                ? 290.0
                : cc <= 350
                    ? 390.0
                    : 560.0;

    final liters = aiEstimate != null && aiEstimate.oilCapacityLitres > 0
        ? aiEstimate.oilCapacityLitres
        : fallbackLiters;
    final oilFilter = aiEstimate != null && aiEstimate.oilFilterPrice > 0
        ? aiEstimate.oilFilterPrice
        : fallbackOilFilter;
    final airFilter = aiEstimate != null && aiEstimate.airFilterPrice > 0
        ? aiEstimate.airFilterPrice
        : fallbackAirFilter;
    final motulOilPacks = liters.ceil();
    final amsOilPacks = liters.ceil();

    return _MarketEstimate(
      engineCc: cc,
      engineOilLiters: liters,
      oilFilterPrice: oilFilter,
      airFilterPrice: airFilter,
      motulOilPacks: motulOilPacks,
      amsOilPacks: amsOilPacks,
      motulOilCost: motulOilPacks * 950,
      amsOilCost: amsOilPacks * 1250,
      confidence: aiEstimate?.confidence ?? "fallback",
      notes: aiEstimate?.notes ?? "Showing local estimate because AI API data is unavailable.",
      sources: aiEstimate?.sources ?? const <String>[],
      sourceLabel: aiEstimate == null ? "Local fallback estimate" : "AI web estimate",
    );
  }

  int _extractEngineCc(String bikeModel) {
    const knownCc = <String, int>{
      "splendor": 100,
      "shine": 125,
      "sp 125": 125,
      "apache 160": 160,
      "apache rtr 160": 160,
      "pulsar 150": 150,
      "pulsar 180": 180,
      "pulsar ns200": 200,
      "r15": 155,
      "mt 15": 155,
      "fzs": 149,
      "fz": 149,
      "duke 200": 200,
      "duke 250": 250,
      "classic 350": 349,
      "hunter 350": 349,
      "meteor 350": 349,
      "bullet 350": 346,
      "himalayan": 411,
      "dominar 400": 373,
      "z900": 900,
      "kawasaki z900": 900,
    };

    for (final entry in knownCc.entries) {
      if (bikeModel.contains(entry.key)) return entry.value;
    }

    final match = RegExp(r"(\d{2,4})").firstMatch(bikeModel);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed >= 70 && parsed <= 1300) {
        return parsed;
      }
    }

    return 150;
  }

  double _estimateFallbackOilLiters(String bikeModel, int cc) {
    const knownOilLiters = <String, double>{
      "r15": 1.0,
      "mt 15": 1.05,
      "classic 350": 2.0,
      "hunter 350": 1.7,
      "meteor 350": 1.7,
      "himalayan": 2.0,
      "dominar 400": 1.9,
      "z900": 3.7,
      "kawasaki z900": 3.7,
    };

    for (final entry in knownOilLiters.entries) {
      if (bikeModel.contains(entry.key)) return entry.value;
    }

    if (cc <= 125) return 0.9;
    if (cc <= 160) return 1.0;
    if (cc <= 220) return 1.2;
    if (cc <= 350) return 1.5;
    if (cc <= 500) return 1.8;
    if (cc <= 650) return 2.4;
    if (cc <= 800) return 3.0;
    if (cc <= 1000) return 3.7;
    return 4.2;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text("Motorcycle Service Station"),
        backgroundColor: const Color(0xFF151826),
        actions: [
          IconButton(
            tooltip: "My Bookings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MotorcycleServiceBookingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          FutureBuilder<bool>(
            future: AuthService().isPrivilegedAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                tooltip: "Admin Bookings",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MotorcycleServiceAdminScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings_rounded),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Which bike model do you have?",
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Select from the list or add the model manually. The selected bike model will be saved for future use.",
                        style: TextStyle(
                          color: palette.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: palette.textPrimary),
                        decoration: _inputDecoration(
                          hintText: "Search bike model",
                          prefixIcon: Icons.search_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: const Color(0xFF1C1F2E),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _bikeOptions.contains(_selectedBike) &&
                                  _selectedBike.trim().isNotEmpty
                              ? _selectedBike
                              : null,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1C1F2E),
                          decoration: _inputDecoration(
                            hintText: "Select bike from full list",
                            prefixIcon: Icons.two_wheeler_rounded,
                          ),
                          items: _bikeOptions
                              .where((bike) {
                                final query =
                                    _searchController.text.trim().toLowerCase();
                                if (query.isEmpty) return true;
                                return bike.toLowerCase().contains(query);
                              })
                              .map(
                                (bike) => DropdownMenuItem<String>(
                                  value: bike,
                                  child: Text(
                                    bike,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            await _selectBike(value);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _manualBikeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hintText: "Enter bike model manually",
                          prefixIcon: Icons.edit_rounded,
                          suffix: TextButton(
                            onPressed: _addManualBike,
                            child: const Text("Save"),
                          ),
                        ),
                      ),
                      if (_selectedBike.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF172554),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.two_wheeler_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Saved bike model: $_selectedBike",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _estimateStatus.isEmpty
                              ? "AI estimate will load for this bike model."
                              : _estimateStatus,
                          style: TextStyle(
                            color: _aiEstimate == null
                                ? Colors.white60
                                : const Color(0xFF86EFAC),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_fetchingEstimate)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white70,
                                  ),
                                ),
                              ),
                            if (_fetchingEstimate) const SizedBox(width: 10),
                            if (!_fetchingEstimate)
                              TextButton.icon(
                                onPressed: () => _refreshAiEstimate(_selectedBike),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text("Retry"),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF7DD3FC),
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Choose Service Package",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tap any card or use the button on the card to select your package.",
                  style: TextStyle(color: Colors.white60, height: 1.4),
                ),
                const SizedBox(height: 10),
                ..._packages.map((servicePackage) {
                  final selected = _selectedPackage?.id == servicePackage.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildServiceCard(servicePackage, selected),
                  );
                }),
                const SizedBox(height: 2),
                if (_selectedBike.trim().isNotEmpty) ...[
                  _buildAirFilterOptionsCard(),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 4),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Book Appointment",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF11131F),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTimeSlot,
                        dropdownColor: const Color(0xFF1C1F2E),
                        decoration: _inputDecoration(
                          hintText: "Select time slot",
                          prefixIcon: Icons.access_time_rounded,
                        ),
                        items: _timeSlots
                            .map(
                              (slot) => DropdownMenuItem<String>(
                                value: slot,
                                child: Text(
                                  slot,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedTimeSlot = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _choiceTile(
                              title: "Normal",
                              selected: _servicePriority == "normal",
                              onTap: () {
                                setState(() {
                                  _servicePriority = "normal";
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _choiceTile(
                              title: "Urgent",
                              selected: _servicePriority == "urgent",
                              onTap: () {
                                setState(() {
                                  _servicePriority = "urgent";
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Pickup & Drop Option",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Switch(
                            value: _pickupAndDrop,
                            onChanged: !_pickupDropEnabled
                                ? null
                                : (value) {
                              setState(() {
                                  if (value && !_isPickupDropAvailableForAddress) {
                                    _pickupAndDrop = false;
                                  } else {
                                    _pickupAndDrop = value;
                                  }
                              });
                                },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        !_pickupDropEnabled
                            ? "Pickup & Drop is currently disabled by admin."
                            : _pickupAndDrop
                                ? "Extra charge: Rs 149. Available only for $_pickupDropCity addresses."
                                : "Pickup & Drop is available only for $_pickupDropCity addresses approved by admin.",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          hintText: "Address auto fill / edit here",
                          prefixIcon: Icons.location_on_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _fetchingEstimate ? null : _continueToEstimate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A36),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _fetchingEstimate
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            "Continue To Price Estimate",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildServiceCard(_ServicePackage servicePackage, bool selected) {
    return InkWell(
      onTap: () => _selectServicePackage(servicePackage),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F2E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? servicePackage.accent : Colors.white10,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: servicePackage.accent.withOpacity(selected ? 0.22 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    servicePackage.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: servicePackage.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "Selected",
                      style: TextStyle(
                        color: servicePackage.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              servicePackage.tagline,
              style: TextStyle(
                color: servicePackage.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ...servicePackage.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: servicePackage.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _selectServicePackage(servicePackage),
                icon: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                ),
                label: Text(selected ? "Selected Package" : "Select Package"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected
                      ? servicePackage.accent
                      : servicePackage.accent.withOpacity(0.16),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: servicePackage.accent.withOpacity(
                        selected ? 0.0 : 0.45,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirFilterOptionsCard() {
    final aiEstimate = _aiEstimate;
    final estimate = aiEstimate == null
        ? null
        : _buildMarketEstimate(_selectedBike, aiEstimate: aiEstimate);
    final options = estimate == null
        ? const <_AirFilterOption>[]
        : _buildAirFilterOptions(estimate);

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Air Filter Option",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "If the bike already has a lifetime washable filter, cleaning stays free. A new filter is charged only when the customer selects a replacement option.",
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_fetchingEstimate)
            _buildEstimatePreviewSkeleton()
          else if (options.isEmpty)
            const Text(
              "Filter options will appear here after the AI estimate is loaded.",
              style: TextStyle(color: Colors.white60),
            )
          else
            ...options.map(
              (option) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: option.id == _selectedAirFilterOptionId
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFF11131F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: option.id == _selectedAirFilterOptionId
                        ? const Color(0xFFFF5A36)
                        : Colors.white10,
                  ),
                ),
                child: RadioListTile<String>(
                  value: option.id,
                  groupValue: _selectedAirFilterOptionId,
                  activeColor: const Color(0xFFFF5A36),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedAirFilterOptionId = value;
                    });
                  },
                  title: Text(
                    option.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    option.description,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  secondary: Text(
                    option.isCleaning
                        ? "Free"
                        : "Rs ${option.price.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Color(0xFFFFB36B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _choiceTile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF5A36) : const Color(0xFF11131F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : Colors.white10),
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  List<_AirFilterOption> _buildAirFilterOptions(_MarketEstimate estimate) {
    final basePrice = estimate.airFilterPrice;
    final oemPrice = basePrice <= 0 ? 0.0 : basePrice;
    final premiumPrice = basePrice <= 0 ? 0.0 : (basePrice * 1.28);

    return <_AirFilterOption>[
      const _AirFilterOption(
        id: "clean",
        title: "Clean Existing Air Filter",
        description: "Lifetime / reusable air filter cleaning service included",
        price: 0,
        isCleaning: true,
      ),
      _AirFilterOption(
        id: "oem_new",
        title: "New OEM Style Air Filter",
        description: "Standard replacement filter you can buy for this bike",
        price: oemPrice,
      ),
      _AirFilterOption(
        id: "premium_new",
        title: "New Premium Air Filter",
        description: "Premium / high-flow replacement option",
        price: premiumPrice,
      ),
    ];
  }

  Widget _buildEstimatePreviewSkeleton() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 0.9),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildSkeletonLine(widthFactor: 0.6, opacity: value),
              const SizedBox(height: 10),
              _buildSkeletonLine(widthFactor: 1, opacity: value * 0.85),
              const SizedBox(height: 8),
              _buildSkeletonLine(widthFactor: 0.88, opacity: value * 0.8),
              const SizedBox(height: 8),
              _buildSkeletonLine(widthFactor: 0.82, opacity: value * 0.75),
              const SizedBox(height: 8),
              _buildSkeletonLine(widthFactor: 0.72, opacity: value * 0.7),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLine({
    required double widthFactor,
    required double opacity,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity.clamp(0.15, 0.9)),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(prefixIcon, color: Colors.white70),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF11131F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5A36)),
      ),
    );
  }
}

class _MotorcycleServiceEstimateScreen extends StatefulWidget {
  const _MotorcycleServiceEstimateScreen({
    super.key,
    required this.draft,
  });

  final _ServiceBookingDraft draft;

  @override
  State<_MotorcycleServiceEstimateScreen> createState() =>
      _MotorcycleServiceEstimateScreenState();
}

class _MotorcycleServiceEstimateScreenState
    extends State<_MotorcycleServiceEstimateScreen> {
  static const String _workshopPhone = "9166666554";
  static const String _workshopAddress =
      "Shop no. 5, Hanuman Market, 200ft, Airport Rd, near 7no choraha, near Mahima Paradise, Ravindra Nagar - A, Jagatpura, Jaipur, Rajasthan 302033";
  final MotorcycleServiceBookingService _bookingService =
      MotorcycleServiceBookingService();
  final AccountService _accountService = AccountService();

  String _paymentMethod = "workshop";
  bool _submitting = false;

  Future<void> _confirmBooking() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
    });

    final customer = await _accountService.fetchCustomer();
    final billing = (customer["billing"] as Map<String, dynamic>?) ?? {};
    final bookingId = "MSS-${DateTime.now().millisecondsSinceEpoch}";
    final booking = <String, dynamic>{
      "booking_id": bookingId,
      "bike_model": widget.draft.bikeModel,
      "package_id": widget.draft.servicePackage.id,
      "package_title": widget.draft.servicePackage.title,
      "service_date": widget.draft.serviceDate.toIso8601String(),
      "time_slot": widget.draft.timeSlot,
      "service_priority": widget.draft.servicePriority,
      "pickup_and_drop": widget.draft.pickupAndDrop,
      "address": widget.draft.address,
      "payment_method": _paymentMethod,
      "subtotal": widget.draft.quote.subtotal,
      "discount": widget.draft.quote.discount,
      "total": widget.draft.quote.total,
      "payment_note":
          "Pay at workshop only. Diagnosis charge refundable if diagnosis cannot be completed.",
      "customer_name":
          "${(billing["first_name"] ?? "").toString().trim()} ${(billing["last_name"] ?? "").toString().trim()}".trim(),
      "customer_phone": (billing["phone"] ?? "").toString().trim(),
      "customer_email": (billing["email"] ?? customer["email"] ?? "")
          .toString()
          .trim(),
      "workshop_address": _workshopAddress,
      "workshop_phone": _workshopPhone,
      "completed_service_date": "",
      "service_done_km": "",
      "next_service_due_km": "",
      "air_filter_option": widget.draft.quote.airFilterOption.title,
      "quotation_items": widget.draft.quote.lineItems
          .map(
            (item) => <String, dynamic>{
              "title": item.title,
              "subtitle": item.subtitle,
              "amount": item.amount,
            },
          )
          .toList(),
      "status": "Hold",
      "created_at": DateTime.now().toIso8601String(),
    };
    await _bookingService.saveBooking(booking);

    if (!mounted) return;
    setState(() {
      _submitting = false;
    });

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1F2E),
          title: const Text(
            "Booking Saved",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            "Booking ID: $bookingId\nPayment mode: ${_paymentLabel(_paymentMethod)}\nFinal total: ${_money(widget.draft.quote.total)}\n\nWorkshop address:\n$_workshopAddress\nPhone / WhatsApp / Call: $_workshopPhone",
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _sendOnWhatsApp(booking);
              },
              child: const Text("Send On WhatsApp"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _sendOnWhatsApp(Map<String, dynamic> booking) async {
    final phone = "91$_workshopPhone";
    final message = Uri.encodeComponent(
      "Motorcycle Service Booking\n"
      "Booking ID: ${booking["booking_id"]}\n"
      "Bike: ${booking["bike_model"]}\n"
      "Package: ${booking["package_title"]}\n"
      "Date: ${_dateLabel(widget.draft.serviceDate)}\n"
      "Time: ${widget.draft.timeSlot}\n"
      "Priority: ${widget.draft.servicePriority}\n"
      "Pickup & Drop: ${widget.draft.pickupAndDrop ? "Yes" : "No"}\n"
      "Address: ${widget.draft.address}\n"
      "Customer: ${booking["customer_name"]}\n"
      "Phone: ${booking["customer_phone"]}\n"
      "Air Filter: ${widget.draft.quote.airFilterOption.title}\n"
      "Final Total: ${_money(widget.draft.quote.total)}\n"
      "Payment: Pay at workshop\n"
      "Workshop Address: $_workshopAddress\n"
      "Workshop Phone: $_workshopPhone"
    );
    final uri = Uri.parse("https://wa.me/$phone?text=$message");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.draft.quote;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text("Price Estimate"),
        backgroundColor: const Color(0xFF151826),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.draft.servicePackage.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Bike: ${widget.draft.bikeModel}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  "Appointment: ${_dateLabel(widget.draft.serviceDate)} | ${widget.draft.timeSlot}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  "Priority: ${widget.draft.servicePriority == "urgent" ? "Urgent" : "Normal"}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  "Pickup & Drop: ${widget.draft.pickupAndDrop ? "Yes" : "No"}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  "Air filter: ${widget.draft.quote.airFilterOption.title}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Workshop Address",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  _workshopAddress,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Phone / WhatsApp / Call: 9166666554",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Quotation",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "The final quotation below includes the selected service package and any optional items chosen for this bike.",
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...quote.lineItems.map((item) => _quoteRow(item)),
                const Divider(color: Colors.white12, height: 24),
                _infoRow("Service + add-ons total", _money(quote.subtotal)),
                _infoRow("Discount (Rs 200 app offer)", "-${_money(quote.discount)}"),
                const SizedBox(height: 8),
                _infoRow(
                  "Final total",
                  _money(quote.total),
                  valueColor: const Color(0xFFFFB36B),
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Payment",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _paymentTile(
                  value: "workshop",
                  title: "Pay At Workshop",
                  subtitle:
                      "Diagnosis is paid only at the workshop. If the diagnosis cannot be completed, the diagnosis amount will be refunded.",
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await _sendOnWhatsApp({
                      "booking_id": "Preview",
                      "bike_model": widget.draft.bikeModel,
                      "package_title": widget.draft.servicePackage.title,
                      "customer_name": "",
                      "customer_phone": "",
                    });
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text("Send Details On WhatsApp"),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4ADE80),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A36),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _submitting ? "Saving..." : "Confirm Booking",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _quoteRow(_QuoteLineItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.subtitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _money(item.amount),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _paymentMethod == value;
    return InkWell(
      onTap: () {
        setState(() {
          _paymentMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF5A36) : const Color(0xFF11131F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : Colors.white10),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _paymentMethod,
              onChanged: (newValue) {
                if (newValue == null) return;
                setState(() {
                  _paymentMethod = newValue;
                });
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Color valueColor = Colors.white,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) => "Rs ${value.toStringAsFixed(0)}";

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, "0");
    final month = date.month.toString().padLeft(2, "0");
    return "$day/$month/${date.year}";
  }

  String _paymentLabel(String method) {
    switch (method) {
      case "workshop":
        return "Pay at workshop";
      case "razorpay":
        return "Razorpay";
      case "cod":
        return "Cash on delivery";
      default:
        return "UPI";
    }
  }
}

class _ServicePackage {
  const _ServicePackage({
    required this.id,
    required this.title,
    required this.accent,
    required this.tagline,
    required this.serviceCharge,
    required this.features,
  });

  final String id;
  final String title;
  final Color accent;
  final String tagline;
  final double serviceCharge;
  final List<String> features;

  _ServicePackage copyWith({
    String? id,
    String? title,
    Color? accent,
    String? tagline,
    double? serviceCharge,
    List<String>? features,
  }) {
    return _ServicePackage(
      id: id ?? this.id,
      title: title ?? this.title,
      accent: accent ?? this.accent,
      tagline: tagline ?? this.tagline,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      features: features ?? this.features,
    );
  }
}

class _MarketEstimate {
  const _MarketEstimate({
    required this.engineCc,
    required this.engineOilLiters,
    required this.oilFilterPrice,
    required this.airFilterPrice,
    required this.motulOilPacks,
    required this.amsOilPacks,
    required this.motulOilCost,
    required this.amsOilCost,
    required this.confidence,
    required this.notes,
    required this.sources,
    required this.sourceLabel,
  });

  final int engineCc;
  final double engineOilLiters;
  final double oilFilterPrice;
  final double airFilterPrice;
  final int motulOilPacks;
  final int amsOilPacks;
  final double motulOilCost;
  final double amsOilCost;
  final String confidence;
  final String notes;
  final List<String> sources;
  final String sourceLabel;
}

class _QuoteLineItem {
  const _QuoteLineItem({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final double amount;
}

class _AirFilterOption {
  const _AirFilterOption({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.isCleaning = false,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final bool isCleaning;
}

class _ServiceQuote {
  const _ServiceQuote({
    required this.lineItems,
    required this.marketEstimate,
    required this.airFilterOption,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final List<_QuoteLineItem> lineItems;
  final _MarketEstimate marketEstimate;
  final _AirFilterOption airFilterOption;
  final double subtotal;
  final double discount;
  final double total;
}

class _ServiceBookingDraft {
  const _ServiceBookingDraft({
    required this.bikeModel,
    required this.servicePackage,
    required this.quote,
    required this.serviceDate,
    required this.timeSlot,
    required this.servicePriority,
    required this.pickupAndDrop,
    required this.address,
  });

  final String bikeModel;
  final _ServicePackage servicePackage;
  final _ServiceQuote quote;
  final DateTime serviceDate;
  final String timeSlot;
  final String servicePriority;
  final bool pickupAndDrop;
  final String address;
}

class MotorcycleServiceBookingsScreen extends StatefulWidget {
  const MotorcycleServiceBookingsScreen({super.key});

  @override
  State<MotorcycleServiceBookingsScreen> createState() =>
      _MotorcycleServiceBookingsScreenState();
}

class _MotorcycleServiceBookingsScreenState
    extends State<MotorcycleServiceBookingsScreen> {
  final MotorcycleServiceBookingService _bookingService =
      MotorcycleServiceBookingService();

  List<Map<String, dynamic>> _bookings = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bookings = await _bookingService.getBookings();
    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: const Color(0xFF151826),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(
                  child: Text(
                    "No service bookings yet.",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1F2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (booking["package_title"] ?? "-").toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _bookingInfo("Booking ID", (booking["booking_id"] ?? "-").toString()),
                          _bookingInfo("Bike", (booking["bike_model"] ?? "-").toString()),
                          _bookingInfo("Date", _formatBookingDate((booking["service_date"] ?? "").toString())),
                          _bookingInfo("Time", (booking["time_slot"] ?? "-").toString()),
                          _bookingInfo("Address", (booking["address"] ?? "-").toString()),
                          _bookingInfo(
                            "Workshop address",
                            (booking["workshop_address"] ??
                                    "Shop no. 5, Hanuman Market, 200ft, Airport Rd, near 7no choraha, near Mahima Paradise, Ravindra Nagar - A, Jagatpura, Jaipur, Rajasthan 302033")
                                .toString(),
                          ),
                          _bookingInfo(
                            "Workshop phone",
                            (booking["workshop_phone"] ?? "9166666554")
                                .toString(),
                          ),
                          _bookingInfo(
                            "Service done on",
                            _serviceRecordValue(
                              booking["completed_service_date"],
                              formatter: _formatBookingDate,
                            ),
                          ),
                          _bookingInfo(
                            "Service done at",
                            _serviceRecordValue(
                              booking["service_done_km"],
                              suffix: "km",
                            ),
                          ),
                          _bookingInfo(
                            "Next service due at",
                            _serviceRecordValue(
                              booking["next_service_due_km"],
                              suffix: "km",
                            ),
                          ),
                          _bookingInfo("Payment", "Pay at workshop"),
                          _bookingInfo("Total", "Rs ${double.tryParse((booking["total"] ?? "0").toString())?.toStringAsFixed(0) ?? "0"}"),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _bookingInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBookingDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return "-";
    return "${date.day.toString().padLeft(2, "0")}/${date.month.toString().padLeft(2, "0")}/${date.year}";
  }

  String _serviceRecordValue(
    Object? raw, {
    String suffix = "",
    String Function(String value)? formatter,
  }) {
    final value = (raw ?? "").toString().trim();
    if (value.isEmpty) return "Not updated";
    final formatted = formatter != null ? formatter(value) : value;
    if (formatted == "-" || formatted.trim().isEmpty) return "Not updated";
    return suffix.isEmpty ? formatted : "$formatted $suffix";
  }
}

class MotorcycleServiceAdminScreen extends StatefulWidget {
  const MotorcycleServiceAdminScreen({super.key});

  @override
  State<MotorcycleServiceAdminScreen> createState() =>
      _MotorcycleServiceAdminScreenState();
}

class _MotorcycleServiceAdminScreenState
    extends State<MotorcycleServiceAdminScreen> {
  final MotorcycleServiceBookingService _bookingService =
      MotorcycleServiceBookingService();
  static const List<String> _statusOptions = <String>[
    "All",
    "Hold",
    "Processing",
    "Part Order",
    "Complete",
    "Canceled",
  ];

  final TextEditingController _essentialController = TextEditingController();
  final TextEditingController _performanceController = TextEditingController();
  final TextEditingController _ultimateController = TextEditingController();
  bool _pickupDropEnabled = false;
  final TextEditingController _pickupDropCityController =
      TextEditingController();
  String _selectedStatusFilter = "All";
  final TextEditingController _bookingSearchController = TextEditingController();

  List<Map<String, dynamic>> _bookings = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _essentialController.dispose();
    _performanceController.dispose();
    _ultimateController.dispose();
    _pickupDropCityController.dispose();
    _bookingSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final bookings = await _bookingService.getBookings(adminView: true);
    final charges = await _bookingService.getPackageCharges();
    final serviceConfig = await _bookingService.getServiceConfig();
    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _essentialController.text =
          (charges["essential"] ?? 699).toStringAsFixed(0);
      _performanceController.text =
          (charges["performance"] ?? 1199).toStringAsFixed(0);
      _ultimateController.text =
          (charges["ultimate"] ?? 1899).toStringAsFixed(0);
      _pickupDropEnabled = serviceConfig["pickup_drop_enabled"] == true;
      _pickupDropCityController.text =
          (serviceConfig["pickup_drop_city"] ?? "Jaipur").toString();
      _loading = false;
    });
  }

  Future<void> _saveCharges() async {
    await _bookingService.savePackageCharges({
      "essential": double.tryParse(_essentialController.text.trim()) ?? 699,
      "performance": double.tryParse(_performanceController.text.trim()) ?? 1199,
      "ultimate": double.tryParse(_ultimateController.text.trim()) ?? 1899,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Service charges updated")),
    );
  }

  Future<void> _saveServiceConfig() async {
    await _bookingService.saveServiceConfig({
      "pickup_drop_enabled": _pickupDropEnabled,
      "pickup_drop_city": _pickupDropCityController.text.trim().isEmpty
          ? "Jaipur"
          : _pickupDropCityController.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pickup & Drop settings updated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _bookingSearchController.text.trim().toLowerCase();
    final filteredBookings = _bookings.where((booking) {
      final status = (booking["status"] ?? "Hold").toString();
      final matchesStatus =
          _selectedStatusFilter == "All" || status == _selectedStatusFilter;
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      final haystack = [
        (booking["booking_id"] ?? "").toString(),
        (booking["customer_name"] ?? "").toString(),
        (booking["customer_phone"] ?? "").toString(),
        (booking["bike_model"] ?? "").toString(),
        (booking["package_title"] ?? "").toString(),
      ].join(" ").toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text("Admin Service Bookings"),
        backgroundColor: const Color(0xFF151826),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Service Charge Control",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _chargeField(_essentialController, "Essential"),
                      const SizedBox(height: 10),
                      _chargeField(_performanceController, "Performance"),
                      const SizedBox(height: 10),
                      _chargeField(_ultimateController, "Ultimate"),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _saveCharges,
                        child: const Text("Save Charges"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Pickup & Drop Control",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _pickupDropEnabled,
                        onChanged: (value) {
                          setState(() {
                            _pickupDropEnabled = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFFFF5A36),
                        title: const Text(
                          "Enable Pickup & Drop",
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          "This option should be available only when you want to offer it.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _pickupDropCityController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Allowed city",
                          hintText: "Jaipur",
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF11131F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _saveServiceConfig,
                        child: const Text("Save Pickup & Drop Settings"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "All Bookings",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bookingSearchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search bookings",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF11131F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _statusOptions.map((status) {
                          final selected = _selectedStatusFilter == status;
                          return ChoiceChip(
                            label: Text(status),
                            selected: selected,
                            selectedColor: const Color(0xFFFF5A36),
                            backgroundColor: const Color(0xFF11131F),
                            labelStyle: const TextStyle(color: Colors.white),
                            onSelected: (_) {
                              setState(() {
                                _selectedStatusFilter = status;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      if (filteredBookings.isEmpty)
                        const Text(
                          "No bookings yet.",
                          style: TextStyle(color: Colors.white70),
                        )
                      else
                        ...filteredBookings.map((booking) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF11131F),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (booking["package_title"] ?? "-").toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _adminInfo("Customer", (booking["customer_name"] ?? "-").toString()),
                                _adminInfo("Phone", (booking["customer_phone"] ?? "-").toString()),
                                _adminInfo("Email", (booking["customer_email"] ?? "-").toString()),
                                _adminInfo("Bike", (booking["bike_model"] ?? "-").toString()),
                                _adminInfo("Date", (booking["service_date"] ?? "-").toString()),
                                _adminInfo("Time", (booking["time_slot"] ?? "-").toString()),
                                _adminInfo("Address", (booking["address"] ?? "-").toString()),
                                _adminInfo(
                                  "Workshop Address",
                                  (booking["workshop_address"] ??
                                          "Shop no. 5, Hanuman Market, 200ft, Airport Rd, near 7no choraha, near Mahima Paradise, Ravindra Nagar - A, Jagatpura, Jaipur, Rajasthan 302033")
                                      .toString(),
                                ),
                                _adminInfo(
                                  "Workshop Phone",
                                  (booking["workshop_phone"] ?? "9166666554")
                                      .toString(),
                                ),
                                _adminInfo(
                                  "Service Done On",
                                  _serviceRecordValue(
                                    booking["completed_service_date"],
                                    formatter: _formatBookingDate,
                                  ),
                                ),
                                _adminInfo(
                                  "Service Done At",
                                  _serviceRecordValue(
                                    booking["service_done_km"],
                                    suffix: "km",
                                  ),
                                ),
                                _adminInfo(
                                  "Next Service Due At",
                                  _serviceRecordValue(
                                    booking["next_service_due_km"],
                                    suffix: "km",
                                  ),
                                ),
                                _adminInfo("Air Filter", (booking["air_filter_option"] ?? "-").toString()),
                                _adminInfo("Total", "Rs ${double.tryParse((booking["total"] ?? "0").toString())?.toStringAsFixed(0) ?? "0"}"),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: _normalizeStatus((booking["status"] ?? "Hold").toString()),
                                  dropdownColor: const Color(0xFF1C1F2E),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Booking status",
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    filled: true,
                                    fillColor: const Color(0xFF1A1D2A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items: _statusOptions
                                      .where((status) => status != "All")
                                      .map(
                                        (status) => DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(status),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    await _bookingService.updateBookingStatus(
                                      bookingId: (booking["booking_id"] ?? "").toString(),
                                      status: value,
                                    );
                                    await _load();
                                  },
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await _showServiceRecordEditor(booking);
                                  },
                                  icon: const Icon(Icons.build_circle_outlined),
                                  label: const Text("Update Service Record"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                  ),
                                ),
                                _buildAdminQuotation(booking),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _adminCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _chargeField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: "$label service charge",
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF11131F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _adminInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        "$label: $value",
        style: const TextStyle(color: Colors.white70, height: 1.35),
      ),
    );
  }

  String _normalizeStatus(String status) {
    final normalized = status.trim();
    return _statusOptions.contains(normalized) ? normalized : "Hold";
  }

  String _formatBookingDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return "-";
    return "${date.day.toString().padLeft(2, "0")}/${date.month.toString().padLeft(2, "0")}/${date.year}";
  }

  String _serviceRecordValue(
    Object? raw, {
    String suffix = "",
    String Function(String value)? formatter,
  }) {
    final value = (raw ?? "").toString().trim();
    if (value.isEmpty) return "Not updated";
    final formatted = formatter != null ? formatter(value) : value;
    if (formatted == "-" || formatted.trim().isEmpty) return "Not updated";
    return suffix.isEmpty ? formatted : "$formatted $suffix";
  }

  Future<void> _showServiceRecordEditor(Map<String, dynamic> booking) async {
    await showDialog<void>(
      context: context,
      builder: (modalContext) {
        return _ServiceRecordEditorDialog(
          initialServiceDate:
              (booking["completed_service_date"] ?? "").toString().trim(),
          initialServiceDoneKm:
              (booking["service_done_km"] ?? "").toString().trim(),
          initialNextServiceDueKm:
              (booking["next_service_due_km"] ?? "").toString().trim(),
          onSave: (
            completedServiceDate,
            serviceDoneKm,
            nextServiceDueKm,
          ) async {
            await _bookingService.updateBookingAdminDetails(
              bookingId: (booking["booking_id"] ?? "").toString(),
              completedServiceDate: completedServiceDate,
              serviceDoneKm: serviceDoneKm,
              nextServiceDueKm: nextServiceDueKm,
            );
            if (!mounted) return;
            await _load();
          },
        );
      },
    );
  }

  Widget _buildAdminQuotation(Map<String, dynamic> booking) {
    final items = booking["quotation_items"];
    final normalizedItems = <Map<String, dynamic>>[];
    if (items is List) {
      for (final raw in items) {
        if (raw is Map) {
          normalizedItems.add(Map<String, dynamic>.from(raw));
        }
      }
    }
    final subtotal =
        double.tryParse((booking["subtotal"] ?? "0").toString()) ?? 0;
    final discount =
        double.tryParse((booking["discount"] ?? "0").toString()) ?? 0;
    final total = double.tryParse((booking["total"] ?? "0").toString()) ?? 0;

    if (normalizedItems.isEmpty &&
        subtotal == 0 &&
        discount == 0 &&
        total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quotation",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (normalizedItems.isEmpty)
            const Text(
              "Detailed line items are not available for this booking, but the quotation summary is shown below.",
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
            ),
          ...normalizedItems.map((item) {
            final amount =
                double.tryParse((item["amount"] ?? "0").toString()) ?? 0;
            final subtitle = (item["subtitle"] ?? "").toString().trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item["title"] ?? "-").toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Rs ${amount.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (normalizedItems.isNotEmpty)
            const Divider(color: Colors.white12, height: 20),
          _adminQuoteSummaryRow("Subtotal", "Rs ${subtotal.toStringAsFixed(0)}"),
          _adminQuoteSummaryRow("Discount", "-Rs ${discount.toStringAsFixed(0)}"),
          _adminQuoteSummaryRow(
            "Final total",
            "Rs ${total.toStringAsFixed(0)}",
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _adminQuoteSummaryRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: highlight ? Colors.white : Colors.white70,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFFFB36B) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRecordEditorDialog extends StatefulWidget {
  const _ServiceRecordEditorDialog({
    required this.initialServiceDate,
    required this.initialServiceDoneKm,
    required this.initialNextServiceDueKm,
    required this.onSave,
  });

  final String initialServiceDate;
  final String initialServiceDoneKm;
  final String initialNextServiceDueKm;
  final Future<void> Function(String, String, String) onSave;

  @override
  State<_ServiceRecordEditorDialog> createState() =>
      _ServiceRecordEditorDialogState();
}

class _ServiceRecordEditorDialogState extends State<_ServiceRecordEditorDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _serviceDoneKmController;
  late final TextEditingController _nextServiceDueKmController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.initialServiceDate);
    _serviceDoneKmController =
        TextEditingController(text: widget.initialServiceDoneKm);
    _nextServiceDueKmController =
        TextEditingController(text: widget.initialNextServiceDueKm);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _serviceDoneKmController.dispose();
    _nextServiceDueKmController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate =
        DateTime.tryParse(_dateController.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2022),
      lastDate: DateTime(2035),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dateController.text = picked.toIso8601String().split("T").first;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
    });
    await widget.onSave(
      _dateController.text.trim(),
      _serviceDoneKmController.text.trim(),
      _nextServiceDueKmController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1F2E),
      title: const Text(
        "Update Service Record",
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _dateController,
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Service date",
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF11131F),
                suffixIcon: IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white70,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serviceDoneKmController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Service done at (km)",
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF11131F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nextServiceDueKmController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Next service due at (km)",
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF11131F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop();
                },
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? "Saving..." : "Save"),
        ),
      ],
    );
  }
}
