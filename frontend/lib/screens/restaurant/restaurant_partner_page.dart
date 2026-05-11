import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../../utils/responsive.dart';
import '../../models/models.dart';
import '../../services/restaurant_service.dart';
import '../../services/upload_service.dart';
import '../../core/token_storage.dart';
import '../../providers/user_provider.dart';
import '../onboarding/login_screen.dart';
import 'restaurant_waiting_screen.dart';

// ─────────────────────────────────────────────────────────
// Provider — Partner Form State
// ─────────────────────────────────────────────────────────
class PartnerFormProvider extends ChangeNotifier {
  int currentStep = 0;
  bool isLoading = false;
  bool isSubmitted = false;

  // Step 1 — Basic Info
  String restaurantName = '';
  String ownerName = '';
  String location = '';
  String phone = '';

  // Step 2 — Restaurant Details
  String email = '';
  String address = '';
  String cuisineType = '';
  List<String> cuisineTypes = [];
  String fssaiNumber = '';

  // Step 3 — Media
  Uint8List? imageBytes;
  String? imageName;

  final List<String> cuisineOptions = [
    'South Indian',
    'North Indian',
    'Chinese',
    'Biryani',
    'Fast Food',
    'Bakery & Sweets',
    'Beverages',
    'Multi-Cuisine',
    'Other',
  ];

  void nextStep() {
    if (currentStep < 2) {
      currentStep++;
      notifyListeners();
    }
  }

  void prevStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  void goTo(int step) {
    currentStep = step;
    notifyListeners();
  }

  /// Picks an image using image_picker (works on web + mobile).
  /// Stores bytes in-memory as Uint8List for universal compatibility.
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? xFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // slight compression
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (xFile == null) return;

      // Read as bytes — works on both web (no File path) and mobile
      final bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('⚠️ Image bytes are empty');
        return;
      }

      imageBytes = Uint8List.fromList(bytes);
      imageName = xFile.name;
      notifyListeners();
    } catch (e) {
      debugPrint('⛔ Image pick error: $e');
    }
  }

  Future<bool> submit(BuildContext context) async {
    // 1. Validate required fields
    if (restaurantName.trim().isEmpty || 
        ownerName.trim().isEmpty || 
        phone.trim().isEmpty || 
        location.trim().isEmpty ||
        email.trim().isEmpty ||
        address.trim().isEmpty ||
        fssaiNumber.trim().isEmpty ||
        cuisineTypes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields before submitting.'), backgroundColor: Colors.red),
        );
      }
      return false;
    }

    if (isLoading) return false; // Prevent multiple clicks

    isLoading = true;
    notifyListeners();

    try {
      // Get User ID
      final userProv = Provider.of<UserProvider>(context, listen: false);
      String uid = userProv.phone;
      
      // Fallback if provider state was lost during reload
      if (uid.isEmpty) {
        uid = 'demo_user_1234567890'; // fallback for demo
      }

      String imageUrl = '';
      if (imageBytes != null) {
        imageUrl = await UploadService().uploadImage(
          imageBytes!, imageName ?? 'image.jpg', type: 'restaurant');
      }

      final newRestaurant = await RestaurantService().registerRestaurant({
        'shopName': restaurantName.trim(),
        'ownerName': ownerName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'town': location.trim(),
        'address': address.trim(),
        'cuisineType': cuisineTypes.first,
        'cuisineTypes': cuisineTypes,
        'fssaiNumber': fssaiNumber.trim(),
        'status': 'pending',
        'restaurantImageUrl': imageUrl,
      });

      debugPrint('Restaurant registered successfully');

      isLoading = false;
      isSubmitted = true;
      notifyListeners();
      
      // Navigate to waiting screen using pushReplacement so they can't go back to the form easily
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RestaurantWaitingScreen(restaurant: newRestaurant)),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error submitting restaurant: $e');
      isLoading = false;
      notifyListeners();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit application: ${e.toString().replaceAll('Exception: ', '')}'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
  }

  void reset() {
    currentStep = 0;
    isLoading = false;
    isSubmitted = false;
    restaurantName = '';
    ownerName = '';
    location = '';
    phone = '';
    email = '';
    address = '';
    cuisineType = '';
    cuisineTypes = [];
    fssaiNumber = '';
    imageBytes = null;
    imageName = null;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────
const _zomato = Color(0xFF00A651);
const _zomaLight = Color(0xFFE8F5E9);
const _grey = Color(0xFF757575);
const _border = Color(0xFFE0E0E0);

// ─────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────
class RestaurantPartnerPage extends StatelessWidget {
  const RestaurantPartnerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PartnerFormProvider(),
      child: const _RestaurantPartnerView(),
    );
  }
}

