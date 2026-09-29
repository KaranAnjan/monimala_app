import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select()
          .order('category_name');

      _categories = (data as List).map((json) => Category.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchProducts({String? categoryId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure categories are loaded first if needed
      if (_categories.isEmpty) await fetchCategories();

      var query = Supabase.instance.client
          .from('products')
          .select('*, categories(category_name)');

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final data = await query.order('created_at', ascending: false);
      _products = (data as List).map((json) => Product.fromJson(json)).toList();
      debugPrint('Fetched ${_products.length} products');
    } catch (e) {
      debugPrint('Fetch Error: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> fetchProductById(String id) async {
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select('*, categories(category_name)')
          .eq('id', id)
          .single();
      return Product.fromJson(data);
    } catch (e) {
      return null;
    }
  }
}
