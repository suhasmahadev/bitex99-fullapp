import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../utils/responsive.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/restaurant_service.dart';
import '../../core/app_exceptions.dart';
import '../../core/local_storage.dart';
import '../../core/token_storage.dart';
import '../../providers/auth_provider.dart' as riverpod_auth;
import '../customer/customer_main.dart';
import '../restaurant/restaurant_partner_page.dart';
import '../agent/delivery_dashboard_page.dart';
import '../agent/agent_registration.dart';
import '../agent/agent_kyc_status.dart';
import '../restaurant/restaurant_main.dart';
import '../restaurant/menu_management.dart';
import '../restaurant/restaurant_waiting_screen.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ROLE SELECTOR SCREEN (shown after successful login / OTP verify)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: R.wp(6.0), vertical: R.hp(4.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: R.hp(2.0)),
              Text('Welcome!', style: TextStyle(fontSize: R.sp(8.0), fontWeight: FontWeight.bold)),
              SizedBox(height: R.hp(1.0)),
              Text(
                'How would you like to continue?',
                style: TextStyle(fontSize: R.sp(4.0), color: Colors.grey.shade600),
              ),
              SizedBox(height: R.hp(4.0)),
              _RoleCard(role: UserRole.customer, color: Colors.orange),
              SizedBox(height: R.hp(2.0)),
              _RoleCard(role: UserRole.restaurantPartner, color: Colors.green),
              SizedBox(height: R.hp(2.0)),
              _RoleCard(role: UserRole.deliveryAgent, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final Color color;
  const _RoleCard({required this.role, required this.color});

  void _navigate(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final themeProvider = context.read<ThemeProvider>();
    
    userProvider.setRole(role);
    themeProvider.setRoleTheme(role);

    Widget next;
    switch (role) {
      case UserRole.customer:
        next = const CustomerMain();
        break;
      case UserRole.restaurantPartner:
        next = const RestaurantPartnerPage();
        break;
      case UserRole.deliveryAgent:
        next = const DeliveryDashboardPage();
        break;
    }
    if (role == UserRole.customer) {
      context.go('/home/restaurants');
    } else if (role == UserRole.restaurantPartner) {
      context.go('/restaurant-admin');
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => next),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        height: R.hp(12.0),
        padding: EdgeInsets.symmetric(horizontal: R.wp(4.0)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(R.wp(3.5)),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: R.wp(6.5),
              backgroundColor: color.withOpacity(0.15),
              child: Icon(role.icon, color: color, size: R.wp(7.0)),
            ),
            SizedBox(width: R.wp(4.0)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    role.label,
                    style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _subtitle(role),
                    style: TextStyle(fontSize: R.sp(3.2), color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: R.wp(4.5)),
          ],
        ),
      ),
    );
  }

  String _subtitle(UserRole r) {
    switch (r) {
      case UserRole.customer:
        return 'Order food from local restaurants';
      case UserRole.restaurantPartner:
        return 'Manage orders, menu & earnings';
      case UserRole.deliveryAgent:
        return 'Deliver orders & earn rewards';
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// MAIN LOGIN SCREEN
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class LoginScreen extends ConsumerStatefulWidget {
  final String town;
  const LoginScreen({super.key, required this.town});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  static const _orange = Color(0xFFE8593C);

  UserRole? _selectedRole;

  final _firstNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  
  bool _otpSent = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _rememberMe = false;
  bool _googleSigningIn = false;

  // Google-prefill data (cleared after OTP verify PATCH)
  String? _googleName;
  String? _googleEmail;

  String? _firstNameError;
  String? _phoneError;
  String? _roleError;
  String? _otpError;
  String? _globalError;
  String? _googlePreFillBanner;
  
  int _resendCountdown = 30;
  Timer? _resendTimer;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _shakeCtrl.dispose();
    for (final c in [..._otpCtrls, _firstNameCtrl, _phoneCtrl]) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  // â”€â”€ Navigation after OTP confirmed â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _navigateByRole(String role) {
    final userProvider = context.read<UserProvider>();
    final themeProvider = context.read<ThemeProvider>();
    final authUser = ref.read(riverpod_auth.authProvider).valueOrNull;
    final name = _firstNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    userProvider.login(
      uid: authUser?.uid ?? '',
      name: authUser?.name.isNotEmpty == true ? authUser!.name : name,
      phone: authUser?.phone.isNotEmpty == true ? authUser!.phone : phone,
      role: _selectedRole!,
      town: authUser?.town ?? '',
    );
    themeProvider.setRoleTheme(_selectedRole!);

    switch (role) {
      case 'customer':
        context.go('/home/restaurants');
        break;
      case 'restaurant':
        _navigateRestaurant(context, phone);
        return;
      case 'agent':
        context.go('/delivery');
        break;
      default:
        context.go('/home/restaurants');
    }
  }

  Future<void> _navigateRestaurant(BuildContext context, String phone) async {
    try {
      final restaurant = await RestaurantService().getRestaurantById(phone);
      if (!context.mounted) return;
      if (restaurant == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RestaurantPartnerPage()),
          (_) => false,
        );
      } else if (restaurant.status == 'pending') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => RestaurantWaitingScreen(restaurant: restaurant)),
          (_) => false,
        );
      } else {
        context.go('/restaurant-admin');
      }
    } catch (e) {
      debugPrint('Error checking restaurant status: $e');
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RestaurantPartnerPage()),
        (_) => false,
      );
    }
  }

  // â”€â”€ Phone OTP flow (HTTP to backend) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _sendOtp() async {
    setState(() {
      _firstNameError = _firstNameCtrl.text.trim().isEmpty ? 'First name is required' : null;
      _phoneError = _phoneCtrl.text.trim().length != 10 ? 'Enter a valid 10-digit number' : null;
      _roleError = _selectedRole == null ? 'Please select your role' : null;
      _globalError = null;
    });
    if (_firstNameError != null || _phoneError != null || _roleError != null) return;

    setState(() => _sendingOtp = true);

    try {
      await AuthService().verifyPhone(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _otpSent = true;
        _globalError = null;
      });
      _startResendTimer();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _otpFocus[0].requestFocus();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent successfully! Check backend logs for the OTP.')),
      );
    } on OtpCooldownException catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = e.message; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = e.message; });
    } catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = 'Failed to send OTP'; });
    }
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCountdown <= 0) {
        t.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  void _resendOtp() async {
    for (final c in _otpCtrls) { c.clear(); }
    setState(() { _sendingOtp = true; _otpError = null; _globalError = null; });

    try {
      await AuthService().verifyPhone(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() => _sendingOtp = false);
      _startResendTimer();
      _otpFocus[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New OTP sent successfully!')),
      );
    } on OtpCooldownException catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = e.message; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = e.message; });
    } catch (e) {
      if (mounted) setState(() { _sendingOtp = false; _globalError = 'Failed to resend OTP'; });
    }
  }

  void _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _otpError = 'Enter valid 6-digit OTP');
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() { _verifyingOtp = true; _otpError = null; _globalError = null; });

    // Map UserRole enum to backend role string
    String roleStr = 'customer';
    switch (_selectedRole!) {
      case UserRole.customer: roleStr = 'customer'; break;
      case UserRole.restaurantPartner: roleStr = 'restaurant'; break;
      case UserRole.deliveryAgent: roleStr = 'agent'; break;
    }

    try {
      await ref.read(riverpod_auth.authProvider.notifier).login(
        phone: _phoneCtrl.text.trim(),
        otp: otp,
        role: roleStr,
        name: _firstNameCtrl.text.trim(),
      );
      if (!mounted) return;

      // â”€â”€ Remember Me: persist or clear token based on checkbox â”€â”€
      await LocalStorage.preferences.put('remember_me', _rememberMe);
      // If "Remember me" is off, SplashScreen clears the token on the next
      // cold start. Keep it for this session so post-login setup can call APIs.

      // â”€â”€ Google post-OTP PATCH: update name/email if from Google flow â”€â”€
      if (_googleName != null || _googleEmail != null) {
        try {
          await AuthService().patchProfile(
            name: _googleName,
            email: _googleEmail,
          );
        } catch (_) {
          // Non-fatal â€” profile update can be retried later
        }
        _googleName = null;
        _googleEmail = null;
      }

      setState(() => _verifyingOtp = false);
      _navigateByRole(roleStr);
    } on InvalidOtpException catch (e) {
      if (mounted) { setState(() { _verifyingOtp = false; _otpError = e.message; }); _shakeCtrl.forward(from: 0); }
    } on NetworkException catch (e) {
      if (mounted) setState(() { _verifyingOtp = false; _globalError = e.message; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _verifyingOtp = false; _otpError = e.message; });
    } catch (e) {
      if (mounted) { setState(() { _verifyingOtp = false; _otpError = 'Verification failed'; }); _shakeCtrl.forward(from: 0); }
    }
  }

  // â”€â”€ Google Sign-In pre-fill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _signInWithGoogle() async {
    setState(() { _googleSigningIn = true; _globalError = null; });
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (!mounted) return;
      if (account == null) {
        // User cancelled
        setState(() => _googleSigningIn = false);
        return;
      }

      _googleName = account.displayName;
      _googleEmail = account.email;

      // Pre-fill name field if empty
      if (_googleName != null && _firstNameCtrl.text.trim().isEmpty) {
        _firstNameCtrl.text = _googleName!.split(' ').first;
      }

      setState(() {
        _googleSigningIn = false;
        _googlePreFillBanner = 'Please verify your phone to continue';
        _globalError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signed in as ${account.displayName ?? account.email}. Enter your phone to continue.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleSigningIn = false;
          _globalError = 'Google Sign-In failed. Please try again.';
        });
      }
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            _buildHeader(),
            _buildFormCard(),
          ],
        ),
      ),
    );
  }

  // â”€â”€ HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: R.hp(30.0),
      color: Colors.black,
      child: Stack(
        children: [
          // Content â€” logo centered
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/bitex99_logo.png',
                  height: R.hp(16.0),
                  fit: BoxFit.contain,
                ),
                SizedBox(height: R.hp(1.5)),
                Text(
                  'Your Town. Your Food.',
                  style: TextStyle(
                    fontSize: R.sp(3.8),
                    color: Colors.white54,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          // Bottom wave to blend into white form
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: _WaveClipper(),
              child: Container(height: R.hp(6.0), color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ FORM CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.fromLTRB(R.wp(6.0), R.hp(1.0), R.wp(6.0), R.hp(4.0)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // â”€â”€ Role Selector
          _buildRoleSelector(),
          SizedBox(height: R.hp(3.0)),
          
          if (_globalError != null) ...[
            Container(
              padding: EdgeInsets.all(R.wp(3.0)),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(R.wp(2.0)),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: R.wp(5.0)),
                  SizedBox(width: R.wp(2.0)),
                  Expanded(
                    child: Text(
                      _globalError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: R.sp(3.5)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: R.hp(2.0)),
          ],

          _buildPhoneTab(),
          
          SizedBox(height: R.hp(3.0)),
          _buildTermsText(),
          SizedBox(height: R.hp(2.0)),
        ],
      ),
    );
  }

  // â”€â”€ ROLE SELECTOR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.badge_outlined, size: R.wp(5.0), color: Colors.grey.shade700),
            SizedBox(width: R.wp(2.0)),
            Text(
              'I am a...',
              style: TextStyle(fontSize: R.sp(4.2), fontWeight: FontWeight.w700, color: Colors.grey.shade800),
            ),
          ],
        ),
        SizedBox(height: R.hp(1.5)),
        Row(
          children: UserRole.values.map((role) {
            final selected = _selectedRole == role;
            final colors = {
              UserRole.customer: Colors.orange,
              UserRole.restaurantPartner: Colors.green,
              UserRole.deliveryAgent: Colors.blue,
            };
            final color = colors[role]!;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedRole = role;
                  _roleError = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: role != UserRole.deliveryAgent ? R.wp(2.0) : 0),
                  padding: EdgeInsets.symmetric(vertical: R.hp(1.5)),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(R.wp(3.0)),
                    border: Border.all(
                      color: selected ? color : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(role.icon, color: selected ? color : Colors.grey.shade500, size: R.wp(6.5)),
                      SizedBox(height: R.hp(0.5)),
                      Text(
                        _shortLabel(role),
                        style: TextStyle(
                          fontSize: R.sp(2.8),
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? color : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_roleError != null) ...[
          SizedBox(height: R.hp(0.8)),
          Text(_roleError!, style: TextStyle(fontSize: R.sp(3.2), color: Colors.red.shade600)),
        ],
      ],
    );
  }

  String _shortLabel(UserRole r) {
    switch (r) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.restaurantPartner:
        return 'Restaurant\nPartner';
      case UserRole.deliveryAgent:
        return 'Delivery\nAgent';
    }
  }

  // â”€â”€ PHONE TAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPhoneTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel('First Name'),
        _inputField(
          controller: _firstNameCtrl,
          hint: 'Enter your first name',
          prefixIcon: Icons.person_outline,
          error: _firstNameError,
          onChanged: (_) => setState(() => _firstNameError = null),
          textCapitalization: TextCapitalization.words,
        ),
        SizedBox(height: R.hp(2.0)),
        _fieldLabel('Phone Number'),
        _inputField(
          controller: _phoneCtrl,
          hint: 'Enter 10-digit number',
          prefixText: '+91  ',
          keyboardType: TextInputType.phone,
          maxLength: 10,
          error: _phoneError,
          onChanged: (_) => setState(() => _phoneError = null),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SizedBox(height: R.hp(1.5)),
        // â”€â”€ Remember Me â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          children: [
            SizedBox(
              width: R.wp(6.0),
              height: R.wp(6.0),
              child: Checkbox(
                value: _rememberMe,
                activeColor: _orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) => setState(() => _rememberMe = val ?? false),
              ),
            ),
            SizedBox(width: R.wp(2.0)),
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Text(
                'Remember me',
                style: TextStyle(
                  fontSize: R.sp(3.8),
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        // â”€â”€ Google pre-fill banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (_googlePreFillBanner != null) ...[
          SizedBox(height: R.hp(1.0)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.wp(3.0), vertical: R.hp(1.0)),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(R.wp(2.0)),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: R.wp(4.5)),
                SizedBox(width: R.wp(2.0)),
                Expanded(
                  child: Text(
                    _googlePreFillBanner!,
                    style: TextStyle(color: Colors.blue.shade800, fontSize: R.sp(3.4)),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: R.hp(2.0)),
        if (!_otpSent)
          SizedBox(
            height: R.hp(7.5),
            child: ElevatedButton(
              onPressed: _sendingOtp ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(3.0))),
              ),
              child: _sendingOtp
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                  : Text('Send OTP', style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold)),
            ),
          ),
        if (!_otpSent) ...[
          SizedBox(height: R.hp(1.5)),
          // â”€â”€ OR divider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: R.wp(3.0)),
                child: Text('or', style: TextStyle(fontSize: R.sp(3.5), color: Colors.grey.shade500)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          SizedBox(height: R.hp(1.5)),
          // â”€â”€ Continue with Google â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SizedBox(
            height: R.hp(7.5),
            child: OutlinedButton(
              onPressed: _googleSigningIn ? null : _signInWithGoogle,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(3.0))),
              ),
              child: _googleSigningIn
                  ? SizedBox(
                      width: R.wp(5.5),
                      height: R.wp(5.5),
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google 'G' logo colours
                        _GoogleLogo(size: R.wp(5.5)),
                        SizedBox(width: R.wp(3.0)),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: R.sp(4.2),
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
        // OTP section â€” animated slide-down
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          height: _otpSent ? R.hp(28.0) : 0,
          curve: Curves.easeOut,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: _otpSent ? _buildOtpSection() : const SizedBox.shrink(),
        ),
        SizedBox(height: R.hp(1.5)),
        Text(
          'New to Bitex99? Your account is created automatically on first login.',
          style: TextStyle(fontSize: R.sp(3.2), color: Colors.grey.shade500),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildOtpSection() {
    return Padding(
      padding: EdgeInsets.only(top: R.hp(2.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter OTP sent to +91 ${_phoneCtrl.text}',
            style: TextStyle(fontSize: R.sp(3.5), color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: R.hp(2.0)),
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              final offset = _shakeCtrl.isAnimating
                  ? ((_shakeAnim.value * 4).round() % 2 == 0 ? 8.0 : -8.0) * _shakeAnim.value
                  : 0.0;
              return Transform.translate(offset: Offset(offset, 0), child: child);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, _buildOtpBox),
            ),
          ),
          if (_otpError != null) ...[
            SizedBox(height: R.hp(1.0)),
            Text(_otpError!, style: TextStyle(fontSize: R.sp(3.2), color: Colors.red.shade600), textAlign: TextAlign.center),
          ],
          SizedBox(height: R.hp(1.5)),
          Center(
            child: GestureDetector(
              onTap: _resendCountdown == 0 ? _resendOtp : null,
              child: Text(
                _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend OTP',
                style: TextStyle(
                  fontSize: R.sp(3.5),
                  color: _resendCountdown == 0 ? _orange : Colors.grey.shade500,
                  fontWeight: _resendCountdown == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
          SizedBox(height: R.hp(2.0)),
          SizedBox(
            height: R.hp(7.5),
            child: ElevatedButton(
              onPressed: _verifyingOtp ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(3.0))),
              ),
              child: _verifyingOtp
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                  : Text('Verify & Continue', style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int i) {
    return SizedBox(
      width: R.wp(12.0),
      height: R.hp(8.0),
      child: TextField(
        controller: _otpCtrls[i],
        focusNode: _otpFocus[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(fontSize: R.sp(7.0), fontWeight: FontWeight.bold, color: _orange),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.wp(3.0)),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.wp(3.0)),
            borderSide: const BorderSide(color: _orange, width: 2),
          ),
        ),
        onChanged: (val) {
          setState(() => _otpError = null);
          if (val.isNotEmpty && i < 5) _otpFocus[i + 1].requestFocus();
          if (val.isNotEmpty && i == 5) _otpFocus[i].unfocus();
        },
      ),
    );
  }

  // â”€â”€ SHARED WIDGETS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _fieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: R.hp(0.8)),
      child: Text(label, style: TextStyle(fontSize: R.sp(3.8), fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    String? prefixText,
    TextInputType? keyboardType,
    int? maxLength,
    String? error,
    ValueChanged<String>? onChanged,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: R.hp(7.5),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            onChanged: onChanged,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            style: TextStyle(fontSize: R.sp(4.0)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: R.sp(4.0), color: Colors.grey.shade400),
              counterText: '',
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade500, size: R.wp(5.5)) : null,
              prefixText: prefixText,
              prefixStyle: TextStyle(fontSize: R.sp(4.0), color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              contentPadding: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(2.0)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.wp(3.0)), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.wp(3.0)), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.wp(3.0)), borderSide: const BorderSide(color: _orange, width: 2)),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: R.hp(0.5), left: R.wp(1.0)),
            child: Text(error, style: TextStyle(fontSize: R.sp(3.2), color: Colors.red.shade600)),
          ),
      ],
    );
  }

  Widget _buildTermsText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(fontSize: R.sp(3.0), color: Colors.grey.shade500),
        children: const [
          TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(text: 'Terms of Service', style: TextStyle(color: _orange, fontWeight: FontWeight.w600)),
          TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: TextStyle(color: _orange, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// â”€â”€ WAVE CLIPPER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// ── GOOGLE LOGO WIDGET ────────────────────────────────────
/// Renders the classic four-color Google 'G' logo using CustomPaint.
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final colors = [
      const Color(0xFFEA4335),
      const Color(0xFFFBBC05),
      const Color(0xFF34A853),
      const Color(0xFF4285F4),
    ];
    final startAngles = [-0.523, 1.047, 2.618, 4.189];
    final sweepAngles = [1.571, 1.571, 1.571, 1.571];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: c, radius: r * 0.75);
    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(rect, startAngles[i], sweepAngles[i], false, paint);
    }
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.6, size.width, size.height * 0.1);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}
