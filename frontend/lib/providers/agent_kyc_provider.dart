import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AgentKycProvider extends ChangeNotifier {
  int _currentStep = 0;
  int get currentStep => _currentStep;

  // Form keys
  final formKey1 = GlobalKey<FormState>();
  final formKey2 = GlobalKey<FormState>();
  final formKey3 = GlobalKey<FormState>();
  final formKey4 = GlobalKey<FormState>();

  // ── Step 1: Personal Details ──
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  // ── Step 2: Identity Verification ──
  String idType = 'Aadhaar';
  final idNumberCtrl = TextEditingController();
  Uint8List? idProofBytes;
  String? idProofName;

  // ── Step 3: Vehicle Details ──
  String vehicleType = 'Bike';
  final vehicleNumberCtrl = TextEditingController();
  Uint8List? rcProofBytes;
  String? rcProofName;

  // ── Step 4: Bank Details ──
  final accountNameCtrl = TextEditingController();
  final accountNumberCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();

  final _picker = ImagePicker();

  void nextStep() {
    if (_currentStep == 0 && !formKey1.currentState!.validate()) return;
    if (_currentStep == 1 && !formKey2.currentState!.validate()) return;
    if (_currentStep == 2 && !formKey3.currentState!.validate()) return;
    if (_currentStep < 3) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void setStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void setIdType(String val) {
    idType = val;
    notifyListeners();
  }

  void setVehicleType(String val) {
    vehicleType = val;
    notifyListeners();
  }

  /// Use image_picker and readAsBytes to ensure web compatibility
  Future<void> pickIdProof() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xFile == null) return;
      
      final bytes = await xFile.readAsBytes();
      // 5MB limit
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        debugPrint('File size exceeds 5MB');
        return;
      }
      
      idProofBytes = Uint8List.fromList(bytes);
      idProofName = xFile.name;
      notifyListeners();
    } catch (e) {
      debugPrint('Error picking ID Proof: $e');
    }
  }

  void clearIdProof() {
    idProofBytes = null;
    idProofName = null;
    notifyListeners();
  }

  Future<void> pickRcProof() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xFile == null) return;
      
      final bytes = await xFile.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) return;
      
      rcProofBytes = Uint8List.fromList(bytes);
      rcProofName = xFile.name;
      notifyListeners();
    } catch (e) {
      debugPrint('Error picking RC Proof: $e');
    }
  }

  void clearRcProof() {
    rcProofBytes = null;
    rcProofName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    dobCtrl.dispose();
    addressCtrl.dispose();
    idNumberCtrl.dispose();
    vehicleNumberCtrl.dispose();
    accountNameCtrl.dispose();
    accountNumberCtrl.dispose();
    ifscCtrl.dispose();
    super.dispose();
  }
}
