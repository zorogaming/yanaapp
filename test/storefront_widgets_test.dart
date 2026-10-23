import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanaworldwide_store/theme/app_theme.dart';
import 'package:yanaworldwide_store/widgets/storefront_widgets.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [AppThemes.midnightPalette]),
    home: Scaffold(body: child),
  );

  testWidgets('Sale and service rows fit small and large phone widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 390.0, 600.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        host(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StorefrontSaleCard(
                        daily: true,
                        enabled: true,
                        countdown: '02:49:37',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: StorefrontSaleCard(
                        daily: false,
                        enabled: true,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const StorefrontBenefits(),
                Row(
                  children: [
                    Expanded(
                      child: StorefrontServiceCard(
                        title: 'Track Your Parcel',
                        subtitle: 'Enter AWB / Order No.',
                        icon: Icons.inventory_2_outlined,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StorefrontServiceCard(
                        title: 'Motorcycle Service',
                        subtitle: 'Book Bike Service Near You',
                        icon: Icons.handyman_outlined,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Layout at $width pixels');
    }
  });

  testWidgets('Disabled sale preserves countdown and blocks navigation', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 190,
          child: StorefrontSaleCard(
            daily: true,
            enabled: false,
            countdown: '01:20:30',
            countdownLabel: 'Starts in',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Starts in'), findsOneWidget);
    await tester.tap(find.text('Daily Sale'));
    expect(taps, 0);
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 190,
          child: StorefrontSaleCard(
            daily: true,
            enabled: true,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Daily Sale'));
    expect(taps, 1);
  });
}
