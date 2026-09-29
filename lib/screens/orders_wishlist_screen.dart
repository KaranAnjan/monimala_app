import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../core/constants.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';

class OrdersWishlistScreen extends StatefulWidget {
  const OrdersWishlistScreen({super.key});

  @override
  State<OrdersWishlistScreen> createState() => _OrdersWishlistScreenState();
}

class _OrdersWishlistScreenState extends State<OrdersWishlistScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  int _activeTab = 0; // 0 for Orders, 1 for Wishlist

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Load Orders
      final ordersData = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*, products(*))')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      // 2. Refresh Wishlist
      if (mounted) {
        context.read<WishlistProvider>().fetchWishlist();
      }

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(ordersData);
        });
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wishlist = context.watch<WishlistProvider>();

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Activity')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.package, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Login to view your orders & wishlist', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) => _loadData()),
                child: const Text('Login / Sign Up'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders & Wishlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: Column(
        children: [
          // Tab Switcher
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 0 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.package, size: 18, color: _activeTab == 0 ? Colors.white : Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Orders',
                              style: TextStyle(
                                color: _activeTab == 0 ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.heart, size: 18, color: _activeTab == 1 ? Colors.white : Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Wishlist',
                              style: TextStyle(
                                color: _activeTab == 1 ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _activeTab == 0 ? _buildOrdersList() : _buildWishlist(wishlist),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return _buildEmptyState(LucideIcons.shopping_bag, 'No orders yet');
    }
    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildWishlist(WishlistProvider wishlist) {
    if (wishlist.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (wishlist.wishlistProducts.isEmpty) {
      return _buildEmptyState(LucideIcons.heart, 'Your wishlist is empty');
    }
    return ListView.builder(
      itemCount: wishlist.wishlistProducts.length,
      itemBuilder: (context, index) {
        final product = wishlist.wishlistProducts[index];
        return _buildWishlistItem(product, wishlist);
      },
    );
  }

  Widget _buildWishlistItem(dynamic product, WishlistProvider wishlist) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: product.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  _getImageUrl(product.imageUrl),
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(LucideIcons.package, size: 24, color: Colors.grey),
        ),
        title: Text(
          product.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text("₹${product.price}", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(LucideIcons.shopping_cart, size: 20, color: Theme.of(context).colorScheme.primary),
                onPressed: () {
                  context.read<CartProvider>().addItem(product);
                  wishlist.toggleWishlist(product);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to cart'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.primary),
              onPressed: () => wishlist.toggleWishlist(product),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final dateString = order['created_at']?.toString() ?? '';
    final date = dateString.isNotEmpty ? DateTime.parse(dateString).toLocal() : DateTime.now();
    
    final idString = order['id'].toString();
    final orderNumber = order['order_number']?.toString() ?? 
        "#${idString.length > 8 ? idString.substring(0, 8) : idString}";
    
    final status = (order['delivery_status'] ?? order['status'] ?? 'pending').toString().toLowerCase();
    
    Color statusColor = Colors.orange;
    IconData statusIcon = LucideIcons.clock;

    if (status == 'delivered') {
      statusColor = Colors.green;
      statusIcon = LucideIcons.circle_check;
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
      statusIcon = LucideIcons.circle_x;
    } else if (status == 'shipped') {
      statusColor = Colors.blue;
      statusIcon = LucideIcons.truck;
    } else if (status == 'out_for_delivery') {
      statusColor = Colors.purple;
      statusIcon = LucideIcons.bike;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor, size: 24),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(
              "${date.day}/${date.month}/${date.year}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "₹${order['total_amount']}",
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...((order['order_items'] as List?) ?? []).map((item) {
                  final product = item['products'] ?? {};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: product['image_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  _getImageUrl(product['image_url']),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(LucideIcons.package, size: 20, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['product_name'] ?? 'Product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                "Qty: ${item['quantity']} | ₹${item['price']}",
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getImageUrl(dynamic path) {
    if (path == null) return '';
    final pathString = path.toString();
    if (pathString.isEmpty) return '';
    if (pathString.startsWith('http')) return pathString;
    final cleanPath = pathString.startsWith('/') ? pathString.substring(1) : pathString;
    return Supabase.instance.client.storage
        .from(AppConstants.bucketName)
        .getPublicUrl(cleanPath);
  }
}
