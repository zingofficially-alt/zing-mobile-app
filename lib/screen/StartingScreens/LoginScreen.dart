import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';

/// Maps Supabase auth errors to messages for the user.
String authErrorMessage(AuthException e) {
  final code = (e.code ?? '').toLowerCase();
  final msg = e.message.toLowerCase();
  if (code == 'invalid_credentials' || msg.contains('invalid login')) {
    return 'Invalid email or password. Please check your credentials.';
  }
  if (code == 'email_not_confirmed') {
    return 'Please confirm your email first. Check your inbox for the link.';
  }
  if (code == 'user_not_found') {
    return 'No account found with this email. Please check or sign up.';
  }
  if (code == 'user_already_exists' || code == 'email_exists') {
    return 'This email is already registered. Please sign in instead.';
  }
  if (code == 'weak_password') {
    return 'Password is too weak. Use at least 6 characters.';
  }
  if (code == 'over_request_rate_limit' || code == 'over_sms_send_rate_limit' ||
      code == 'over_email_send_rate_limit' || e.statusCode == '429') {
    return 'Too many attempts. Please try again later.';
  }
  if (code == 'otp_expired') {
    return 'Code expired. Please request a new code.';
  }
  if (code == 'sms_send_failed' || code == 'provider_disabled' || msg.contains('sms')) {
    return 'Could not send the SMS code. Phone login may not be set up yet; use email login.';
  }
  if (msg.contains('network') || msg.contains('socket')) {
    return 'Network error. Please check your internet connection and try again.';
  }
  return e.message.isEmpty ? 'Something went wrong. Please try again.' : e.message;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool isPhoneSelected = false;
  bool isTermsAccepted = false;
  final TextEditingController phoneController = TextEditingController(text: '+94 ');
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GoTrueClient _auth = Supabase.instance.client.auth;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isPasswordVisible = false;
  String? _verificationId;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _canResend = true;
  int _otpRetryCount = 0;
  final int _maxOtpRetries = 3;

  final String termsUrl = "https://mfmrifath.github.io/Zing-Terms-and-Conditions/";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _animationController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _launchTermsUrl() async {
    final Uri url = Uri.parse(termsUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        _showSnackBar("Unable to open Terms and Conditions URL.", isError: true);
      }
    }
  }

  void _showTermsDialog() {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        final dialogCs = dialogTheme.colorScheme;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 5,
            backgroundColor: dialogCs.surface,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        color: dialogCs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Terms and Conditions",
                        style: dialogTheme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: dialogCs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Please read and accept our Terms and Conditions before proceeding with Zing services.",
                    style: dialogTheme.textTheme.bodyMedium?.copyWith(
                      color: dialogCs.onSurface,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _launchTermsUrl,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: dialogCs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            color: dialogCs.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "View Full Terms",
                            style: dialogTheme.textTheme.labelLarge?.copyWith(
                              color: dialogCs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Decline",
                          style: dialogTheme.textTheme.labelLarge?.copyWith(
                            color: dialogCs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isTermsAccepted = true;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dialogCs.primary,
                          foregroundColor: dialogCs.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Accept",
                          style: dialogTheme.textTheme.labelLarge?.copyWith(
                            color: dialogCs.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _checkTermsAndLogin() {
    if (!isTermsAccepted) {
      _showTermsDialog();
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _errorMessage = null;
      });

      if (isPhoneSelected) {
        _loginWithPhoneNumber();
      } else {
        _loginWithEmail();
      }
    }
  }

  Future<void> _loginWithEmail() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = authErrorMessage(e);
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred. Please check your connection and try again.";
        });
        HapticFeedback.heavyImpact();
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithPhoneNumber() async {
    debugPrint("\n🔵 ========== PHONE LOGIN STARTED ==========");
    debugPrint("🔵 Phone number from controller: '${phoneController.text}'");

    if (_otpRetryCount >= _maxOtpRetries) {
      debugPrint("❌ Max OTP retry attempts reached: $_otpRetryCount/$_maxOtpRetries");
      setState(() {
        _errorMessage = "Maximum attempts reached. Please try again later.";
      });
      return;
    }

    String phoneNumber = phoneController.text.trim();
    debugPrint("🔵 Trimmed phone number: '$phoneNumber'");

    if (!phoneNumber.startsWith('+94')) {
      debugPrint("❌ Phone number validation failed: doesn't start with +94");
      setState(() {
        _errorMessage = "Phone number must start with +94";
      });
      return;
    }

    String numberWithoutCode = phoneNumber.substring(3).replaceAll(RegExp(r'\D'), '');
    debugPrint("🔵 Number without country code: '$numberWithoutCode' (length: ${numberWithoutCode.length})");

    if (numberWithoutCode.length != 9 || !numberWithoutCode.startsWith('7')) {
      debugPrint("❌ Phone number validation failed: invalid Sri Lankan format");
      setState(() {
        _errorMessage = "Please enter a valid Sri Lankan mobile number";
      });
      return;
    }

    debugPrint("✅ Phone number validation passed: $phoneNumber");
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    debugPrint("🔵 Starting phone verification...");
    try {
      await _auth.signInWithOtp(phone: phoneNumber);
      if (mounted) {
        setState(() {
          isLoading = false;
          _verificationId = phoneNumber; // Supabase verifies by phone + code
          _otpRetryCount++;
        });
        _startResendCountdown();
        _showOTPDialog();
      }
      print("🔵 verifyPhoneNumber() call completed");
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = authErrorMessage(e);
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint("\n❌ ========== EXCEPTION IN PHONE VERIFICATION ==========");
      debugPrint("❌ Exception type: ${e.runtimeType}");
      debugPrint("❌ Exception details: $e");
      debugPrint("❌ Stack trace: ${StackTrace.current}");

      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = "Failed to send verification code: ${e.toString()}. Please try again.";
        });
        HapticFeedback.heavyImpact();
      }
    }
    debugPrint("🔵 ========== PHONE LOGIN METHOD ENDED ==========\n");
  }

  void _showOTPDialog() {
    List<TextEditingController> controllers = List.generate(
      6,
          (index) => TextEditingController(),
    );

    List<FocusNode> focusNodes = List.generate(
      6,
          (index) => FocusNode(),
    );

    for (int i = 0; i < 6; i++) {
      controllers[i].addListener(() {
        String otp = controllers.map((c) => c.text).join();
        if (otp.length == 6) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.of(context).pop();
              _verifyOTPCodeFromDialog(otp, controllers, focusNodes);
            }
          });
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogTheme = Theme.of(context);
          final dialogCs = dialogTheme.colorScheme;
          bool isVerifying = false;
          String? otpError;

          void verifyOTP() async {
            debugPrint("\n🔵 ========== OTP DIALOG VERIFICATION STARTED ==========");

            setDialogState(() {
              isVerifying = true;
              otpError = null;
            });

            String otp = controllers.map((controller) => controller.text).join();
            debugPrint("🔵 OTP from dialog: '$otp' (length: ${otp.length})");

            if (otp.length != 6) {
              debugPrint("❌ OTP validation failed: length is ${otp.length}, expected 6");
              setDialogState(() {
                isVerifying = false;
                otpError = "Please enter all 6 digits";
              });
              return;
            }

            debugPrint("✅ OTP validation passed");
            debugPrint("🔵 Verification ID: '$_verificationId'");

            try {
              if (_verificationId != null) {
                await _auth.verifyOTP(
                  phone: _verificationId!,
                  token: otp,
                  type: OtpType.sms,
                );

                print("✅ Closing OTP dialog and navigating to home");

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/home');
                }
              } else {
                debugPrint("❌ Verification ID is null in OTP dialog!");
                setDialogState(() {
                  isVerifying = false;
                  otpError = "Verification session expired. Please try again.";
                });
              }
            } on AuthException catch (e) {
              setDialogState(() {
                isVerifying = false;
                otpError = authErrorMessage(e);
                for (var controller in controllers) {
                  controller.clear();
                }
                focusNodes[0].requestFocus();
              });
            } catch (e) {
              debugPrint("\n❌ ========== OTP DIALOG EXCEPTION ==========");
              debugPrint("❌ Exception type: ${e.runtimeType}");
              debugPrint("❌ Exception details: $e");

              setDialogState(() {
                isVerifying = false;
                otpError = "Unexpected error: ${e.toString()}";
              });
            }
            debugPrint("🔵 ========== OTP DIALOG VERIFICATION ENDED ==========\n");
          }

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: dialogCs.surface,
              title: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: dialogCs.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Verification Code",
                    style: dialogTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: dialogCs.onSurface,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Enter the 6-digit code sent to",
                    style: dialogTheme.textTheme.bodyMedium?.copyWith(
                      color: dialogCs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phoneController.text,
                    style: dialogTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: dialogCs.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      6,
                          (index) => SizedBox(
                        width: 40,
                        child: TextField(
                          controller: controllers[index],
                          focusNode: focusNodes[index],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: dialogCs.outline,
                                width: 2,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: dialogCs.primary,
                                width: 2,
                              ),
                            ),
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              focusNodes[index - 1].requestFocus();
                            }
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: dialogTheme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (otpError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      otpError!,
                      style: dialogTheme.textTheme.bodySmall?.copyWith(
                        color: dialogCs.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: dialogTheme.textTheme.bodySmall?.copyWith(
                          color: dialogCs.onSurfaceVariant,
                        ),
                      ),
                      GestureDetector(
                        onTap: _canResend
                            ? () {
                          Navigator.pop(context);
                          for (var controller in controllers) {
                            controller.clear();
                          }
                          _loginWithPhoneNumber();
                        }
                            : null,
                        child: Text(
                          _canResend ? "Resend" : "Resend in ${_resendCountdown}s",
                          style: dialogTheme.textTheme.bodySmall?.copyWith(
                            color: _canResend ? dialogCs.primary : dialogCs.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_otpRetryCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Attempts: $_otpRetryCount / $_maxOtpRetries",
                      style: dialogTheme.textTheme.bodySmall?.copyWith(
                        color: dialogCs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Cancel",
                    style: dialogTheme.textTheme.labelLarge?.copyWith(
                      color: dialogCs.onSurfaceVariant,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isVerifying ? null : verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogCs.primary,
                    foregroundColor: dialogCs.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isVerifying
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: dialogCs.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    "Verify",
                    style: dialogTheme.textTheme.labelLarge?.copyWith(
                      color: dialogCs.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _verifyOTPCodeFromDialog(
      String otp,
      List<TextEditingController> controllers,
      List<FocusNode> focusNodes,
      ) async {
    debugPrint("\n🔵 ========== AUTO-SUBMIT OTP VERIFICATION ==========");

    try {
      if (_verificationId != null) {
        await _auth.verifyOTP(
          phone: _verificationId!,
          token: otp,
          type: OtpType.sms,
        );

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      debugPrint("❌ Auto-submit verification failed: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: cs.onPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? cs.error : cs.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // The profile row is created by a database trigger when the auth user is created.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withValues(alpha: 0.08),
                    cs.surface,
                    cs.surface,
                    cs.primary.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: -100,
            right: -100,
            child: Opacity(
              opacity: 0.1,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -80,
            left: -80,
            child: Opacity(
              opacity: 0.1,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Hero(
                                tag: 'logo',
                                child: Image.asset(
                                  'assets/images/zing.png',
                                  height: 100,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              "Welcome Back!",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sign in to continue to Zing",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),

                            Container(
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: ZingShadows.soft,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildToggleButton(
                                        icon: Icons.phone_android_rounded,
                                        label: "Phone",
                                        isSelected: isPhoneSelected,
                                        onTap: () => setState(() {
                                          isPhoneSelected = true;
                                          _errorMessage = null;
                                        }),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildToggleButton(
                                        icon: Icons.email_rounded,
                                        label: "Email",
                                        isSelected: !isPhoneSelected,
                                        onTap: () => setState(() {
                                          isPhoneSelected = false;
                                          _errorMessage = null;
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.1),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: isPhoneSelected
                                  ? _buildPhoneInputField()
                                  : _buildEmailPasswordFields(),
                            ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: cs.error.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: cs.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: cs.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            _buildPrimaryButton(
                              onPressed: _checkTermsAndLogin,
                              text: isPhoneSelected ? "Send Verification Code" : "Sign In",
                              isLoading: isLoading,
                            ),

                            const SizedBox(height: 4),

                            const SizedBox(height: 32),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/createAccount');
                                  },
                                  child: Text(
                                    "Sign Up",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            GestureDetector(
                              onTap: _showTermsDialog,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isTermsAccepted ? Icons.check_circle : Icons.check_circle_outline,
                                    color: isTermsAccepted ? cs.primary : cs.outline,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "I agree to the Terms and Conditions",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isTermsAccepted ? cs.primary : cs.onSurfaceVariant,
                                      fontWeight: isTermsAccepted ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (Navigator.of(context).canPop())
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text('Not now', style: ZingType.body(cs.primary)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputField() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      key: const ValueKey("phone"),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZingShadows.soft,
      ),
      child: TextFormField(
        controller: phoneController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(20),
          hintText: "Phone Number",
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: cs.outline,
            fontSize: 16,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(16),
            child: Icon(
              Icons.phone_android_rounded,
              color: cs.primary,
              size: 22,
            ),
          ),
          border: InputBorder.none,
        ),
        keyboardType: TextInputType.phone,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Phone number is required";
          }
          if (!value.startsWith('+94')) {
            return "Phone number must start with +94";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildEmailPasswordFields() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      key: const ValueKey("email"),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ZingShadows.soft,
          ),
          child: TextFormField(
            controller: emailController,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(20),
              hintText: "Email Address",
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: cs.outline,
                fontSize: 16,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.email_rounded,
                  color: cs.primary,
                  size: 22,
                ),
              ),
              border: InputBorder.none,
            ),
            keyboardType: TextInputType.emailAddress,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Email is required";
              }
              if (!value.contains('@') || !value.contains('.')) {
                return "Please enter a valid email address";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ZingShadows.soft,
          ),
          child: TextFormField(
            controller: passwordController,
            obscureText: !isPasswordVisible,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(20),
              hintText: "Password",
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: cs.outline,
                fontSize: 16,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.lock_rounded,
                  color: cs.primary,
                  size: 22,
                ),
              ),
              suffixIcon: GestureDetector(
                onTap: () => setState(() {
                  isPasswordVisible = !isPasswordVisible;
                }),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: cs.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ),
              border: InputBorder.none,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Password is required";
              }
              if (value.length < 6) {
                return "Password must be at least 6 characters";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Text(
              "Forgot Password?",
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback onPressed,
    required String text,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: cs.onPrimary,
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: cs.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: cs.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
