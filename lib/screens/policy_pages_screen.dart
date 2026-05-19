import 'package:flutter/material.dart';

class PolicyPageScreen extends StatelessWidget {
  final String title;
  final List<String> sections;

  const PolicyPageScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1C1F2E),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              sections[index],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScreen(
      title: "Contact Us",
      sections: [
        "Need help? Contact us using the details below for support related to orders, payments, shipping, returns, and account assistance.",
        "Shop / Office Address\n100/112, Sector 10, Kumbha Marg, Pratap Nagar, Jaipur, Rajasthan 302033\nIndia",
        "Customer Support Hours\nCall us between 8 AM - 8 PM",
        "Email: admin@yanaworldwide.store",
        "Phone / WhatsApp: +91 9166666554",
      ],
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScreen(
      title: "Privacy Policy",
      sections: [
        "We collect basic customer details such as name, phone number, email address, shipping address, and order information to process purchases and provide support.",
        "Payment transactions are processed through secure third-party gateways. We do not store full card details, UPI PINs, or other sensitive payment credentials on our app servers.",
        "Your information may be used for order updates, delivery coordination, refunds, account verification, and customer service communication.",
        "We may use limited technical data such as device details, app events, and analytics to improve app performance, security, and user experience.",
        "Customer data is not sold to third parties. Information is shared only with service providers required for payments, logistics, notifications, or legal compliance.",
        "If you need help with your personal data, account corrections, or privacy-related requests, contact our support team through the details provided in the app.",
      ],
    );
  }
}

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScreen(
      title: "Terms & Conditions",
      sections: [
        "By using this app and placing an order, you agree to Yana Worldwide terms and applicable laws.",
        "Payments are processed securely through PhonePe / Cashfree payment gateway systems. We do not store full card, bank, or UPI credentials on our app servers.",
        "An order is confirmed only after successful payment authorization and order verification from PhonePe / Cashfree and our server.",
        "In case of payment success but order creation delay, your transaction reference and order status will be validated with PhonePe / Cashfree before final confirmation.",
        "Pricing, offers, stock availability, and delivery timelines are subject to change without prior notice.",
        "Any misuse, fraud attempt, chargeback abuse, or suspicious activity may lead to cancellation, account restriction, or legal action.",
      ],
    );
  }
}

class RefundsAndCancellationsPage extends StatelessWidget {
  const RefundsAndCancellationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScreen(
      title: "Refunds & Cancellations",
      sections: [
        "Cancellation requests are accepted before order processing/dispatch. Once dispatched, cancellation may not be possible.",
        "For prepaid orders paid via PhonePe / Cashfree, approved refunds are initiated to the original payment source as per banking timelines.",
        "Typical refund timeline is 5-7 business days after approval, but actual credit depends on bank/issuer/UPI partner.",
        "If payment is debited but order is not confirmed, we verify payment status with PhonePe / Cashfree. Eligible transactions are auto-refunded or manually refunded after verification.",
        "Refunds may be rejected for delivered, used, damaged-by-customer, or policy-violating return requests.",
        "For refund help, contact support with Order ID, payment amount, and transaction details.",
      ],
    );
  }
}

class ReturnPolicyPage extends StatelessWidget {
  const ReturnPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScreen(
      title: "Return Policy",
      sections: [
        "Returns are accepted only for eligible products in unused condition with original packaging, tags, and invoice intact.",
        "Return requests must be raised within 7 days of delivery unless a different return window is explicitly mentioned on the product page.",
        "If a product is marked non-returnable or has a different return timeline, the product page or order details page will override the standard 7-day window.",
        "Products showing signs of use, physical damage, missing accessories, or tampered packaging may be rejected after inspection.",
        "Some categories such as clearance items, special-order parts, consumables, or custom items may be non-returnable.",
        "Approved returns are processed after pickup and quality check confirmation from our team.",
      ],
    );
  }
}

class ShippingPolicyPage extends StatelessWidget {
  const ShippingPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScreen(
      title: "Shipping Policy",
      sections: [
        "Orders are shipped after payment confirmation or order verification, depending on the selected payment method.",
        "Shipping charges, if applicable, are shown during checkout before you place the order.",
        "We ship through trusted courier partners and share tracking details once the shipment is packed and dispatched.",
        "Shipping availability may vary by pincode, courier serviceability, product category, and stock location.",
        "Delays caused by weather, logistics issues, public holidays, or remote-area routing may affect final delivery speed.",
      ],
    );
  }
}

class DeliveryTimelinePage extends StatelessWidget {
  const DeliveryTimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PolicyPageScreen(
      title: "Delivery Timeline",
      sections: [
        "Most confirmed orders are processed within 1-2 business days before dispatch.",
        "Metro city deliveries usually take 2-5 business days after dispatch, while other regions may take 4-8 business days.",
        "Remote locations, heavy products, or pre-order items may require additional delivery time.",
        "Delivery estimates are indicative and begin after dispatch, not from the moment the order is placed.",
        "If your order is delayed beyond the expected timeline, contact support with your Order ID for an updated shipment status.",
      ],
    );
  }
}
