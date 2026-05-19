import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../widgets/skeletons.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final AccountService _accountService = AccountService();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final address1 = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final postcode = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prefillAddress();
  }

  Future<void> _prefillAddress() async {
    final customer = await _accountService.fetchCustomer();
    final billing = (customer["billing"] as Map<String, dynamic>?) ?? {};

    if (!mounted) return;
    setState(() {
      firstName.text = (billing["first_name"] ?? "").toString();
      lastName.text = (billing["last_name"] ?? "").toString();
      address1.text = (billing["address_1"] ?? "").toString();
      city.text = (billing["city"] ?? "").toString();
      state.text = (billing["state"] ?? "").toString();
      postcode.text = (billing["postcode"] ?? "").toString();
      _isLoading = false;
    });
  }

  Future<void> saveAddress() async {
    await _accountService.updateAddress({
      "billing": {
        "first_name": firstName.text,
        "last_name": lastName.text,
        "address_1": address1.text,
        "city": city.text,
        "state": state.text,
        "postcode": postcode.text,
        "country": "IN"
      }
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Address Updated")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Address")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const FullPageSkeleton(padding: EdgeInsets.zero)
            : Column(
                children: [
                  TextField(
                    controller: firstName,
                    decoration: const InputDecoration(labelText: "First Name"),
                  ),
                  TextField(
                    controller: lastName,
                    decoration: const InputDecoration(labelText: "Last Name"),
                  ),
                  TextField(
                    controller: address1,
                    decoration: const InputDecoration(labelText: "Address"),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: "City"),
                  ),
                  TextField(
                    controller: state,
                    decoration: const InputDecoration(labelText: "State"),
                  ),
                  TextField(
                    controller: postcode,
                    decoration: const InputDecoration(labelText: "Postcode"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saveAddress,
                    child: const Text("Save"),
                  ),
                ],
              ),
      ),
    );
  }
}
