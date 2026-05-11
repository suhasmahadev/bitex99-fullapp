import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static const authBox = 'auth';
  static const cartBox = 'cart';
  static const restaurantsBox = 'restaurants';
  static const ordersBox = 'orders';
  static const preferencesBox = 'preferences';

  static Future<void> openHiveBoxes() async {
    await Future.wait([
      Hive.openBox(authBox),
      Hive.openBox(cartBox),
      Hive.openBox(restaurantsBox),
      Hive.openBox(ordersBox),
      Hive.openBox(preferencesBox),
    ]);
  }

  static Box get auth => Hive.box(authBox);
  static Box get cart => Hive.box(cartBox);
  static Box get restaurants => Hive.box(restaurantsBox);
  static Box get orders => Hive.box(ordersBox);
  static Box get preferences => Hive.box(preferencesBox);

  static Future<void> cacheUser(Map<String, dynamic> user) async {
    await auth.put('user', user);
    if ((user['town'] ?? '').toString().isNotEmpty) {
      await preferences.put('town', user['town']);
    }
  }

  static Map<String, dynamic>? get cachedUser {
    final value = auth.get('user');
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

Future<void> openHiveBoxes() => LocalStorage.openHiveBoxes();
