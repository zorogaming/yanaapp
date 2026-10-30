import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanaworldwide_store/services/data_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'category session preserves every product, stable order and disk cache',
    () async {
      final original = List.generate(125, (i) => {'id': i + 1});
      final encoded = jsonEncode(original);
      SharedPreferences.setMockInitialValues({
        'category_98765_all_v2': encoded,
      });
      final first = await DataManager().getCategoryProducts(98765);
      final second = await DataManager().getCategoryProducts(98765);
      expect(second, first);
      expect(
        first.map((p) => p['id']).toSet(),
        original.map((p) => p['id']).toSet(),
      );
      // Returning a list to callers must not let them mutate the session order.
      first.clear();
      expect(await DataManager().getCategoryProducts(98765), second);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('category_98765_all_v2'), encoded);
      final pages = [
        for (var i = 0; i < second.length; i += 20) second.skip(i).take(20),
      ].expand((page) => page).toList();
      expect(pages, second);
    },
  );
  test('next session does not repeat the previous first product', () async {
    SharedPreferences.setMockInitialValues({
      'category_98766_all_v2': jsonEncode([{'id': 1}, {'id': 2}]),
      'category_98766_all_v2_previous_first': '1',
    });
    final items = await DataManager().getCategoryProducts(98766);
    expect(items.first['id'], 2);
    expect(items.map((p) => p['id']).toSet(), {1, 2});
  });

}
