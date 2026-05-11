import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/location_picker.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  String selectedPayment = 'upi';
  String? _selectedAddressId;
  bool _isPlacingOrder = false;

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LocationPicker(),
      ),
    );
    if (result == null || !mounted) return;
    final address = await ref.read(addressProvider.notifier).addAddress({
      'label': 'OTHER',
      'full_address': result.address,
      'landmark': result.address,
      'latitude': result.location.latitude,
      'longitude': result.location.longitude,
      'is_default': true,
      'flat_number': '',
      'contact_name': '',
      'contact_phone': '',
    });
    setState(() => _selectedAddressId = address.id);
  }

  Future<void> _placeOrder() async {
    final addresses = ref.read(addressProvider).valueOrNull ?? [];
    String? defaultAddressId;
    for (final address in addresses) {
      if (address.isDefault) {
        defaultAddressId = address.id;
        break;
      }
    }
    final addressId =
        _selectedAddressId ?? defaultAddressId ?? (addresses.isNotEmpty ? addresses.first.id : null);
    if (addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery location')),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      await ref.read(ordersProvider.notifier).placeOrder(
            addressId: addressId,
            paymentMethod: selectedPayment,
          );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final cartAsync = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Your Cart', style: TextStyle(fontSize: R.sp(5.0)))),
      body: cartAsync.when(
        data: (cart) {
          if (!cart.hasItems) {
            return const Center(child: Text('Your cart is empty'));
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.0)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...cart.items.map(_buildCartItem),
                      SizedBox(height: R.hp(2.5)),
                      Text('Delivery Address',
                          style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600)),
                      SizedBox(height: R.hp(1.5)),
                      addressesAsync.when(
                        data: (addresses) => _AddressSelector(
                          addresses: addresses,
                          selectedAddressId: _selectedAddressId,
                          onChanged: (id) => setState(() => _selectedAddressId = id),
                          onPickLocation: _pickLocation,
                        ),
                        error: (error, _) => Text(error.toString()),
                        loading: () => const LinearProgressIndicator(),
                      ),
                      SizedBox(height: R.hp(2.5)),
                      Text('Payment Options',
                          style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600)),
                      SizedBox(height: R.hp(1.5)),
                      GestureDetector(
                        onTap: () => setState(() => selectedPayment = 'upi'),
                        child: _buildPaymentTile('UPI (GPay, PhonePe)', Icons.account_balance_wallet, selectedPayment == 'upi'),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => selectedPayment = 'cash'),
                        child: _buildPaymentTile('Cash on Delivery', Icons.money, selectedPayment == 'cash'),
                      ),
                      SizedBox(height: R.hp(2.5)),
                      Text('Bill Details',
                          style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600)),
                      SizedBox(height: R.hp(1.5)),
                      _buildBillRow('Item Total', '₹ ${cart.subtotal.toStringAsFixed(0)}'),
                      _buildBillRow('Delivery Fee', '₹ ${cart.deliveryFee.toStringAsFixed(0)}'),
                      Divider(height: R.hp(3.0)),
                      _buildBillRow('Total Pay', '₹ ${cart.grandTotal.toStringAsFixed(0)}', isTotal: true),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.0)),
                  child: SizedBox(
                    width: double.infinity,
                    height: R.hp(7.5),
                    child: ElevatedButton(
                      onPressed: _isPlacingOrder ? null : _placeOrder,
                      child: _isPlacingOrder
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Confirm Order  ₹ ${cart.grandTotal.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildCartItem(CartItemModel item) {
    return Container(
      height: R.hp(9.0),
      margin: EdgeInsets.only(bottom: R.hp(1.5)),
      padding: EdgeInsets.symmetric(horizontal: R.wp(4.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('${item.quantity} x ${item.name}',
                style: TextStyle(fontSize: R.sp(4.2), fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => ref.read(cartProvider.notifier).updateQuantity(
                  item.menuItemId,
                  item.quantity > 1 ? item.quantity - 1 : 0,
                ),
          ),
          Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => ref
                .read(cartProvider.notifier)
                .updateQuantity(item.menuItemId, item.quantity + 1),
          ),
          Text('₹ ${item.itemTotal.toStringAsFixed(0)}',
              style: TextStyle(fontSize: R.sp(4.2), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(String title, IconData icon, bool selected) {
    return Container(
      height: R.hp(9.5),
      margin: EdgeInsets.only(bottom: R.hp(1.5)),
      padding: EdgeInsets.symmetric(horizontal: R.wp(4.0)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, width: selected ? 2 : 1),
        color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(icon, size: R.wp(6.5), color: selected ? Theme.of(context).colorScheme.primary : AppTheme.greyColor),
          SizedBox(width: R.wp(3.0)),
          Expanded(child: Text(title, style: TextStyle(fontSize: R.sp(4.5), fontWeight: selected ? FontWeight.bold : FontWeight.normal))),
          if (selected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: R.wp(6.5)),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: R.hp(0.8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? R.sp(5.5) : R.sp(4.0), fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isTotal ? R.sp(5.5) : R.sp(4.0), fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? Theme.of(context).colorScheme.primary : AppTheme.textColor)),
        ],
      ),
    );
  }
}

class _AddressSelector extends StatelessWidget {
  final List<AddressModel> addresses;
  final String? selectedAddressId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onPickLocation;

  const _AddressSelector({
    required this.addresses,
    required this.selectedAddressId,
    required this.onChanged,
    required this.onPickLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (addresses.isNotEmpty)
          DropdownButtonFormField<String>(
            value: selectedAddressId ?? addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first).id,
            items: addresses
                .map((address) => DropdownMenuItem(
                      value: address.id,
                      child: Text(address.fullAddress, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        OutlinedButton.icon(
          onPressed: onPickLocation,
          icon: const Icon(Icons.map),
          label: Text(addresses.isEmpty ? 'Choose on map' : 'Add another location'),
        ),
      ],
    );
  }
}
