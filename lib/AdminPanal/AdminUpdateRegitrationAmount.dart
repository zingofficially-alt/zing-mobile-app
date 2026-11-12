import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Service/SettingProvider.dart';
import '../Service/ThemeProvider.dart';

class EnhancedAdminUpdateRegistrationAmountScreen extends StatefulWidget {
  @override
  State<EnhancedAdminUpdateRegistrationAmountScreen> createState() =>
      _EnhancedAdminUpdateRegistrationAmountScreenState();
}

class _EnhancedAdminUpdateRegistrationAmountScreenState
    extends State<EnhancedAdminUpdateRegistrationAmountScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController();
  final _amountFocus = FocusNode();
  final _currencyFocus = FocusNode();

  // Default values
  static const double DEFAULT_REGISTRATION_AMOUNT = 0.0;
  static const String DEFAULT_CURRENCY = 'USD';

  bool _isLoading = false;
  bool _isUpdating = false;
  double? _initialAmount;
  String? _initialCurrency;
  bool _fieldsChanged = false;
  bool _isFirstTimeSetup = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupListeners();
    _loadCurrentSettings();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _setupListeners() {
    _amountController.addListener(_checkFieldsChanged);
    _currencyController.addListener(_checkFieldsChanged);
  }

  void _checkFieldsChanged() {
    if (_initialAmount != null && _initialCurrency != null) {
      final newAmount = double.tryParse(_amountController.text) ?? 0;
      final newCurrency = _currencyController.text.trim();

      setState(() {
        _fieldsChanged =
            newAmount != _initialAmount || newCurrency != _initialCurrency;
      });
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _amountFocus.dispose();
    _currencyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      double currentAmount = DEFAULT_REGISTRATION_AMOUNT;
      String currentCurrency = DEFAULT_CURRENCY;
      bool settingsExist = true;

      // Try to load existing settings
      try {
        currentAmount = await settingsProvider.getRegistrationAmount();
        currentCurrency = await settingsProvider.getCurrency();
        print('Loaded existing settings: Amount=$currentAmount, Currency=$currentCurrency');
      } catch (e) {
        settingsExist = false;
        _isFirstTimeSetup = true;
        print('Settings not found, initializing with defaults: Amount=$currentAmount, Currency=$currentCurrency');
      }

      if (mounted) {
        setState(() {
          _amountController.text = currentAmount.toString();
          _currencyController.text = currentCurrency;
          _initialAmount = currentAmount;
          _initialCurrency = currentCurrency;
          _fieldsChanged = _isFirstTimeSetup; // Enable save button for first-time setup
        });

        _startAnimations();

        // Show helpful message for first-time setup
        if (_isFirstTimeSetup) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              _showMessage(
                '👋 Welcome! Please configure your registration fee settings.',
                isError: false,
              );
            }
          });
        }
      }
    } catch (e) {
      print('Unexpected error in _loadCurrentSettings: $e');
      if (mounted) {
        _showMessage('Settings initialized with defaults', isError: false);

        // Still set defaults even if there's an error
        setState(() {
          _amountController.text = DEFAULT_REGISTRATION_AMOUNT.toString();
          _currencyController.text = DEFAULT_CURRENCY;
          _initialAmount = DEFAULT_REGISTRATION_AMOUNT;
          _initialCurrency = DEFAULT_CURRENCY;
          _fieldsChanged = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startAnimations() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            _buildMainContent(),
            if (_isUpdating) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppBar(
      elevation: 0,
      backgroundColor: cs.surface,
      surfaceTintColor: cs.surface,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Registration Settings',
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        if (!_isLoading)
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.primary),
            onPressed: _loadCurrentSettings,
            tooltip: 'Refresh settings',
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 24),
            _buildFormCard(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary,
              cs.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.payments_rounded,
                color: cs.onPrimary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registration Fee Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFirstTimeSetup
                        ? 'Set up the amount new users pay during registration'
                        : 'Configure the amount new users pay during registration',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onPrimary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Fee Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (_isFirstTimeSetup) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ZingColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ZingColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isFirstTimeSetup
                    ? 'Set the initial registration fee and currency for new user accounts'
                    : 'Update the registration fee and currency for new user accounts',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              _buildAmountField(),
              const SizedBox(height: 24),
              _buildCurrencyField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _amountFocus.hasFocus
                  ? cs.primary
                  : cs.outlineVariant,
              width: _amountFocus.hasFocus ? 2 : 1,
            ),
          ),
          child: TextFormField(
            controller: _amountController,
            focusNode: _amountFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Enter registration fee amount',
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a registration amount';
              }
              final amount = double.tryParse(value.trim());
              if (amount == null || amount < 0) {
                return 'Please enter a valid amount';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_currencyFocus);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyField() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currency Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _currencyFocus.hasFocus
                  ? cs.primary
                  : cs.outlineVariant,
              width: _currencyFocus.hasFocus ? 2 : 1,
            ),
          ),
          child: TextFormField(
            controller: _currencyController,
            focusNode: _currencyFocus,
            textCapitalization: TextCapitalization.characters,
            maxLength: 3,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., USD, EUR, GBP',
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZingColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.currency_exchange_rounded,
                  color: ZingColors.success,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a currency code';
              }
              if (value.trim().length != 3) {
                return 'Currency code must be 3 characters';
              }
              if (!RegExp(r'^[A-Z]+$').hasMatch(value.trim())) {
                return 'Currency code must contain only letters';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _fieldsChanged
            ? LinearGradient(
          colors: [cs.primary, cs.secondary],
        )
            : null,
        color: _fieldsChanged ? null : cs.outlineVariant,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _fieldsChanged
            ? [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _fieldsChanged && !_isUpdating ? _submitForm : null,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _fieldsChanged
                      ? (_isFirstTimeSetup ? Icons.rocket_launch_rounded : Icons.save_rounded)
                      : Icons.check_circle_rounded,
                  color: _fieldsChanged ? cs.onPrimary : cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _fieldsChanged
                      ? (_isFirstTimeSetup ? 'Setup Registration' : 'Save Changes')
                      : 'No Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _fieldsChanged ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading settings...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                _isFirstTimeSetup ? 'Setting up registration...' : 'Updating settings...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    final currency = _currencyController.text.trim().toUpperCase();

    if (amount == null) {
      _showMessage('Please enter a valid amount', isError: true);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.updateRegistrationAmount(amount, currency);

      if (mounted) {
        setState(() {
          _initialAmount = amount;
          _initialCurrency = currency;
          _fieldsChanged = false;
        });

        final message = _isFirstTimeSetup
            ? 'Registration settings configured successfully! 🎉'
            : 'Registration settings updated successfully!';

        _showMessage(message);

        // Reset first-time setup flag
        _isFirstTimeSetup = false;
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Failed to update settings: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Remove any existing overlay
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 100, // Position below app bar
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isError ? cs.error : ZingColors.success,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Auto-remove after duration
    Timer(Duration(seconds: isError ? 4 : 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }
}

// Usage for backward compatibility
class AdminUpdateRegistrationAmountScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EnhancedAdminUpdateRegistrationAmountScreen();
  }
}
