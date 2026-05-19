import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoiceScreen extends StatelessWidget {
  final int orderId;

  const InvoiceScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final invoiceUrl = "https://yanaworldwide.store/?print_invoice=$orderId";

    return Scaffold(
      appBar: AppBar(title: const Text("Invoice")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final Uri uri = Uri.parse(invoiceUrl);

            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Could not open invoice")),
              );
            }
          },
          child: const Text("Download Invoice"),
        ),
      ),
    );
  }
}
