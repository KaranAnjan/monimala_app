import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import 'login_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _showCheckout = false;
  bool _isPlacingOrder = false;
  bool _isEditingAddress = false;
  Map<String, dynamic>? _savedAddress;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  String? _selectedState;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        
        if (data != null && mounted) {
          setState(() {
            _savedAddress = data;
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _addressController.text = data['address'] ?? '';
            _cityController.text = data['city'] ?? '';
            _selectedState = data['state'];
            _pincodeController.text = data['pincode']?.toString() ?? '';
            
            if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
              _isEditingAddress = true;
            } else {
              _isEditingAddress = false;
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  String getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage
        .from(AppConstants.bucketName)
        .getPublicUrl(path);
  }

  void _launchWhatsApp(CartProvider cart) async {
    if (cart.items.isEmpty) return;

    String message = "Hi, I want to order:\n\n";
    for (var item in cart.items.values) {
      message += "${item.product.productName} x${item.quantity} - Rs.${(item.product.price * item.quantity).toStringAsFixed(0)}\n";
    }
    message += "\nTotal: Rs.${cart.totalAmount.toStringAsFixed(0)}";

    final phone = AppConstants.contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final whatsappUrl = Uri.parse("whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
        await launchUrl(whatsappUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch WhatsApp")),
        );
      }
    }
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_isEditingAddress) {
      if (!_formKey.currentState!.validate()) return;
      if (_selectedState == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a state')));
        return;
      }
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isPlacingOrder = true);

    try {
      // 1. Update user profile
      await Supabase.instance.client.from('users').upsert({
        'id': user.id,
        'email': user.email ?? '',
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state': _selectedState,
        'pincode': _pincodeController.text,
        'is_active': true,
      });

      // 2. Create order
      final fullAddress = "${_addressController.text}, ${_cityController.text}, $_selectedState - ${_pincodeController.text}";
      
      final orderResponse = await Supabase.instance.client.from('orders').insert({
        'user_id': user.id,
        'total_amount': cart.totalAmount,
        'status': 'pending',
        'delivery_status': 'pending',
        'customer_name': _nameController.text,
        'customer_address': fullAddress,
        'customer_pincode': _pincodeController.text,
      }).select().single();

      final orderId = orderResponse['id'];

      // 3. Create order items
      final orderItems = cart.items.values.map((item) => {
        'order_id': orderId,
        'product_id': item.product.id,
        'quantity': item.quantity,
        'price': item.product.price,
      }).toList();

      await Supabase.instance.client.from('order_items').insert(orderItems);

      if (mounted) {
        final displayOrderNum = orderResponse['order_number']?.toString() ?? orderId.toString().substring(0, 8);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $displayOrderNum placed successfully! (COD)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        cart.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_showCheckout ? 'Order Summary' : 'My Cart'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_showCheckout) {
              setState(() => _showCheckout = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.shopping_cart, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Your cart is empty!', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue Shopping'),
                  ),
                ],
              ),
            )
          : _showCheckout ? _buildCheckoutView(cart) : _buildCartView(cart, auth),
    );
  }

  Widget _buildCartView(CartProvider cart, AuthProvider auth) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items.values.toList()[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: item.product.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: getImageUrl(item.product.imageUrl!),
                                fit: BoxFit.contain,
                              )
                            : const Icon(Icons.image),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.productName,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '₹${item.product.price.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              if (item.product.mrp != null)
                                Text(
                                  '₹${item.product.mrp!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildQtyBtn(
                                icon: LucideIcons.minus,
                                onPressed: () => cart.removeSingleItem(item.product.id),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              _buildQtyBtn(
                                icon: LucideIcons.plus,
                                onPressed: () => cart.addItem(item.product),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => cart.removeItem(item.product.id),
                                child: const Text('REMOVE', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('₹${cart.totalAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchWhatsApp(cart),
                        icon: const Icon(LucideIcons.message_circle, size: 18),
                        label: const Text('WHATSAPP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!auth.isAuthenticated) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                          } else {
                            setState(() => _showCheckout = true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          elevation: 0,
                        ),
                        child: const Text('CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CONTINUE SHOPPING', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQtyBtn({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }

  Widget _buildCheckoutView(CartProvider cart) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Delivery Address Card
                _isEditingAddress ? _buildAddressForm() : _buildAddressSummary(),
                
                const SizedBox(height: 8),
                
                // Item List Summary
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      ...cart.items.values.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("${item.product.productName} (x${item.quantity})", maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('₹${(item.product.price * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹${cart.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Payment Info
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.radio_button_checked, color: Colors.blue),
                          SizedBox(width: 12),
                          Text('Cash on Delivery (COD)', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('₹${cart.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isPlacingOrder ? null : () => _placeOrder(cart),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    elevation: 0,
                  ),
                  child: _isPlacingOrder 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('PLACE ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSummary() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Deliver to:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              OutlinedButton(
                onPressed: () => setState(() => _isEditingAddress = true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
                child: Text('CHANGE', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_nameController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            "${_addressController.text}, ${_cityController.text}, $_selectedState - ${_pincodeController.text}",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(_phoneController.text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAddressForm() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pincodeController,
              decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
              maxLines: 2,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedState,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    items: AppConstants.indianStates.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _selectedState = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_nameController.text.isNotEmpty && _addressController.text.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() => _isEditingAddress = false),
                  child: Text('CANCEL', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
