import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/screen/StartingScreens/LoginScreen.dart' show authErrorMessage;
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({Key? key}) : super(key: key);

  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final List<TextEditingController> otpControllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> otpFocusNodes = List.generate(6, (index) => FocusNode());

  // Focus nodes
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  // Forms
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _nameFormKey = GlobalKey<FormState>();
  int _otpRetryCount = 0;
  final int _maxOtpRetries = 3;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _canResend = true;
  // State variables
  bool isPhoneSelected = false;
  String _selectedRole = 'User';
  bool isLoading = false;
  bool _isValidating = false;
  String verificationId = "";
  String? _errorMessage;
  bool _passwordVisible = false;
  int _currentStep = 0;
  final int _totalSteps = 3;
  bool _keyboardVisible = false;
  bool _termsAccepted = true;
  bool _nameValid = false;
  bool _emailValid = false;
  bool _passwordValid = false;
  bool _phoneValid = false;
  bool _otpValid = false;
  bool _isDarkMode = false;
  DateTime? _lastButtonPress;

  // Animation controllers
  late final AnimationController _pageController;
  late final AnimationController _loadingController;
  late final AnimationController _buttonController;
  late final AnimationController _stepController;
  late final Animation<double> _buttonScaleAnimation;
  late final Animation<double> _stepAnimation;

  @override
  void initState() {
    super.initState();
    _checkFirebaseConfig();
    _checkDarkMode();
    _initializeAnimations();
    _setupKeyboardListener();
    _setupOTPListeners();
    _setupValidationListeners();
    _configureStatusBar();
    _setupAuthStateListener();

    // Ensure forms are ready after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to ensure forms are initialized
      }
    });
  }

  void _initializeAnimations() {
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));

    _stepAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _stepController,
      curve: Curves.easeOutCubic,
    ));

    _stepController.forward();
  }

  void _setupKeyboardListener() {
    KeyboardVisibilityController().onChange.listen((bool visible) {
      if (mounted) {
        setState(() {
          _keyboardVisible = visible;
        });
      }
    });
  }

  void _setupOTPListeners() {
    for (int i = 0; i < 6; i++) {
      otpControllers[i].addListener(() {
        if (otpControllers[i].text.length == 1 && i < 5) {
          otpFocusNodes[i + 1].requestFocus();
        }

        // Auto-submit when all fields are filled
        String otp = otpControllers.map((c) => c.text).join();
        if (otp.length == 6 && !isLoading && mounted) {
          // Small delay to ensure user sees the last digit
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !isLoading) {
              _verifyOTP();
            }
          });
        }
      });
    }
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
  void _setupValidationListeners() {
    nameController.addListener(() {
      if (mounted) {
        setState(() {
          _nameValid = nameController.text.trim().length >= 2;
        });
      }
    });

    emailController.addListener(() {
      if (mounted) {
        setState(() {
          _emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(emailController.text.trim());
        });
      }
    });

    passwordController.addListener(() {
      if (mounted) {
        setState(() {
          _passwordValid = passwordController.text.trim().length >= 6;
        });
      }
    });

    phoneController.addListener(() {
      if (mounted) {
        setState(() {
          _phoneValid = RegExp(r'^[1-9][0-9]{8}$').hasMatch(phoneController.text.trim());
        });
      }
    });
  }

  void _configureStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _checkDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final bool storedPreference = prefs.getBool('darkMode') ?? false;
    if (mounted) {
      setState(() {
        _isDarkMode = storedPreference;
      });
    }
  }

  void _setupAuthStateListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((AuthState state) {
      final user = state.session?.user;
      if (user != null) {
        print("User authenticated: ${user.email ?? user.phone}");
      } else {
        print("User signed out");
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel(); // Add this line
    _pageController.dispose();
    _loadingController.dispose();
    _buttonController.dispose();
    _stepController.dispose();

    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    nameController.dispose();

    nameFocusNode.dispose();
    emailFocusNode.dispose();
    phoneFocusNode.dispose();
    passwordFocusNode.dispose();

    for (var controller in otpControllers) {
      controller.dispose();
    }

    for (var node in otpFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }
  // Navigation methods
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });
      HapticFeedback.lightImpact();
      _stepController.reset();
      _stepController.forward();
    } else {
      _finishRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      HapticFeedback.lightImpact();
      _stepController.reset();
      _stepController.forward();
    } else {
      Navigator.pop(context);
    }
  }

  void _selectMethod(bool usePhone) {
    if (isPhoneSelected != usePhone) {
      setState(() {
        isPhoneSelected = usePhone;
        _errorMessage = null;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });

    await prefs.setBool('darkMode', _isDarkMode);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  // Enhanced validation methods
  Future<bool> _safeFormValidation() async {
    if (!mounted) return false;

    setState(() {
      _isValidating = true;
    });

    // Small delay to ensure forms are ready
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) {
      setState(() {
        _isValidating = false;
      });
      return false;
    }

    final result = _validateCurrentStep();

    setState(() {
      _isValidating = false;
    });

    return result;
  }

  bool _validateCurrentStep() {
    if (!mounted) return false;

    switch (_currentStep) {
      case 0:
        return true;

      case 1:
        if (!_nameValid) {
          _showValidationError("Please enter your name");
          return false;
        }

        if (isPhoneSelected) {
          return _validatePhoneFormSafely();
        } else {
          return _validateEmailFormSafely();
        }

      case 2:
        if (isPhoneSelected) {
          String otp = otpControllers.map((c) => c.text).join();
          if (otp.length != 6) {
            _showValidationError("Please enter all 6 digits");
            return false;
          }
          return true;
        }

        if (!_termsAccepted) {
          _showValidationError("Please accept the terms and conditions");
          return false;
        }
        return true;

      default:
        return false;
    }
  }

  bool _validatePhoneFormSafely() {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final phoneFormState = _phoneFormKey.currentState;
          if (phoneFormState != null) {
            phoneFormState.validate();
          }
        }
      });

      final phoneFormState = _phoneFormKey.currentState;
      if (phoneFormState == null) {
        return _validatePhoneDirectly();
      }
      return phoneFormState.validate();
    } catch (e) {
      print("Phone form validation error: $e");
      return _validatePhoneDirectly();
    }
  }

  bool _validateEmailFormSafely() {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final emailFormState = _emailFormKey.currentState;
          if (emailFormState != null) {
            emailFormState.validate();
          }
        }
      });

      final emailFormState = _emailFormKey.currentState;
      if (emailFormState == null) {
        return _validateEmailDirectly();
      }
      return emailFormState.validate();
    } catch (e) {
      print("Email form validation error: $e");
      return _validateEmailDirectly();
    }
  }

  bool _validatePhoneDirectly() {
    final phone = phoneController.text.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    if (cleanPhone.isEmpty) {
      _showValidationError("Phone number is required");
      return false;
    }

    // More specific Sri Lankan validation
    if (!RegExp(r'^7[01245678][0-9]{7}$').hasMatch(cleanPhone)) {
      _showValidationError("Please enter a valid Sri Lankan mobile number");
      return false;
    }

    if (phone != cleanPhone) {
      phoneController.text = cleanPhone;
    }

    return true;
  }
  bool _validateEmailDirectly() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      _showValidationError("Email is required");
      return false;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showValidationError("Please enter a valid email");
      return false;
    }

    if (password.isEmpty) {
      _showValidationError("Password is required");
      return false;
    }

    if (password.length < 6) {
      _showValidationError("Password must be at least 6 characters");
      return false;
    }

    return true;
  }

  void _showValidationError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });

    // Auto-clear error after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted && _errorMessage == message) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  void _processCurrentStep() async {
    // Debounce rapid button presses
    final now = DateTime.now();
    if (_lastButtonPress != null &&
        now.difference(_lastButtonPress!).inMilliseconds < 500) {
      return;
    }
    _lastButtonPress = now;

    if (isLoading || _isValidating) return;

    // Check network connectivity first
    if (!await _checkNetworkConnectivity()) {
      _showValidationError("No internet connection. Please check your network.");
      HapticFeedback.heavyImpact();
      return;
    }

    _buttonController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _buttonController.reverse();

    // Use safe validation
    final isValid = await _safeFormValidation();
    if (!isValid) {
      HapticFeedback.mediumImpact();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _errorMessage = null);

    switch (_currentStep) {
      case 0:
        _nextStep();
        break;
      case 1:
        if (isPhoneSelected) {
          _sendPhoneVerification();
        } else {
          _nextStep();
        }
        break;
      case 2:
        _finishRegistration();
        break;
    }
  }
  // Firebase methods
  Future<void> _sendPhoneVerification() async {
    if (_otpRetryCount >= _maxOtpRetries) {
      setState(() {
        _errorMessage = "Maximum attempts reached. Please try again later.";
      });
      return;
    }

    if (!_validatePhoneDirectly()) return;

    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ensure proper format: +94 followed by 9 digits
      final phoneNumber = '+94${phoneController.text.trim()}';

      print("Attempting verification for: $phoneNumber");

      await Supabase.instance.client.auth.signInWithOtp(phone: phoneNumber);
      if (mounted) {
        setState(() {
          verificationId = phoneNumber; // Supabase verifies by phone + code
          isLoading = false;
          _otpRetryCount++;
          _nextStep();
        });
        _startResendCountdown();
      }
      _showSnackBar("Verification code sent to $phoneNumber", isError: false);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = authErrorMessage(e);
          isLoading = false;
        });
      }
      HapticFeedback.heavyImpact();
    } catch (e) {
      print("❌ Phone verification exception: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to send verification code: ${e.toString()}. Please check your internet connection and try again.";
          isLoading = false;
        });
      }
      HapticFeedback.heavyImpact();
    }
  }
  Future<void> _checkFirebaseConfig() async {
    // Nothing to check: Supabase is initialised in main().
  }
  Future<void> _verifyOTP() async {
    final otp = otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      setState(() => _errorMessage = "Please enter all 6 digits");
      HapticFeedback.mediumImpact();
      return;
    }

    // Check if OTP contains only digits
    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = "Invalid code format");
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth
          .verifyOTP(phone: verificationId, token: otp, type: OtpType.sms);
      await _afterPhoneSignIn();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = authErrorMessage(e);
          for (var controller in otpControllers) {
            controller.clear();
          }
          isLoading = false;
        });
        otpFocusNodes[0].requestFocus();
      }
      HapticFeedback.heavyImpact();
    } catch (e) {
      print("❌ OTP verification exception: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "OTP verification error: ${e.toString()}. Please try again.";
          isLoading = false;
        });
      }
      HapticFeedback.heavyImpact();
    }
  }
  Future<void> _createEmailAccount() async {
    if (!mounted) return;

    // Try safe validation first
    final isValid = await _safeFormValidation();
    if (!isValid) {
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create the account. The database creates the profile row from this
      // metadata, and Supabase emails a confirmation link if it is enabled.
      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'name': nameController.text.trim(),
          'phone_number': isPhoneSelected ? '+94${phoneController.text.trim()}' : '',
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Failed to create user account - user is null");
      }

      // With a session (email confirmation off) make sure the profile is complete.
      if (response.session != null) await _saveProfile();

      if (mounted) {
        setState(() => isLoading = false);
        _showSuccessMessage("Account created successfully! Please check your email for verification.");

        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }

    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _errorMessage = authErrorMessage(e);
      });
      HapticFeedback.heavyImpact();

    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = "Registration failed: ${e.toString()}";
        isLoading = false;
      });

      print("🚨 General Error: $e");
      HapticFeedback.heavyImpact();
    }
  }

  /// Completes the signed-in user's profile row (created by a database trigger).
  Future<void> _saveProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client.from('profiles').update({
        'name': nameController.text.trim(),
        if (isPhoneSelected) 'phone_number': '+94${phoneController.text.trim()}',
        if (emailController.text.trim().isNotEmpty) 'email': emailController.text.trim(),
      }).eq('id', user.id);
    } catch (e) {
      print("Failed to save profile: $e");
    }
  }

  Future<void> _afterPhoneSignIn() async {
    try {
      await _saveProfile();

      if (mounted) {
        setState(() => isLoading = false);
        _showSuccessMessage("Phone verification successful!");

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print("Unexpected phone sign-in error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Authentication failed. Please try again.";
          isLoading = false;
        });
      }
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _finishRegistration() async {
    if (isPhoneSelected) {
      await _verifyOTP();
    } else {
      final isValid = await _safeFormValidation();
      if (isValid) {
        await _createEmailAccount();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showSuccessMessage(String message) {
    _showSnackBar(message, isError: false);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isError ? Icons.error_outline : Icons.check_circle,
                color: cs.onPrimary,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? cs.error : ZingColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.7,
            left: 20,
            right: 20
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(cs),
      body: Stack(
        children: [
          _buildBackground(cs),
          SafeArea(
            child: AnimatedBuilder(
              animation: _stepAnimation,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(
                    30 * (1 - _stepAnimation.value),
                    0,
                  ),
                  child: Opacity(
                    opacity: _stepAnimation.value,
                    child: _buildMainContent(cs),
                  ),
                );
              },
            ),
          ),
          if (isLoading) _buildLoadingOverlay(cs),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.onSurface.withOpacity(0.1),
          ),
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: cs.onSurface,
            size: 20,
          ),
          onPressed: _previousStep,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.onSurface.withOpacity(0.1),
            ),
          ),
          child: IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: cs.onSurface,
              size: 20,
            ),
            onPressed: _toggleDarkMode,
          ),
        ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Widget _buildBackground(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.primary.withOpacity(0.03),
            cs.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Subtle geometric patterns
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cs.primary.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cs.secondary.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ColorScheme cs) {
    return Column(
      children: [
        _buildHeader(cs),
        Expanded(
          child: _buildStepContent(cs),
        ),
        if (!_keyboardVisible || MediaQuery.of(context).size.height > 700)
          _buildBottomSection(cs),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          _buildProgressIndicator(cs),
          const SizedBox(height: 24),
          _buildStepTitle(cs),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ColorScheme cs) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Step ${_currentStep + 1} of $_totalSteps",
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${((_currentStep + 1) / _totalSteps * 100).toInt()}%",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: 6,
              width: MediaQuery.of(context).size.width *
                  ((_currentStep + 1) / _totalSteps) * 0.87, // Account for padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary,
                    cs.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTitle(ColorScheme cs) {
    final theme = Theme.of(context);
    String title;
    String subtitle;

    switch (_currentStep) {
      case 0:
        title = "Choose Your Role";
        subtitle = "How would you like to use Zing?";
        break;
      case 1:
        title = "Create Your Account";
        subtitle = "Let's get you set up with your credentials";
        break;
      case 2:
        if (isPhoneSelected) {
          title = "Verify Your Phone";
          subtitle = "Enter the 6-digit code we sent to your phone";
        } else {
          title = "Review & Confirm";
          subtitle = "Almost done! Please review your information";
        }
        break;
      default:
        title = "Welcome to Zing";
        subtitle = "Let's get started";
    }

    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            color: cs.onSurface.withOpacity(0.6),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepContent(ColorScheme cs) {
    switch (_currentStep) {
      case 0:
        return _buildRoleSelectionStep(cs);
      case 1:
        return _buildCredentialsStep(cs);
      case 2:
        return isPhoneSelected
            ? _buildOTPVerificationStep(cs)
            : _buildReviewStep(cs);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRoleSelectionStep(ColorScheme cs) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // App logo section
          Container(
            margin: const EdgeInsets.only(bottom: 48),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 36,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Zing",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  "Food Delivery & Restaurant Management",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Role options
          _buildRoleCard(
            title: "Customer",
            description: "Order food from your favorite restaurants",
            icon: Icons.person_outline,
            color: cs.primary,
            isSelected: _selectedRole == 'User',
            onTap: () => setState(() => _selectedRole = 'User'),
            cs: cs,
          ),

          const SizedBox(height: 16),

          _buildRoleCard(
            title: "Client",
            description: "Manage your restaurant and receive orders",
            icon: Icons.store_outlined,
            color: cs.secondary,
            isSelected: _selectedRole == 'Owner',
            onTap: () => setState(() => _selectedRole = 'Owner'),
            cs: cs,
          ),

          const SizedBox(height: 32),

          // Features info
          _buildFeaturesInfo(cs),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : cs.onSurface.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : cs.onSurface.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                Icons.check,
                color: cs.onPrimary,
                size: 14,
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesInfo(ColorScheme cs) {
    final theme = Theme.of(context);
    final List<String> features = _selectedRole == 'User'
        ? [
      "Browse restaurants and menus",
      "Order food for delivery or pickup",
      "Track orders in real-time",
      "Save favorite places",
      "Rate and review experiences"
    ]
        : [
      "Manage restaurant profile and menu",
      "Receive and process orders",
      "Track sales and analytics",
      "Communicate with customers",
      "Set delivery zones and fees"
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.onSurface.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${_selectedRole == 'User' ? 'As a Customer' : 'As a Client'}, you can:",
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 12,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildCredentialsStep(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Name field
          _buildTextField(
            controller: nameController,
            focusNode: nameFocusNode,
            label: "Full Name",
            hint: "Enter your full name",
            icon: Icons.person_outline,
            isValid: _nameValid,
            cs: cs,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Name is required";
              }
              if (value.trim().length < 2) {
                return "Name must be at least 2 characters";
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Auth method toggle
          _buildAuthMethodToggle(cs),

          const SizedBox(height: 24),

          // Email or phone form
          if (isPhoneSelected)
            _buildPhoneField(cs)
          else
            _buildEmailFields(cs),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(cs),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool isValid,
    required ColorScheme cs,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus
                  ? cs.primary
                  : cs.onSurface.withOpacity(0.1),
            ),
            boxShadow: ZingShadows.soft,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurface,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.4),
              ),
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Icon(
                icon,
                color: cs.primary,
                size: 20,
              ),
              suffixIcon: suffixIcon,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthMethodToggle(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              title: "Email",
              icon: Icons.email_outlined,
              isSelected: !isPhoneSelected,
              onTap: () => _selectMethod(false),
              cs: cs,
            ),
          ),
          Expanded(
            child: _buildToggleOption(
              title: "Phone",
              icon: Icons.phone_outlined,
              isSelected: isPhoneSelected,
              onTap: () => _selectMethod(true),
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? cs.onPrimary : cs.onSurface.withOpacity(0.6),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isSelected ? cs.onPrimary : cs.onSurface.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailFields(ColorScheme cs) {
    final theme = Theme.of(context);

    return Form(
      key: _emailFormKey,
      child: Column(
        children: [
          _buildTextField(
            controller: emailController,
            focusNode: emailFocusNode,
            label: "Email Address",
            hint: "Enter your email address",
            icon: Icons.email_outlined,
            isValid: _emailValid,
            cs: cs,
            keyboardType: TextInputType.emailAddress,
            suffixIcon: emailController.text.isNotEmpty
                ? Icon(
              _emailValid ? Icons.check_circle : Icons.error_outline,
              color: _emailValid ? ZingColors.success : cs.error,
              size: 20,
            )
                : null,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Email is required";
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return "Please enter a valid email";
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(cs),
          if (passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPasswordStrength(cs),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordField(ColorScheme cs) {
    final theme = Theme.of(context);

    return _buildTextField(
      controller: passwordController,
      focusNode: passwordFocusNode,
      label: "Password",
      hint: "Create a strong password",
      icon: Icons.lock_outline,
      isValid: _passwordValid,
      cs: cs,
      obscureText: !_passwordVisible,
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (passwordController.text.isNotEmpty)
            Icon(
              _passwordValid ? Icons.check_circle : Icons.error_outline,
              color: _passwordValid ? ZingColors.success : cs.error,
              size: 20,
            ),
          IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility_off : Icons.visibility,
              color: cs.onSurface.withOpacity(0.6),
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _passwordVisible = !_passwordVisible;
              });
            },
          ),
        ],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Password is required";
        }
        if (value.length < 6) {
          return "Password must be at least 6 characters";
        }
        return null;
      },
    );
  }

  Widget _buildPasswordStrength(ColorScheme cs) {
    final theme = Theme.of(context);
    final String password = passwordController.text;
    int strength = 0;

    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    String label;
    Color color;
    double strengthValue = strength / 4;

    if (strengthValue <= 0.25) {
      label = "Weak";
      color = cs.error;
    } else if (strengthValue <= 0.5) {
      label = "Fair";
      color = ZingColors.warning;
    } else if (strengthValue <= 0.75) {
      label = "Good";
      color = ZingColors.warning;
    } else {
      label = "Strong";
      color = ZingColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.onSurface.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Password Strength",
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: strengthValue,
            backgroundColor: cs.onSurface.withOpacity(0.1),
            color: color,
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(ColorScheme cs) {
    final theme = Theme.of(context);

    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Phone Number",
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: phoneFocusNode.hasFocus
                    ? cs.primary
                    : cs.onSurface.withOpacity(0.1),
              ),
              boxShadow: ZingShadows.soft,
            ),
            child: TextFormField(
              controller: phoneController,
              focusNode: phoneFocusNode,
              keyboardType: TextInputType.phone,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurface,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Enter your phone number",
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.4),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        color: cs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "+94",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                suffixIcon: phoneController.text.isNotEmpty
                    ? Icon(
                  _phoneValid ? Icons.check_circle : Icons.error_outline,
                  color: _phoneValid ? ZingColors.success : cs.error,
                  size: 20,
                )
                    : null,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Phone number is required";
                }
                if (!RegExp(r'^[1-9][0-9]{8}$').hasMatch(value)) {
                  return "Please enter 9 digits after +94";
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPVerificationStep(ColorScheme cs) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Phone display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_android,
                  color: cs.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  "+94 ${phoneController.text}",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _previousStep,
                  child: Icon(
                    Icons.edit,
                    size: 16,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // OTP fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6,
                  (index) => _buildOTPField(index, cs),
            ),
          ),

          const SizedBox(height: 32),

          if (_errorMessage != null) ...[
            _buildErrorMessage(cs),
            const SizedBox(height: 24),
          ],

          // Resend section
          _buildResendSection(cs),
        ],
      ),
    );
  }

  Widget _buildOTPField(int index, ColorScheme cs) {
    final theme = Theme.of(context);

    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: otpFocusNodes[index].hasFocus
              ? cs.primary
              : cs.onSurface.withOpacity(0.1),
          width: otpFocusNodes[index].hasFocus ? 2 : 1,
        ),
        boxShadow: ZingShadows.soft,
      ),
      child: TextFormField(
        controller: otpControllers[index],
        focusNode: otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            otpFocusNodes[index - 1].requestFocus();
          }

          if (mounted) {
            setState(() {
              String otp = otpControllers.map((c) => c.text).join();
              _otpValid = otp.length == 6;
            });
          }
        },
        maxLength: 1,
      ),
    );
  }

  Widget _buildResendSection(ColorScheme cs) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.onSurface.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            "Didn't receive the code?",
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _previousStep,
                icon: Icon(
                  Icons.edit,
                  size: 16,
                  color: cs.primary,
                ),
                label: Text(
                  "Change Number",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _canResend ? () {
                  // Reset OTP fields before resending
                  for (var controller in otpControllers) {
                    controller.clear();
                  }
                  _sendPhoneVerification();
                } : null,
                icon: Icon(
                  Icons.refresh,
                  size: 16,
                  color: _canResend ? cs.secondary : cs.onSurface.withOpacity(0.3),
                ),
                label: Text(
                  _canResend
                      ? "Resend Code"
                      : "Resend in ${_resendCountdown}s",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _canResend ? cs.secondary : cs.onSurface.withOpacity(0.3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_otpRetryCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              "Attempts: $_otpRetryCount / $_maxOtpRetries",
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildReviewStep(ColorScheme cs) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: ZingShadows.soft,
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary,
                        cs.primary.withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: cs.onPrimary,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  nameController.text.isEmpty ? "New User" : nameController.text,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selectedRole == 'User'
                        ? cs.primary.withOpacity(0.1)
                        : cs.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedRole == 'User' ? 'Customer' : 'Restaurant Owner',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _selectedRole == 'User'
                          ? cs.primary
                          : cs.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Account details
                _buildDetailRow(
                  icon: Icons.email_outlined,
                  label: "Email",
                  value: emailController.text,
                  cs: cs,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Terms checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _termsAccepted,
                  onChanged: (value) {
                    setState(() {
                      _termsAccepted = value ?? true;
                      if (!_termsAccepted) {
                        _errorMessage = "Please accept the terms and conditions";
                      } else {
                        _errorMessage = null;
                      }
                    });
                  },
                  activeColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                    children: [
                      const TextSpan(text: "I agree to the "),
                      TextSpan(
                        text: "Terms of Service",
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: " and "),
                      TextSpan(
                        text: "Privacy Policy",
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(cs),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme cs,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: cs.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ColorScheme cs) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.error.withOpacity(0.2),
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.error,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _buttonScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _buttonScaleAnimation.value,
                child: _buildPrimaryButton(cs),
              );
            },
          ),
          if (_currentStep <= 1) ...[
            const SizedBox(height: 16),
            _buildSignInLink(cs),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(ColorScheme cs) {
    final theme = Theme.of(context);
    String buttonText;
    switch (_currentStep) {
      case 0:
        buttonText = "Continue";
        break;
      case 1:
        buttonText = isPhoneSelected ? "Send Verification Code" : "Continue";
        break;
      case 2:
        buttonText = isPhoneSelected ? "Verify & Create Account" : "Create Account";
        break;
      default:
        buttonText = "Continue";
    }

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isLoading || _isValidating) ? null : _processCurrentStep,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: (isLoading || _isValidating)
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
                  buttonText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: cs.onPrimary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInLink(ColorScheme cs) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.6),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            "Sign In",
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay(ColorScheme cs) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: ZingShadows.medium,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: cs.primary,
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _getLoadingMessage(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getLoadingMessage() {
    if (_currentStep == 1 && isPhoneSelected) {
      return "Sending verification code...";
    } else if (_currentStep == 2 && isPhoneSelected) {
      return "Verifying code...";
    } else {
      return "Creating your account...";
    }
  }
}
