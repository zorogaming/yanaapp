import 'package:flutter/material.dart';
import '../services/woo_service.dart';
import '../widgets/skeletons.dart';

class MyOrdersScreen extends StatefulWidget {
  final int customerId;

  const MyOrdersScreen({super.key, required this.customerId});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List> ordersFuture;

  @override
  void initState() {
    super.initState();
    ordersFuture = WooService().fetchCustomerOrders(widget.customerId);
  }

  // ✅ Order Status ke hisaab se color return karne ke liye helper function
  Color _getStatusColor(String status, {bool confirmationPending = false}) {
    if (confirmationPending) return Colors.amber.shade800;
    switch (status.toLowerCase()) {
      case 'processing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'on-hold':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  bool _isPaymentConfirmationPending(Map order) {
    final meta = order['meta_data'];
    if (meta is! List) return false;
    for (final item in meta) {
      if (item is! Map) continue;
      final key = (item['key'] ?? '').toString();
      final value = (item['value'] ?? '').toString();
      if (key == 'app_payment_confirmation_pending' && value == '1') {
        return true;
      }
    }
    return false;
  }

  String _statusLabel(String status, {bool confirmationPending = false}) {
    if (confirmationPending) {
      return 'PAYMENT RECEIVED, CONFIRMATION PENDING';
    }
    return status.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background
      appBar: AppBar(
        title: const Text("My Orders", style: TextStyle(color: Colors.white)),
        backgroundColor: theme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: FutureBuilder<List>(
        future: ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const FullPageSkeleton();
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No Orders Found"));
          }

          final orders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              String status = order['status'] ?? 'unknown';
              final confirmationPending =
                  order is Map && _isPaymentConfirmationPending(order);
              final statusColor = _getStatusColor(
                status,
                confirmationPending: confirmationPending,
              );

              // ✅ Adjusted Card Styling
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Order #${order['id']}",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(
                                  status,
                                  confirmationPending: confirmationPending,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Date: ${order['date_created']}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total"),
                          Text(
                            "₹${order['total']}",
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
