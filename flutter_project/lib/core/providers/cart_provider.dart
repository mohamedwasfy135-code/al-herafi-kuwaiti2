import 'package:flutter/foundation.dart';

class CartItem {
  final String productId;
  final String businessId;  // معرف المحل صاحب المنتج
  final String name;
  final double price;
  int quantity;
  final String? imageUrl;

  CartItem({
    required this.productId,
    required this.businessId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
  });
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.values.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  void addItem(CartItem item) {
    if (_items.containsKey(item.productId)) {
      _items[item.productId]!.quantity += 1;
    } else {
      _items[item.productId] = item;
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (_items.containsKey(productId)) {
      if (quantity <= 0) {
        _items.remove(productId);
      } else {
        _items[productId]!.quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}