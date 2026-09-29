import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../models/product.dart';
import '../core/constants.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../screens/product_detail_screen.dart';
import 'heart_bubble.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  String getImageUrl(dynamic path) {
    if (path == null) return '';
    final pathString = path.toString();
    if (pathString.isEmpty) return '';
    if (pathString.startsWith('http')) return pathString;
    
    // Fix: Remove leading slashes if they exist in the DB path
    final cleanPath = pathString.startsWith('/') ? pathString.substring(1) : pathString;
    
    final url = Supabase.instance.client.storage
        .from(AppConstants.bucketName)
        .getPublicUrl(cleanPath);
    
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Hero(
                      tag: 'product-${product.id}',
                      child: product.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: getImageUrl(product.imageUrl!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, size: 50, color: Colors.grey),
                            ),
                    ),
                  ),
                  if (product.mrp != null && product.mrp! > product.price)
                    Positioned(
                      top: 8,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: Colors.green,
                        child: Text(
                          '${((product.mrp! - product.price) / product.mrp! * 100).round()}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Consumer<WishlistProvider>(
                    builder: (context, wishlist, child) {
                      final isLiked = wishlist.isWishlisted(product.id);
                      return Positioned(
                        top: 4,
                        right: 4,
                        child: Builder(
                          builder: (iconContext) => GestureDetector(
                            onTap: () {
                              final wasLiked = wishlist.isWishlisted(product.id);
                              wishlist.toggleWishlist(product);
                              showHeartBubble(iconContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(wasLiked ? 'Removed from wishlist' : 'Added to wishlist'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Theme.of(context).colorScheme.primary : Colors.grey,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (product.mrp != null)
                        Text(
                          '₹${product.mrp!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const Spacer(),
                      Consumer<CartProvider>(
                        builder: (context, cart, child) {
                          final isInCart = cart.items.containsKey(product.id);
                          return GestureDetector(
                            onTap: () {
                              if (product.stock > 0) {
                                if (isInCart) {
                                  cart.removeItem(product.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Removed from cart'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                } else {
                                  cart.addItem(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Added to cart'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isInCart
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isInCart
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isInCart
                                    ? LucideIcons.shopping_cart
                                    : LucideIcons.shopping_cart,
                                color: isInCart ? Colors.white : Colors.grey.shade600,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.stock > 0 ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                      fontSize: 12,
                      color: product.stock > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
