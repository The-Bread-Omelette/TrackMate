import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/tm_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _startTimer(); // Starts the countdown automatically when page loads
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _canResend = true;
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthResetPasswordEvent(
            email: widget.email,
            otp: _otpController.text.trim(),
            newPassword: _passwordController.text,
          ),
        );
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    // Dispatching ForgotPasswordEvent again to trigger a fresh OTP email from the backend
    context.read<AuthBloc>().add(
          AuthForgotPasswordEvent(email: widget.email),
        );
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            context.read<AuthBloc>().add(const AuthLogoutEvent());
            context.go('/login');
          },
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthErrorState) {
            setState(() => _sending = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
          if (state is AuthPasswordResetEmailSentState) {
            setState(() => _sending = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('New OTP sent to your email!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
          if (state is AuthPasswordResetSuccessState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Password reset successfully! Please log in.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
            // Forces the redirect to login upon success
            context.go('/login');
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoadingState;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.password_rounded,
                        color: AppColors.success,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Create New Password',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-digit code sent to ${widget.email} and choose a new password.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TmTextField(
                              label: '6-Digit OTP',
                              hint: '123456',
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'OTP is required';
                                if (v.length != 6) return 'Must be exactly 6 digits';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TmTextField(
                              label: 'New Password',
                              controller: _passwordController,
                              isPassword: true,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Password is required';
                                if (v.length < 8) return 'Minimum 8 characters';
                                if (!v.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
                                if (!v.contains(RegExp(r'[0-9]'))) return 'Must contain a digit';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TmTextField(
                              label: 'Confirm New Password',
                              controller: _confirmController,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              onEditingComplete: _submit,
                              validator: (v) {
                                if (v != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isLoading
                                  ? Container(
                                      key: const ValueKey('loading'),
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      key: const ValueKey('button'),
                                      onPressed: _submit,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 50),
                                      ),
                                      child: const Text('Reset Password'),
                                    ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 🔥 Here is the exact Timer and Resend Button logic
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Didn't receive the code? ",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: (_sending || !_canResend) ? null : _resend,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: _canResend
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                  child: Text(
                                    _canResend
                                        ? 'Resend'
                                        : 'Resend in ${_secondsRemaining}s',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _canResend
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                context.read<AuthBloc>().add(const AuthLogoutEvent());
                                context.go('/login');
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                              child: const Text('Back to login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}