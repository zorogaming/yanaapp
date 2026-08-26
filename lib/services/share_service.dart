import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models/product_model.dart';

class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  String get _siteBaseUrl {
    final uri = Uri.parse(Config.baseUrl);
    return '${uri.scheme}://${uri.host}';
  }

  Future<void> shareProduct(BuildContext context, Product product) async {
    final url = _productUrl(product);
    final price = product.price.trim().isEmpty
        ? ''
        : '\nPrice: ₹${product.price}';
    await Share.share(
      'Check out ${product.name}$price\n$url',
      subject: product.name,
      sharePositionOrigin: _sharePositionOrigin(context),
    );
  }

  Future<void> shareCategory({
    required BuildContext context,
    required int categoryId,
    required String categoryName,
    String? categorySlug,
  }) async {
    final url = _categoryUrl(
      categoryId: categoryId,
      categorySlug: categorySlug,
    );
    await Share.share(
      'Check out $categoryName products on Yanaworldwide\n$url',
      subject: categoryName,
      sharePositionOrigin: _sharePositionOrigin(context),
    );
  }

  Rect? _sharePositionOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  String _productUrl(Product product) {
    final permalink = product.permalink.trim();
    if (permalink.startsWith('http')) return permalink;

    final slug = product.slug.trim();
    if (slug.isNotEmpty) return '$_siteBaseUrl/product/$slug/';

    return '$_siteBaseUrl/?p=${product.id}';
  }

  String _categoryUrl({required int categoryId, String? categorySlug}) {
    final slug = (categorySlug ?? '').trim();
    if (slug.isNotEmpty) return '$_siteBaseUrl/product-category/$slug/';

    return '$_siteBaseUrl/shop/?category_id=$categoryId';
  }
}
