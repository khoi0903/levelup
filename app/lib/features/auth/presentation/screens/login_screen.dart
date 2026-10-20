import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../controllers/auth_controller.dart';

/// Màn hình đăng nhập / đăng ký tài khoản (trước Onboarding).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _resetEmailController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  void _onAuthSuccess() {
    // Sau khi đăng nhập thành công, làm mới trạng thái user và chuyển hướng về luồng bootstrap
    ref.invalidate(userStatusFutureProvider);
    ref.invalidate(currentUserProvider);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App branding header
                  Center(
                    child: Text(
                      'LevelUp',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: context.colors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Đồng hành rèn luyện & duy trì thói quen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Success Banner
                  if (authState.successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.colors.successBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.successBorder),
                      ),
                      child: Text(
                        authState.successMessage!,
                        key: const ValueKey('login-success-banner'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.successText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error Banner
                  if (authState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.colors.errorBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.errorBorder),
                      ),
                      child: Text(
                        authState.errorMessage!,
                        key: const ValueKey('login-error-banner'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.errorText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Tiếp tục với Google button
                  _buildGoogleButton(
                    isLoading: authState.isLoading,
                    onTap: () async {
                      final success = await authNotifier.signInWithGoogle();
                      if (success && mounted) {
                        _onAuthSuccess();
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Divider "hoặc"
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.colors.border, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          _isSignUp ? 'hoặc đăng ký bằng email' : 'hoặc đăng nhập bằng email',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.colors.border, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Card Form
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên hiển thị (chỉ hiện khi Đăng ký)
                        if (_isSignUp) ...[
                          Text(
                            'Tên hiển thị',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const ValueKey('auth-name-field'),
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration(
                              hintText: 'Nhập tên của bạn...',
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email field
                        Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('auth-email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: _inputDecoration(
                            hintText: 'email@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mật khẩu',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            if (!_isSignUp)
                              GestureDetector(
                                onTap: () => _showForgotPasswordModal(context, authNotifier),
                                child: Text(
                                  'Quên mật khẩu?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('auth-password-field'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: context.colors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Nút Đăng nhập / Đăng ký
                        PrimaryButton(
                          key: const ValueKey('auth-submit-button'),
                          label: authState.isLoading
                              ? 'Đang xử lý...'
                              : (_isSignUp ? 'Đăng ký tài khoản' : 'Đăng nhập'),
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  final email = _emailController.text.trim();
                                  final password = _passwordController.text;

                                  final bool success;
                                  if (_isSignUp) {
                                    final name = _nameController.text.trim();
                                    success = await authNotifier.signUpWithEmailPassword(
                                      email: email,
                                      password: password,
                                      displayName: name.isNotEmpty ? name : null,
                                    );
                                  } else {
                                    success = await authNotifier.signInWithEmailPassword(
                                      email: email,
                                      password: password,
                                    );
                                  }

                                  if (success && mounted) {
                                    _onAuthSuccess();
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggle giữa Đăng nhập và Đăng ký
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUp
                            ? 'Đã có tài khoản?'
                            : 'Chưa có tài khoản?',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        key: const ValueKey('auth-toggle-mode'),
                        onTap: () {
                          authNotifier.clearMessages();
                          setState(() {
                            _isSignUp = !_isSignUp;
                          });
                        },
                        child: Text(
                          _isSignUp ? 'Đăng nhập' : 'Đăng ký ngay',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton({
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: const ValueKey('google-signin-button'),
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google icon
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent,
              ),
              alignment: Alignment.center,
              child: const Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Tiếp tục với Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 14),
      filled: true,
      fillColor: context.colors.mutedBg,
      prefixIcon: Icon(prefixIcon, color: context.colors.textSecondary, size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  void _showForgotPasswordModal(BuildContext context, AuthNotifier notifier) {
    // Không điền sẵn email đăng nhập: robot kiểm thử của Google Play (đăng nhập bằng tài khoản thật)
    // bấm "Gửi" là chủ tài khoản nhận mail đặt lại mật khẩu dù không ai yêu cầu.
    _resetEmailController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            MediaQuery.of(bottomSheetCtx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quên mật khẩu?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nhập địa chỉ email tài khoản của bạn để nhận liên kết đặt lại mật khẩu.',
                style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('forgot-password-email-field'),
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hintText: 'email@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                key: const ValueKey('forgot-password-submit-button'),
                label: 'Gửi email đặt lại mật khẩu',
                onPressed: () async {
                  final email = _resetEmailController.text.trim();
                  Navigator.pop(bottomSheetCtx);
                  await notifier.sendPasswordResetEmail(email);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
