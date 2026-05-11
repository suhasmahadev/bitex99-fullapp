import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../providers/user_provider.dart';
import '../../services/menu_service.dart';
import '../../services/upload_service.dart';
import '../../models/models.dart';
import 'restaurant_main.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class MenuManagement extends StatefulWidget {
  final bool isStandalone;
  const MenuManagement({super.key, this.isStandalone = false});

  @override
  State<MenuManagement> createState() => _MenuManagementState();
}

class _MenuManagementState extends State<MenuManagement> {
  List<MenuItemModel> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMenu();
    });
  }

  Future<void> _loadMenu() async {
    try {
      final userProv = Provider.of<UserProvider>(context, listen: false);
      final restaurantId = userProv.phone;
      final menu = await MenuService().getMenuForRestaurant(restaurantId);
      if (mounted) {
        setState(() {
          _menuItems = menu;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RestaurantMain()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final userProv = Provider.of<UserProvider>(context);
    final restaurantId = userProv.phone;

    return PopScope(
      canPop: !widget.isStandalone,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (widget.isStandalone) {
          _goToDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(R.hp(8.0)),
          child: AppBar(
            toolbarHeight: R.hp(8.0),
            backgroundColor: Colors.black,
            leading: widget.isStandalone
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _goToDashboard,
                  )
                : null,
            title: Text('Menu Management', style: TextStyle(fontSize: R.sp(5.0), color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(Icons.add_circle_outline, size: R.wp(6.5), color: Colors.white),
                onPressed: () => _showAddItemDialog(restaurantId),
              ),
            ],
          ),
        ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
        : Builder(
            builder: (context) {
              if (_menuItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: R.wp(15.0), color: Colors.grey.shade300),
                      SizedBox(height: R.hp(2.0)),
                      Text('Your menu is empty', style: TextStyle(fontSize: R.sp(4.5), color: Colors.grey)),
                      SizedBox(height: R.hp(1.0)),
                      TextButton(
                        onPressed: () => _showAddItemDialog(restaurantId),
                        child: Text('Add your first item', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      ),
                    ],
                  ),
                );
              }

              // Group items by category
              Map<String, List<MenuItemModel>> categorizedItems = {};
              for (var item in _menuItems) {
                categorizedItems.putIfAbsent(item.category, () => []).add(item);
              }

              return ListView.builder(
                padding: EdgeInsets.only(bottom: R.hp(10.0)),
                itemCount: categorizedItems.length,
                itemBuilder: (context, index) {
                  String category = categorizedItems.keys.elementAt(index);
                  List<MenuItemModel> categoryItems = categorizedItems[category]!;
                  return _buildCategorySection(restaurantId, category, categoryItems);
                },
              );
            },
          ),
    ),
    );
  }

  Widget _buildCategorySection(String restaurantId, String category, List<MenuItemModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(R.wp(5.0), R.hp(2.5), R.wp(5.0), R.hp(1.0)),
          child: Text(
            category.toUpperCase(),
            style: TextStyle(
              fontSize: R.sp(3.8),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildMenuItemCard(restaurantId, items[index]);
          },
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(String restaurantId, MenuItemModel item) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(0.8)),
      padding: EdgeInsets.all(R.wp(4.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: item.isVeg ? Colors.green : Colors.red,
                      size: R.wp(3.5),
                    ),
                    SizedBox(width: R.wp(1.5)),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(fontSize: R.sp(4.2), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: R.hp(0.5)),
                Text(
                  '₹ ${item.price.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: R.sp(4.0), fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                ),
                if (item.description.isNotEmpty) ...[
                  SizedBox(height: R.hp(0.8)),
                  Text(
                    item.description,
                    style: TextStyle(fontSize: R.sp(3.5), color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: R.wp(4.0)),
          // Toggle and Action
          Column(
            children: [
              Switch(
                value: item.isAvailable,
                onChanged: (val) async {
                  await MenuService().updateMenuItem(restaurantId, item.id, {'available': val});
                  _loadMenu();
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
              Text(
                item.isAvailable ? 'Available' : 'Sold Out',
                style: TextStyle(
                  fontSize: R.sp(3.0),
                  color: item.isAvailable ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: R.wp(5.0)),
                onPressed: () async {
                  await MenuService().deleteMenuItem(restaurantId, item.id);
                  _loadMenu();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(String restaurantId) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController();
    bool isVeg = true;
    Uint8List? imageBytes;
    String imageName = '';
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(4.0))),
            title: Text('Add New Item', style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Item Name *', hintText: 'e.g. Paneer Tikka'),
                  ),
                  SizedBox(height: R.hp(1.5)),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final xFile = await picker.pickImage(source: ImageSource.gallery);
                      if (xFile != null) {
                        final bytes = await xFile.readAsBytes();
                        setDialogState(() {
                          imageBytes = bytes;
                          imageName = xFile.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(imageBytes == null ? 'Upload Image' : 'Image Selected'),
                  ),
                  SizedBox(height: R.hp(1.5)),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (₹) *', hintText: 'e.g. 250'),
                  ),
                  SizedBox(height: R.hp(1.5)),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category *', hintText: 'e.g. Starters, Main Course'),
                  ),
                  SizedBox(height: R.hp(1.5)),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'Short description'),
                    maxLines: 2,
                  ),
                  SizedBox(height: R.hp(2.0)),
                  Row(
                    children: [
                      Text('Veg / Non-Veg:', style: TextStyle(fontSize: R.sp(4.0))),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('Veg'),
                        selected: isVeg,
                        onSelected: (val) => setDialogState(() => isVeg = true),
                        selectedColor: Colors.green.shade100,
                        labelStyle: TextStyle(color: isVeg ? Colors.green.shade900 : Colors.black),
                      ),
                      SizedBox(width: R.wp(2.0)),
                      ChoiceChip(
                        label: const Text('Non-Veg'),
                        selected: !isVeg,
                        onSelected: (val) => setDialogState(() => isVeg = false),
                        selectedColor: Colors.red.shade100,
                        labelStyle: TextStyle(color: !isVeg ? Colors.red.shade900 : Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isUploading ? null : () async {
                  if (nameController.text.isNotEmpty &&
                      priceController.text.isNotEmpty &&
                      categoryController.text.isNotEmpty) {
                    
                    setDialogState(() => isUploading = true);
                    
                    String imageUrl = '';
                    if (imageBytes != null) {
                      imageUrl = await UploadService().uploadImage(imageBytes!, imageName, type: 'menu');
                    }

                    await MenuService().addMenuItem(restaurantId, {
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'price': double.tryParse(priceController.text) ?? 0.0,
                      'category': categoryController.text.trim(),
                      'available': true,
                      'imageUrl': imageUrl,
                      'isSpecial': false,
                      'preparationTime': 15,
                      'isVeg': isVeg,
                    });
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadMenu();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                child: isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Add Item', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}


