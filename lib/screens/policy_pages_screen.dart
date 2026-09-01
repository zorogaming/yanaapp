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
        "At Yana Worldwide, we strive to process and dispatch orders as quickly as possible.",
        "Order Cancellation\nOrders can only be canceled within 5 hours of placing the order. Any cancellation request received after 5 hours from the time of purchase will not be accepted. Once the cancellation window has expired, the order cannot be canceled under any circumstances. Customers are requested to carefully verify product compatibility, quantity, shipping address, and other order details before placing an order.",
        "Snapmint EMI Orders\nOrders placed through Snapmint EMI are not eligible for cancellation. Such orders may only qualify for replacement in the event of a verified defective product, subject to approval.",
        "Refused Deliveries\nRefusing delivery after an order has been shipped does not make the order eligible for cancellation, return, or refund. If a customer refuses delivery and the shipment is returned to us, the customer will be responsible for all applicable forward shipping charges, return shipping charges, handling charges, and associated costs. Any advance payment made may be adjusted against these charges before any balance amount is considered for refund, if applicable.",
        "Refund Method\nApproved refunds may first be issued as Store Wallet Credit. In exceptional cases, refunds may be processed to the original payment method. Refund processing times depend on payment providers, banks, and settlement timelines.",
        "Refund Deductions\nWhere legally permissible, approved refunds may be subject to deductions including payment gateway charges, merchant settlement charges, shipping charges, return shipping charges, handling charges, packaging charges, and other applicable operational costs.",
        "Final Decision\nAll return, replacement, refund, and cancellation requests are subject to verification and final approval by Yana Worldwide. The company's decision regarding eligibility and resolution shall be final.",
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
        "Return, Replacement & Refund Policy\nWe accept claims only for products that are received damaged, defective, or incorrectly supplied.",
        "Mandatory Unboxing Video Requirement\nTo qualify for any return, replacement, or refund request, a complete unboxing video is mandatory. The video must start before opening the package, clearly show the shipping label and outer packaging, show the entire package continuously from start to finish, be recorded without cuts, edits, pauses, or interruptions, and clearly show the opening of the package and the contents received.",
        "Claims will be rejected if the video contains cuts, edits, or missing portions, the package is not fully visible throughout the recording, the product issue cannot be clearly verified from the video, or no unboxing video is provided.",
        "Statements such as \"The video was not recorded properly\", \"The video contains cuts by mistake\", \"I forgot to record the video\", or \"The issue is not visible in the video\" will not be accepted as valid grounds for approval.",
        "Reporting an Issue\nCustomers must report any damaged, defective, or incorrect item within 48 hours of delivery. The claim must include order number, product photographs, clear description of the issue, and complete unboxing video. Claims submitted after 48 hours may be rejected.",
        "Replacement Policy\nReplacement is the primary resolution offered for approved claims. Replacements are subject to stock availability and verification. Products must be unused and in the same condition as received. Customers may be required to return the original product before a replacement is issued.",
        "Refund Policy\nRefunds are generally not provided when a replacement is available. A refund may only be considered when a replacement product is unavailable due to stock shortages, a replacement cannot be arranged for operational reasons, or the company determines that a refund is the appropriate resolution.",
        "Non-Returnable Situations\nReturns, replacements, or refunds will not be accepted for incorrect products ordered by the customer, compatibility issues due to failure to verify vehicle fitment, products damaged due to improper installation or misuse, normal wear and tear, claims submitted without a valid unboxing video, claims submitted after the reporting period, refused deliveries, and Snapmint EMI orders except verified defective product replacement cases.",
        "Final Decision\nAll return, replacement, refund, and cancellation requests are subject to verification and final approval by Yana Worldwide. The company's decision regarding eligibility and resolution shall be final.",
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
