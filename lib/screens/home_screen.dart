import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/cart_icon_with_badge.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'product_detail_screen.dart';
import 'orders_wishlist_screen.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../core/constants.dart';

// Shared Helper Functions
String _getCategoryEmoji(String name) {
  final lowerName = name.toLowerCase();
  if (lowerName.contains('jewel')) return '💍';
  if (lowerName.contains('gift')) return '🎁';
  if (lowerName.contains('cosmetic')) return '💄';
  if (lowerName.contains('special')) return '✨';
  if (lowerName.contains('home')) return '🏠';
  if (lowerName.contains('fashion')) return '👕';
  if (lowerName.contains('all')) return '🛍️';
  return '📦';
}

String _toSentenceCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _searchTerm = '';
  String? _homeSelectedCategoryId;
  final GlobalKey<NavigatorState> _categoriesNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ProductProvider>().fetchCategories();
      context.read<ProductProvider>().fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // 1. Handle nested navigation in Categories tab
        if (_currentIndex == 1) {
          final navigator = _categoriesNavigatorKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
            return;
          }
        }

        // 2. If not on Home tab, always go back to Home tab first
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          // 3. If already on Home tab, exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: _currentIndex == 1 || _currentIndex == 2 ? null : AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo_white.png',
                height: 35,
                errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.store),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monimala',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  Text(
                    'Fashion Jewellery',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: const [CartIconWithBadge()],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeContent(
              searchTerm: _searchTerm,
              selectedCategoryId: _homeSelectedCategoryId,
              onSearchChanged: (value) => setState(() => _searchTerm = value),
              onCategorySelected: (id) => setState(() => _homeSelectedCategoryId = id),
            ),
            CategoriesTabNavigator(
              navigatorKey: _categoriesNavigatorKey,
            ),
            const OrdersWishlistScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.house), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.layout_grid), label: 'Categories'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.package), label: 'Activity'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Account'),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final String searchTerm;
  final String? selectedCategoryId;
  final Function(String) onSearchChanged;
  final Function(String?) onCategorySelected;

  const HomeContent({
    super.key,
    required this.searchTerm,
    required this.selectedCategoryId,
    required this.onSearchChanged,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<ProductProvider>().fetchCategories();
        await context.read<ProductProvider>().fetchProducts();
      },
      child: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search for products',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    icon: Icon(LucideIcons.search, color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ),
          ),

          // Categories Horizontal Scroll
          SliverToBoxAdapter(
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.categories.isEmpty) return const SizedBox.shrink();
                return Container(
                  height: 120,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildCategoryItem(
                          context,
                          id: null,
                          name: 'All',
                          isSelected: selectedCategoryId == null,
                        );
                      }
                      final category = provider.categories[index - 1];
                      return _buildCategoryItem(
                        context,
                        id: category.id,
                        name: category.categoryName,
                        isSelected: selectedCategoryId == category.id,
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Featured Products Slider
          SliverToBoxAdapter(
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading || provider.products.isEmpty) return const SizedBox.shrink();
                
                final Map<String, Product> highlightedProductsMap = {};
                for (var product in provider.products) {
                  if (product.categoryId != null && !highlightedProductsMap.containsKey(product.categoryId)) {
                    highlightedProductsMap[product.categoryId!] = product;
                  }
                }
                final highlightedProducts = highlightedProductsMap.values.toList();
                
                return FeaturedProductSlider(products: highlightedProducts);
              },
            ),
          ),

          // Products Grid
          Consumer<ProductProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      childCount: 6,
                    ),
                  ),
                );
              }

              final filteredProducts = provider.products.where((p) {
                final matchesSearch = p.productName.toLowerCase().contains(searchTerm.toLowerCase()) ||
                    p.productCode.toLowerCase().contains(searchTerm.toLowerCase());
                final matchesCategory = selectedCategoryId == null || p.categoryId == selectedCategoryId;
                return matchesSearch && matchesCategory;
              }).toList();

              return SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ProductCard(product: filteredProducts[index]),
                    childCount: filteredProducts.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, {required String? id, required String name, required bool isSelected}) {
    final displayName = _toSentenceCase(name);
    return GestureDetector(
      onTap: () => onCategorySelected(id),
      child: Container(
        width: 90,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200]!,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Center(
                child: Text(_getCategoryEmoji(name), style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeaturedProductSlider extends StatefulWidget {
  final List<Product> products;
  const FeaturedProductSlider({super.key, required this.products});

  @override
  State<FeaturedProductSlider> createState() => _FeaturedProductSliderState();
}

class _FeaturedProductSliderState extends State<FeaturedProductSlider> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        if (_currentPage < widget.products.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          _currentPage = index;
        },
        itemCount: widget.products.length,
        itemBuilder: (context, index) {
          final product = widget.products[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: _getImageUrl(product.imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => const Icon(Icons.image, size: 50),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.categoryName?.toUpperCase() ?? 'FEATURED',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.productName,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Consumer<WishlistProvider>(
                      builder: (context, wishlist, child) {
                        final isLiked = wishlist.isWishlisted(product.id);
                        return Positioned(
                          top: 15,
                          right: 15,
                          child: GestureDetector(
                            onTap: () => wishlist.toggleWishlist(product),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Theme.of(context).colorScheme.primary : Colors.grey,
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoriesTabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const CategoriesTabNavigator({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) {
            if (settings.name == '/products') {
              final categoryId = settings.arguments as String;
              return CategoryProductsScreen(categoryId: categoryId);
            }
            return const CategoriesGridScreen();
          },
        );
      },
    );
  }
}

class CategoriesGridScreen extends StatelessWidget {
  const CategoriesGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_white.png',
              height: 30,
              errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.layout_grid),
            ),
            const SizedBox(width: 10),
            const Text('Shop by Category', style: TextStyle(fontSize: 18)),
          ],
        ),
        centerTitle: false,
        actions: const [CartIconWithBadge()],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.categories.isEmpty) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final category = provider.categories[index];
              return _buildCategoryBanner(context, category);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryBanner(BuildContext context, Category category) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/products', arguments: category.id),
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.2,
                child: Text(
                  _getCategoryEmoji(category.categoryName),
                  style: const TextStyle(fontSize: 100),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getCategoryEmoji(category.categoryName),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _toSentenceCase(category.categoryName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View Collection',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 18,
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

class CategoryProductsScreen extends StatelessWidget {
  final String categoryId;
  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: const [CartIconWithBadge()],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final products = provider.products.where((p) => p.categoryId == categoryId).toList();
          if (products.isEmpty) return const Center(child: Text('No products found in this category.'));
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => ProductCard(product: products[index]),
          );
        },
      ),
    );
  }
}
