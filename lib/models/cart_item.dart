class CartItem {
  final int id;
  final String name;
  final String image;
  final double price;
  int quantity;
  final int? variationId;

  CartItem({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    this.quantity = 1,
    this.variationId,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "image": image,
      "price": price,
      "quantity": quantity,
      "variation_id": variationId,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json["id"],
      name: json["name"],
      image: json["image"],
      price: (json["price"] as num).toDouble(),
      quantity: json["quantity"],
      variationId: json["variation_id"],
    );
  }
}