class _RestaurantPartnerView extends StatelessWidget {
  const _RestaurantPartnerView();

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final provider = context.watch<PartnerFormProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: provider.isSubmitted
          ? _SuccessView(onReset: () => provider.reset())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _HeroSection(),
                  _StepperHeader(currentStep: provider.currentStep),
                  _FormBody(provider: provider),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HERO SECTION
// ─────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  Future<void> _backToLogin(BuildContext context) async {
    await TokenStorage.clearAll();
    if (!context.mounted) return;
    context.read<UserProvider>().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(town: '')),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(R.wp(6.0), R.hp(6.0), R.wp(6.0), R.hp(5.0)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_zomato, Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => _backToLogin(context),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: R.wp(3.0), vertical: R.hp(1.0)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(R.wp(2.0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: R.wp(4.0)),
                  Text('Back',
                      style:
                          TextStyle(color: Colors.white, fontSize: R.sp(3.5))),
                ],
              ),
            ),
          ),
          SizedBox(height: R.hp(3.0)),
          // Badge
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: R.wp(3.0), vertical: R.hp(0.8)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant, color: Colors.white, size: R.wp(4.5)),
                SizedBox(width: R.wp(2.0)),
                Text(
                  'Restaurant Partner Program',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: R.sp(3.2),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          SizedBox(height: R.hp(2.0)),
          Text(
            'Partner with Us',
            style: TextStyle(
              color: Colors.white,
              fontSize: R.sp(8.5),
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          SizedBox(height: R.hp(1.0)),
          Text(
            'Grow your restaurant business with us.\nReach thousands of hungry customers in your town.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: R.sp(4.0),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: R.hp(3.0)),
          // Stats row
          Row(
            children: [
              _statBadge('10,000+', 'Restaurants'),
              SizedBox(width: R.wp(4.0)),
              _statBadge('5 Lakh+', 'Orders/month'),
              SizedBox(width: R.wp(4.0)),
              _statBadge('Zero', 'Setup Fee'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: R.sp(4.5),
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.8), fontSize: R.sp(3.0))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// STEPPER HEADER
// ─────────────────────────────────────────────────────────
class _StepperHeader extends StatelessWidget {
  final int currentStep;
  const _StepperHeader({required this.currentStep});

  static const _steps = ['Basic Info', 'Details', 'Upload'];

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: R.hp(2.5), horizontal: R.wp(6.0)),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            int stepBefore = i ~/ 2;
            bool done = currentStep > stepBefore;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? _zomato : _border,
              ),
            );
          }
          final step = i ~/ 2;
          final done = currentStep > step;
          final active = currentStep == step;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: R.wp(9.0),
                height: R.wp(9.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? _zomato
                      : active
                          ? _zomaLight
                          : Colors.grey.shade100,
                  border: Border.all(
                    color: done || active ? _zomato : _border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check, color: Colors.white, size: R.wp(4.5))
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            color: active ? _zomato : _grey,
                            fontWeight: FontWeight.bold,
                            fontSize: R.sp(3.5),
                          ),
                        ),
                ),
              ),
              SizedBox(height: R.hp(0.5)),
              Text(
                _steps[step],
                style: TextStyle(
                  fontSize: R.sp(3.0),
                  color: active || done ? _zomato : _grey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// FORM BODY — dispatches to correct step
// ─────────────────────────────────────────────────────────
class _FormBody extends StatelessWidget {
  final PartnerFormProvider provider;
  const _FormBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                  .animate(anim),
          child: child,
        ),
      ),
      child: switch (provider.currentStep) {
        0 => _Step1(provider: provider, key: const ValueKey(0)),
        1 => _Step2(provider: provider, key: const ValueKey(1)),
        _ => _Step3(provider: provider, key: const ValueKey(2)),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// STEP 1 — Basic Info
// ─────────────────────────────────────────────────────────
class _Step1 extends StatefulWidget {
  final PartnerFormProvider provider;
  const _Step1({required this.provider, super.key});

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.provider.restaurantName);
  late final _ownerCtrl =
      TextEditingController(text: widget.provider.ownerName);
  late final _locCtrl = TextEditingController(text: widget.provider.location);
  late final _phoneCtrl = TextEditingController(text: widget.provider.phone);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _locCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      widget.provider.restaurantName = _nameCtrl.text.trim();
      widget.provider.ownerName = _ownerCtrl.text.trim();
      widget.provider.location = _locCtrl.text.trim();
      widget.provider.phone = _phoneCtrl.text.trim();
      widget.provider.nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return _StepCard(
      stepTitle: 'Basic Information',
      stepSubtitle: 'Tell us about your restaurant and you',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _PartnerField(
              controller: _nameCtrl,
              label: 'Restaurant Name',
              hint: 'e.g. Hotel Annapurna',
              icon: Icons.storefront_outlined,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Restaurant name is required' : null,
            ),
            SizedBox(height: R.hp(2.0)),
            _PartnerField(
              controller: _ownerCtrl,
              label: 'Owner Name',
              hint: 'Your full name',
              icon: Icons.person_outline,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Owner name is required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: R.hp(2.0)),
            _PartnerField(
              controller: _locCtrl,
              label: 'Location / City',
              hint: 'e.g. KR Nagar, Mysuru',
              icon: Icons.location_city_outlined,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Location is required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: R.hp(2.0)),
            _PartnerField(
              controller: _phoneCtrl,
              label: 'Phone Number',
              hint: '10-digit mobile number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixText: '+91  ',
              validator: (v) {
                if (v!.trim().isEmpty) return 'Phone number is required';
                if (v.trim().length != 10) return 'Enter valid 10-digit number';
                return null;
              },
            ),
            SizedBox(height: R.hp(3.5)),
            _PrimaryButton(
                label: 'Next: Restaurant Details',
                onTap: _next,
                icon: Icons.arrow_forward),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// STEP 2 — Restaurant Details
// ─────────────────────────────────────────────────────────
class _Step2 extends StatefulWidget {
  final PartnerFormProvider provider;
  const _Step2({required this.provider, super.key});

  @override
  State<_Step2> createState() => _Step2State();
}

class _Step2State extends State<_Step2> {
  final _formKey = GlobalKey<FormState>();
  late final _emailCtrl = TextEditingController(text: widget.provider.email);
  late final _addressCtrl =
      TextEditingController(text: widget.provider.address);
  late final _fssaiCtrl =
      TextEditingController(text: widget.provider.fssaiNumber);
  late final Set<String> _selectedCuisines;

  @override
  void initState() {
    super.initState();
    _selectedCuisines = {
      ...widget.provider.cuisineTypes,
      if (widget.provider.cuisineTypes.isEmpty &&
          widget.provider.cuisineType.isNotEmpty)
        ...widget.provider.cuisineType
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
    };
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _fssaiCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCuisines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one cuisine')),
        );
        return;
      }
      widget.provider.email = _emailCtrl.text.trim();
      widget.provider.address = _addressCtrl.text.trim();
      widget.provider.cuisineTypes = _selectedCuisines.toList();
      widget.provider.cuisineType = widget.provider.cuisineTypes.join(', ');
      widget.provider.fssaiNumber = _fssaiCtrl.text.trim();
      widget.provider.nextStep();
    }
  }

  void _toggleCuisine(String cuisine) {
    setState(() {
      if (_selectedCuisines.contains(cuisine)) {
        _selectedCuisines.remove(cuisine);
      } else {
        _selectedCuisines.add(cuisine);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return _StepCard(
      stepTitle: 'Restaurant Details',
      stepSubtitle: 'Help customers find and trust your restaurant',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _PartnerField(
              controller: _emailCtrl,
              label: 'Email Address',
              hint: 'business@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.trim().isEmpty) return 'Email is required';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim()))
                  return 'Enter a valid email';
                return null;
              },
            ),
            SizedBox(height: R.hp(2.0)),
            _PartnerField(
              controller: _addressCtrl,
              label: 'Restaurant Address',
              hint: 'Building, Street, Area, City',
              icon: Icons.location_on_outlined,
              maxLines: 3,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Address is required' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            SizedBox(height: R.hp(2.0)),
            // Cuisine Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Cuisine Types'),
                SizedBox(height: R.hp(0.8)),
                PopupMenuButton<String>(
                  onSelected: _toggleCuisine,
                  itemBuilder: (context) => widget.provider.cuisineOptions
                      .map(
                        (c) => CheckedPopupMenuItem<String>(
                          value: c,
                          checked: _selectedCuisines.contains(c),
                          child: Text(c),
                        ),
                      )
                      .toList(),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: R.hp(7.5)),
                    padding: EdgeInsets.symmetric(
                      horizontal: R.wp(4.0),
                      vertical: R.hp(1.6),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(R.wp(3.0)),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.restaurant_menu_outlined,
                            color: _grey, size: R.wp(5.5)),
                        SizedBox(width: R.wp(2.5)),
                        Expanded(
                          child: Text(
                            _selectedCuisines.isEmpty
                                ? 'Select cuisine types'
                                : _selectedCuisines.join(', '),
                            style: TextStyle(
                              color: _selectedCuisines.isEmpty
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                              fontSize: R.sp(4.0),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: _grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: R.hp(2.0)),
            _PartnerField(
              controller: _fssaiCtrl,
              label: 'FSSAI License Number',
              hint: '14-digit license number',
              icon: Icons.verified_outlined,
              keyboardType: TextInputType.number,
              maxLength: 14,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v!.trim().isEmpty) return 'FSSAI number is required';
                if (v.trim().length < 14) return 'FSSAI must be 14 digits';
                return null;
              },
            ),
            SizedBox(height: R.hp(3.5)),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: 'Back',
                    icon: Icons.arrow_back,
                    onTap: () => widget.provider.prevStep(),
                  ),
                ),
                SizedBox(width: R.wp(3.0)),
                Expanded(
                  flex: 2,
                  child: _PrimaryButton(
                      label: 'Next: Upload Photo',
                      onTap: _next,
                      icon: Icons.arrow_forward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// STEP 3 — Upload
// ─────────────────────────────────────────────────────────
class _Step3 extends StatelessWidget {
  final PartnerFormProvider provider;
  const _Step3({required this.provider, super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return _StepCard(
      stepTitle: 'Restaurant Photo',
      stepSubtitle: 'A great photo gets you more orders',
      child: Column(
        children: [
          // Upload area
          GestureDetector(
            onTap: () => provider.pickImage(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: R.hp(28.0),
              decoration: BoxDecoration(
                color: provider.imageBytes != null ? Colors.black : _zomaLight,
                borderRadius: BorderRadius.circular(R.wp(4.0)),
                border: Border.all(
                  color: provider.imageBytes != null ? _zomato : _border,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: provider.imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(R.wp(4.0) - 2),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(provider.imageBytes!, fit: BoxFit.cover),
                          Positioned(
                            bottom: R.hp(1.5),
                            right: R.wp(3.0),
                            child: GestureDetector(
                              onTap: () => provider.pickImage(),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: R.wp(3.0), vertical: R.hp(0.8)),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit,
                                        color: Colors.white, size: R.wp(4.0)),
                                    SizedBox(width: R.wp(1.5)),
                                    Text('Change',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: R.sp(3.2))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: R.wp(18.0),
                          height: R.wp(18.0),
                          decoration: BoxDecoration(
                            color: _zomato.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_photo_alternate_outlined,
                              color: _zomato, size: R.wp(9.0)),
                        ),
                        SizedBox(height: R.hp(2.0)),
                        Text(
                          'Tap to upload restaurant photo',
                          style: TextStyle(
                              fontSize: R.sp(4.0),
                              fontWeight: FontWeight.w600,
                              color: _zomato),
                        ),
                        SizedBox(height: R.hp(0.8)),
                        Text(
                          'JPG, PNG supported • Max 10MB',
                          style: TextStyle(fontSize: R.sp(3.2), color: _grey),
                        ),
                      ],
                    ),
            ),
          ),
          if (provider.imageName != null) ...[
            SizedBox(height: R.hp(1.5)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: R.wp(4.0), vertical: R.hp(1.0)),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(R.wp(2.0)),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green, size: R.wp(5.5)),
                  SizedBox(width: R.wp(2.0)),
                  Expanded(
                    child: Text(
                      provider.imageName!,
                      style: TextStyle(
                          fontSize: R.sp(3.5), color: Colors.green.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: R.hp(2.5)),
          // Tips card
          Container(
            padding: EdgeInsets.all(R.wp(4.5)),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(R.wp(3.0)),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber.shade700, size: R.wp(5.0)),
                    SizedBox(width: R.wp(2.0)),
                    Text('Photo Tips',
                        style: TextStyle(
                            fontSize: R.sp(4.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800)),
                  ],
                ),
                SizedBox(height: R.hp(1.0)),
                ...[
                  'Use a well-lit, clear photo of your restaurant',
                  'Show your dining area or signature dish',
                  'Avoid blurry or dark photos',
                ].map((tip) => Padding(
                      padding: EdgeInsets.only(top: R.hp(0.5)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ',
                              style: TextStyle(
                                  fontSize: R.sp(3.5),
                                  color: Colors.amber.shade700)),
                          Expanded(
                              child: Text(tip,
                                  style: TextStyle(
                                      fontSize: R.sp(3.5),
                                      color: Colors.amber.shade800))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          SizedBox(height: R.hp(3.5)),
          // Review Summary
          _ReviewCard(provider: provider),
          SizedBox(height: R.hp(3.0)),
          // Buttons
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  onTap: () => provider.prevStep(),
                ),
              ),
              SizedBox(width: R.wp(3.0)),
              Expanded(
                flex: 2,
                child: _SubmitButton(provider: provider),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// REVIEW SUMMARY CARD
// ─────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final PartnerFormProvider provider;
  const _ReviewCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.wp(5.0)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_outlined, color: _zomato, size: R.wp(5.5)),
              SizedBox(width: R.wp(2.0)),
              Text('Application Summary',
                  style: TextStyle(
                      fontSize: R.sp(4.2), fontWeight: FontWeight.bold)),
            ],
          ),
          Divider(height: R.hp(2.5), color: _border),
          _reviewRow('Restaurant', provider.restaurantName),
          _reviewRow('Owner', provider.ownerName),
          _reviewRow('Location', provider.location),
          _reviewRow('Phone', '+91 ${provider.phone}'),
          _reviewRow('Email', provider.email),
          _reviewRow('Cuisine', provider.cuisineType),
          _reviewRow('FSSAI No.', provider.fssaiNumber),
          _reviewRow('Photo', provider.imageName ?? 'Not uploaded (optional)'),
        ],
      ),
    );
  }

  Widget _reviewRow(String key, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: R.hp(0.6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: R.wp(28.0),
            child:
                Text(key, style: TextStyle(fontSize: R.sp(3.5), color: _grey)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: R.sp(3.5),
                fontWeight: FontWeight.w600,
                color: value.isEmpty ? Colors.grey.shade400 : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SUBMIT BUTTON
// ─────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final PartnerFormProvider provider;
  const _SubmitButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return SizedBox(
      height: R.hp(7.5),
      child: ElevatedButton(
        onPressed: provider.isLoading
            ? null
            : () async {
                await provider.submit(context);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _zomato,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0))),
          elevation: 0,
        ),
        child: provider.isLoading
            ? SizedBox(
                width: R.wp(5.5),
                height: R.wp(5.5),
                child: const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: R.wp(5.5)),
                    SizedBox(width: R.wp(2.0)),
                    Text('Submit Application',
                        style: TextStyle(
                            fontSize: R.sp(4.2), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SUCCESS VIEW
// ─────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onReset;
  const _SuccessView({required this.onReset});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          // Coloured top
          Container(
            width: double.infinity,
            height: R.hp(35.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_zomato, Color(0xFFFF6B6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: R.wp(22.0),
                  height: R.wp(22.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 4)
                    ],
                  ),
                  child: Icon(Icons.check_rounded,
                      color: _zomato, size: R.wp(13.0)),
                ),
                SizedBox(height: R.hp(2.5)),
                Text('Application Submitted!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: R.sp(6.5),
                        fontWeight: FontWeight.bold)),
                SizedBox(height: R.hp(1.0)),
                Text(
                  'We\'ll review your application\nand contact you within 48 hours.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: R.sp(4.0)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(R.wp(6.0)),
            child: Column(
              children: [
                SizedBox(height: R.hp(2.0)),
                // Next steps
                ...[
                  (
                    'Our team will review your application',
                    Icons.search,
                    Colors.blue
                  ),
                  (
                    'You\'ll receive a verification call',
                    Icons.call,
                    Colors.green
                  ),
                  (
                    'Onboarding & menu setup support',
                    Icons.restaurant_menu,
                    Colors.orange
                  ),
                  ('Start receiving orders!', Icons.delivery_dining, _zomato),
                ].indexed.map(((int, (String, IconData, Color)) entry) {
                  final (i, (title, icon, color)) = entry;
                  return Padding(
                    padding: EdgeInsets.only(bottom: R.hp(2.0)),
                    child: Row(
                      children: [
                        Container(
                          width: R.wp(12.0),
                          height: R.wp(12.0),
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle),
                          child: Center(
                              child: Icon(icon, color: color, size: R.wp(6.0))),
                        ),
                        SizedBox(width: R.wp(4.0)),
                        Expanded(
                            child: Text(title,
                                style: TextStyle(
                                    fontSize: R.sp(4.0),
                                    fontWeight: FontWeight.w500))),
                        Container(
                          width: R.wp(7.0),
                          height: R.wp(7.0),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: R.sp(3.5),
                                      fontWeight: FontWeight.bold,
                                      color: _grey))),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: R.hp(2.0)),
                _PrimaryButton(
                    label: 'Submit Another Application',
                    icon: Icons.add_business,
                    onTap: onReset),
                SizedBox(height: R.hp(2.0)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Go Back to App',
                      style: TextStyle(fontSize: R.sp(4.0), color: _zomato)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// REUSABLE COMPONENTS
// ─────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String stepTitle;
  final String stepSubtitle;
  final Widget child;
  const _StepCard(
      {required this.stepTitle,
      required this.stepSubtitle,
      required this.child});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.5)),
      padding: EdgeInsets.all(R.wp(5.5)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(4.0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stepTitle,
              style:
                  TextStyle(fontSize: R.sp(5.5), fontWeight: FontWeight.bold)),
          SizedBox(height: R.hp(0.5)),
          Text(stepSubtitle,
              style: TextStyle(fontSize: R.sp(3.5), color: _grey)),
          SizedBox(height: R.hp(2.5)),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Text(
      label,
      style: TextStyle(
          fontSize: R.sp(3.8),
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700),
    );
  }
}

class _PartnerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final TextCapitalization textCapitalization;

  const _PartnerField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.inputFormatters,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        SizedBox(height: R.hp(0.8)),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          validator: validator,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: TextStyle(fontSize: R.sp(4.0)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(fontSize: R.sp(4.0), color: Colors.grey.shade400),
            counterText: '',
            prefixIcon: Icon(icon, color: _grey, size: R.wp(5.5)),
            prefixText: prefixText,
            prefixStyle: TextStyle(fontSize: R.sp(4.0), color: _grey),
            contentPadding: EdgeInsets.symmetric(
              horizontal: R.wp(4.0),
              vertical: maxLines > 1 ? R.hp(2.0) : 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0)),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0)),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0)),
              borderSide: const BorderSide(color: _zomato, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0)),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0)),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return SizedBox(
      width: double.infinity,
      height: R.hp(7.5),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _zomato,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0))),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: R.sp(4.2), fontWeight: FontWeight.bold)),
            SizedBox(width: R.wp(2.0)),
            Icon(icon, size: R.wp(5.0)),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return SizedBox(
      height: R.hp(7.5),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.wp(3.0))),
          foregroundColor: Colors.black87,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: R.wp(5.0)),
              SizedBox(width: R.wp(2.0)),
              Text(label,
                  style: TextStyle(
                      fontSize: R.sp(4.0), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
