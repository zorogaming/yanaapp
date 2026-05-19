import 'package:flutter/material.dart';

class OrderDetailScreen extends StatelessWidget {
  final Map order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final items = order["line_items"];

    return Scaffold(
      appBar: AppBar(title: Text("Order #${order["id"]}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Status: ${order["status"]}"),
            const SizedBox(height: 10),
            Text("Total: ₹${order["total"]}"),
            const SizedBox(height: 20),
            const Text(
              "Items",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index];

                  return ListTile(
                    title: Text(item["name"]),
                    subtitle:
                        Text("Qty: ${item["quantity"]}  ₹${item["total"]}"),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
