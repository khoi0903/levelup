import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider lưu branch hiện tại của AppShell (0: Trang chủ, 1: Tập, 2: Coach, 3: Dinh dưỡng, 4: Tôi).
final appShellCurrentBranchProvider = StateProvider<int>((ref) => 0);
