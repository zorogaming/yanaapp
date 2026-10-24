import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanaworldwide_store/widgets/sale_banner.dart';
import 'package:yanaworldwide_store/widgets/festival_sale_decoration.dart';

void main() {
  testWidgets('Festival title, icon, active border and tap fit small cards', (
    tester,
  ) async {
    var taps = 0;
    for (final key in FestivalSaleIcon.icons.keys) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: SaleBanner(
                  daily: false,
                  enabled: true,
                  saleTitle: '$key Sale',
                  festivalKey: key,
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FestivalSaleIcon), findsOneWidget);
      expect(find.byType(ActiveSaleBorder), findsOneWidget);
      expect(tester.takeException(), isNull, reason: key);
    }
    await tester.tap(find.byType(SaleBanner));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Disabled sale blocks taps and reduced motion stops animated border',
    (tester) async {
      var taps = 0;
      Future<void> show({required bool enabled, required bool reduced}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: SizedBox(
                  width: 180,
                  child: SaleBanner(
                    daily: false,
                    enabled: enabled,
                    saleTitle: 'Diwali Sale',
                    festivalKey: 'diwali',
                    onTap: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await show(enabled: false, reduced: false);
      expect(find.byType(ActiveSaleBorder), findsNothing);
      await tester.tap(find.byType(SaleBanner));
      expect(taps, 0);
      await show(enabled: true, reduced: true);
      expect(find.byType(ActiveSaleBorder), findsNothing);
      expect(find.text('Diwali Sale'), findsOneWidget);
    },
  );
}
