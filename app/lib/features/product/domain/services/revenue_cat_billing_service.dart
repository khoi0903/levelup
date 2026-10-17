import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import 'billing_service.dart';

class RevenueCatBillingService implements BillingService {
  final Ref _ref;
  final String apiKey;
  bool _isConfigured = false;
  String? _configuredUid;

  RevenueCatBillingService(this._ref, {required this.apiKey});

  Future<void> onAuthChanged(String? uid) async {
    if (apiKey.isEmpty) return;
    if (uid == null || uid.isEmpty) {
      await logOut();
      return;
    }
    await ensureConfiguredForUser(uid);
  }

  Future<void> ensureConfiguredForUser(String uid) async {
    if (apiKey.isEmpty) return;
    final isConfiguredNatively = _isConfigured || await Purchases.isConfigured;
    if (!isConfiguredNatively) {
      final config = PurchasesConfiguration(apiKey)..appUserID = uid;
      await Purchases.configure(config);
      _isConfigured = true;
      _configuredUid = uid;
    } else if (_configuredUid != uid) {
      await Purchases.logIn(uid);
      _configuredUid = uid;
    }
  }

  @override
  Future<void> logOut() async {
    if (apiKey.isEmpty) return;
    final isConfiguredNatively = _isConfigured || await Purchases.isConfigured;
    if (isConfiguredNatively && _configuredUid != null) {
      try {
        await Purchases.logOut();
      } catch (e) {
        debugPrint('RevenueCat logOut error: $e');
      }
      _configuredUid = null;
    }
  }

  @override
  Future<Map<BillingPeriod, String>> getPrices() async {
    try {
      final currentUid = _ref.read(authRepositoryProvider).currentUser?.id;
      if (currentUid != null) {
        await ensureConfiguredForUser(currentUid);
      }
      final isConfiguredNatively = _isConfigured || await Purchases.isConfigured;
      if (!isConfiguredNatively) {
        return const {};
      }
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return const {};
      final map = <BillingPeriod, String>{};
      if (current.monthly != null) {
        map[BillingPeriod.monthly] = current.monthly!.storeProduct.priceString;
      }
      if (current.annual != null) {
        map[BillingPeriod.yearly] = current.annual!.storeProduct.priceString;
      }
      return map;
    } catch (e) {
      debugPrint('RevenueCat getPrices error: $e');
      return const {};
    }
  }

  @override
  Future<String> purchase(BillingPeriod period) async {
    try {
      final currentUid = _ref.read(authRepositoryProvider).currentUser?.id;
      if (currentUid != null) {
        await ensureConfiguredForUser(currentUid);
      }
      final isConfiguredNatively = _isConfigured || await Purchases.isConfigured;
      if (!isConfiguredNatively) {
        return 'Chưa cấu hình thanh toán';
      }

      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        return 'Không tìm thấy gói sản phẩm';
      }

      final package = period == BillingPeriod.monthly
          ? current.monthly
          : current.annual;
      if (package == null) {
        return 'Không tìm thấy gói sản phẩm phù hợp';
      }

      await Purchases.purchase(PurchaseParams.package(package));
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return '';
      }
      return 'Lỗi thanh toán: ${e.message ?? 'Đã có lỗi xảy ra'}';
    } catch (e) {
      return 'Lỗi thanh toán: $e';
    }

    return await _pollForProActivation();
  }

  @override
  Future<String> restore() async {
    try {
      final currentUid = _ref.read(authRepositoryProvider).currentUser?.id;
      if (currentUid != null) {
        await ensureConfiguredForUser(currentUid);
      }
      final isConfiguredNatively = _isConfigured || await Purchases.isConfigured;
      if (!isConfiguredNatively) {
        return 'Chưa cấu hình thanh toán';
      }

      await Purchases.restorePurchases();
      _ref.invalidate(userStatusFutureProvider);
      try {
        final me = await _ref.read(userRepositoryProvider).getMe();
        _ref.read(currentUserProvider.notifier).state = me;
        if (me.subscription.tier == 'pro') {
          return 'Đã kích hoạt Pro';
        }
      } catch (_) {}
      return 'Đã khôi phục giao dịch';
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return '';
      }
      return 'Lỗi khôi phục: ${e.message ?? 'Đã có lỗi xảy ra'}';
    } catch (e) {
      return 'Lỗi khôi phục: $e';
    }
  }

  Future<String> _pollForProActivation() async {
    _ref.invalidate(userStatusFutureProvider);
    bool isPro = false;
    for (int i = 0; i < 5; i++) {
      try {
        final me = await _ref.read(userRepositoryProvider).getMe();
        _ref.read(currentUserProvider.notifier).state = me;
        if (me.subscription.tier == 'pro') {
          isPro = true;
          break;
        }
      } catch (e) {
        debugPrint('RevenueCat polling /me error: $e');
      }
      if (i < 4) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _ref.invalidate(userStatusFutureProvider);
    if (isPro) {
      return 'Đã kích hoạt Pro';
    } else {
      return 'Đã thanh toán, Pro sẽ kích hoạt trong ít phút';
    }
  }
}
