class PaginatedProductsResult {
  final List<dynamic> items;
  final int totalProducts;
  final int totalPages;

  const PaginatedProductsResult({
    required this.items,
    required this.totalProducts,
    required this.totalPages,
  });
}
