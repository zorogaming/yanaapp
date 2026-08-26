import 'package:flutter/material.dart';

import 'products_screen.dart';

class SearchResultScreen extends StatelessWidget {
  const SearchResultScreen({
    super.key,
    required this.searchQuery,
  });

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim();
    return ProductsScreen(
      title: query.isEmpty ? "Search Products" : "Search: $query",
      initialSearchQuery: query,
    );
  }
}
