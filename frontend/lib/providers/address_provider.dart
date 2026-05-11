import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/address_service.dart';
import 'auth_provider.dart';

final addressProvider =
    AsyncNotifierProvider<AddressController, List<AddressModel>>(
  AddressController.new,
);

class AddressController extends AsyncNotifier<List<AddressModel>> {
  final _service = AddressService();

  @override
  Future<List<AddressModel>> build() async {
    ref.watch(authProvider);
    if (ref.read(authProvider).valueOrNull == null) return [];
    return _service.getAddresses();
  }

  Future<AddressModel> addAddress(Map<String, dynamic> data) async {
    final address = await _service.addAddress(data);
    state = AsyncData(await _service.getAddresses());
    return address;
  }

  Future<void> setDefault(String id) async {
    await _service.setDefault(id);
    state = AsyncData(await _service.getAddresses());
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    state = AsyncData(await _service.getAddresses());
  }
}
