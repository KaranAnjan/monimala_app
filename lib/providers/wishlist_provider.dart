import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class WishlistProvider extends ChangeNotifier {
  final List<String> _wishlistProductIds = [];
  List<Product> _wishlistProducts = [];
  bool _isLoading = false;

  List<String> get wishlistProductIds => _wishlistProductIds;
  List<Product> get wishlistProducts => _wishlistProducts;
  bool get isLoading => _isLoading;

  WishlistProvider() {
    _init();
  }

  void _init() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session == null) {
        _wishlistProductIds.clear();
        _wishlistProducts.clear();
        notifyListeners();
      } else {
        fetchWishlist();
      }
    });
    fetchWishlist();
  }

  Future<void> fetchWishlist() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = await Supabase.instance.client
          .from('wishlists')
          .select('product_id, products(*, categories(category_name))')
          .eq('user_id', user.id);

      _wishlistProductIds.clear();
      _wishlistProducts.clear();
      
      for (var item in (data as List)) {
        final productId = item['product_id'].toString();
        _wishlistProductIds.add(productId);
        if (item['products'] != null) {
          _wishlistProducts.add(Product.fromJson(item['products']));
        }
      }
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isWishlisted(String productId) {
    return _wishlistProductIds.contains(productId);
  }

  Future<void> toggleWishlist(Product product) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final productId = product.id;
    final currentlyWishlisted = isWishlisted(productId);

    try {
      if (currentlyWishlisted) {
        await Supabase.instance.client
            .from('wishlists')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', productId);
        _wishlistProductIds.remove(productId);
        _wishlistProducts.removeWhere((p) => p.id == productId);
      } else {
        await Supabase.instance.client.from('wishlists').insert({
          'user_id': user.id,
          'product_id': productId,
        });
        _wishlistProductIds.add(productId);
        _wishlistProducts.add(product);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
    }
  }
}
