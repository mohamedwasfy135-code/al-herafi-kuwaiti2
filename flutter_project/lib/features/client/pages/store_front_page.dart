import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/providers/cart_provider.dart';
import 'cart_page.dart';
import '../../auth/pages/auth_page.dart';

class StoreFrontPage extends StatefulWidget {
  final String businessId;
  final String businessName;
  const StoreFrontPage({super.key, required this.businessId, required this.businessName});

  @override
  State<StoreFrontPage> createState() => _StoreFrontPageState();
}

class _StoreFrontPageState extends State<StoreFrontPage> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.currentUser == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthPage()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _uid = AuthService.currentUser?.id ?? '';
      });
    });
  }

  /// Polling stream for approved products of this business
  Stream<List<Map<String, dynamic>>> _productsStream() async* {
    while (true) {
      try {
        final products = await FirestoreService.getProducts(businessId: widget.businessId);
        yield products.where((p) => p['status'] == 'approved').toList();
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/ocean_bg.jpg', fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                decoration: const BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)],
                )),
              ),
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
          Column(children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF007A3D), Color(0xFFFFFFFF), Color(0xFFCE1126), Color(0xFF000000)], stops: [0.0, 0.35, 0.75, 1.0]),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  Expanded(child: Text(widget.businessName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  Consumer<CartProvider>(
                    builder: (context, cart, _) {
                      final count = cart.itemCount;
                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart, color: Colors.white),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CartPage()),
                            ),
                          ),
                          if (count > 0)
                            Positioned(
                              right: 6, top: 6,
                              child: CircleAvatar(
                                radius: 9, backgroundColor: Colors.red,
                                child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ]),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _productsStream(),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
                  }
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const Center(child: Text('لا توجد منتجات حالياً', style: TextStyle(color: Colors.white70)));
                  }

                  final products = snap.data!;
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final d = products[i];
                      final productId = d['id']?.toString() ?? '';
                      final imageUrl = d['imageUrl'] as String? ?? '';
                      final name = d['name'] ?? '';
                      final originalPrice = (d['originalPrice'] as num?)?.toDouble() ?? 0;
                      final discountedPrice = d['discountedPrice'] as double?;
                      final price = discountedPrice ?? originalPrice;
                      final stock = d['stock'] as int? ?? 0;
                      final bool isOutOfStock = stock <= 0;

                      return Card(
                        color: Colors.white.withOpacity(0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: imageUrl.isNotEmpty
                                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                                        : Container(color: Colors.grey.shade800, child: const Icon(Icons.image, color: Colors.white54)),
                                  ),
                                  if (isOutOfStock)
                                    Container(
                                      color: Colors.black.withOpacity(0.6),
                                      alignment: Alignment.center,
                                      child: const Text('Sold Out',
                                          style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  if (discountedPrice != null && discountedPrice < originalPrice) ...[
                                    Text('${originalPrice.toStringAsFixed(3)} د.ك',
                                        style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.white54, fontSize: 12)),
                                    Text('${discountedPrice.toStringAsFixed(3)} د.ك',
                                        style: const TextStyle(color: Color(0xFF0071E3), fontWeight: FontWeight.bold)),
                                  ] else
                                    Text('${originalPrice.toStringAsFixed(3)} د.ك',
                                        style: const TextStyle(color: Color(0xFF0071E3), fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(isOutOfStock ? 'نفذت الكمية' : 'المخزون: $stock',
                                      style: TextStyle(color: isOutOfStock ? Colors.red : Colors.green, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Consumer<CartProvider>(
                                    builder: (context, cart, _) {
                                      final inCart = cart.items.containsKey(productId);
                                      return SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: isOutOfStock
                                              ? null
                                              : () {
                                                  if (inCart) {
                                                    cart.removeItem(productId);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('تم إزالة $name من السلة'), backgroundColor: Colors.orange),
                                                    );
                                                  } else {
                                                    cart.addItem(CartItem(
                                                      productId: productId,
                                                      businessId: widget.businessId,
                                                      name: name,
                                                      price: price,
                                                      imageUrl: imageUrl,
                                                    ));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('تم إضافة $name إلى السلة'), backgroundColor: Colors.green),
                                                    );
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isOutOfStock
                                                ? Colors.grey
                                                : inCart
                                                    ? Colors.red
                                                    : const Color(0xFF0071E3),
                                            foregroundColor: isOutOfStock
                                                ? Colors.white70
                                                : inCart
                                                    ? Colors.white
                                                    : Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                          ),
                                          child: Text(isOutOfStock ? 'Sold Out' : inCart ? 'إزالة من السلة' : 'أضف للسلة'),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
