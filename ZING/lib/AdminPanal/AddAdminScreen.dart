import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../Service/CoustomUserProvider.dart';

class AddAdminScreen extends StatefulWidget {
  @override
  _AddAdminScreenState createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String _phoneNumber = '';
  bool _obscurePassword = true;

  // Focus nodes for form fields
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();

  // Animation controller for form submission
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Field focus change helper
  void _fieldFocusChange(BuildContext context, FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  @override
  Widget build(BuildContext context) {
    final customUserProvider = Provider.of<CustomUserProvider>(context);
    bool isLoading = customUserProvider.isLoading;

    // Get theme colors
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textTheme = Theme.of(context).textTheme;

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: primaryColor, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: Colors.redAccent, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: Colors.redAccent, width: 2.0),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          labelStyle: TextStyle(color: Colors.grey.shade700),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          errorStyle: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, backgroundColor: primaryColor,
            padding: EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 4,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Add Admin',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              // Background decoration
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
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
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Main content
              GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Icon(
                            Icons.admin_panel_settings,
                            size: 80,
                            color: primaryColor.withOpacity(0.8),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Admin Registration',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Enter the details to create a new admin account',
                            style: textTheme.titleSmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32),

                          // Form
                          Card(
                            elevation: 8,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildNameField(),
                                    SizedBox(height: 20),
                                    _buildEmailField(),
                                    SizedBox(height: 20),
                                    _buildPasswordField(),
                                    SizedBox(height: 20),
                                    _buildPhoneField(),
                                    SizedBox(height: 32),
                                    _buildSubmitButton(isLoading),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Loading overlay
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SpinKitFadingCircle(
                            color: primaryColor,
                            size: 60.0,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Creating admin account...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      focusNode: _nameFocus,
      decoration: InputDecoration(
        labelText: 'Full Name',
        hintText: 'Enter administrator\'s full name',
        prefixIcon: Icon(Icons.person_outline),
        helperText: ' ',
      ),
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      onChanged: (value) => setState(() => _name = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a name';
        }
        return null;
      },
      onFieldSubmitted: (_) => _fieldFocusChange(context, _nameFocus, _emailFocus),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      focusNode: _emailFocus,
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'Enter business email address',
        prefixIcon: Icon(Icons.email_outlined),
        helperText: ' ',
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onChanged: (value) => setState(() => _email = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter an email address';
        }
        // Basic email validation
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
      onFieldSubmitted: (_) => _fieldFocusChange(context, _emailFocus, _passwordFocus),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      focusNode: _passwordFocus,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Create a secure password',
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey.shade600,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        helperText: 'Password should be at least 8 characters',
      ),
      textInputAction: TextInputAction.next,
      obscureText: _obscurePassword,
      onChanged: (value) => setState(() => _password = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
      onFieldSubmitted: (_) => _fieldFocusChange(context, _passwordFocus, _phoneFocus),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      focusNode: _phoneFocus,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter contact phone number',
        prefixIcon: Icon(Icons.phone_outlined),
        helperText: 'Include country code if applicable',
      ),
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onChanged: (value) => setState(() => _phoneNumber = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a phone number';
        }
        return null;
      },
      onFieldSubmitted: (_) => _submitForm(),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitForm,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 20),
                SizedBox(width: 12),
                Text(
                  'CREATE ADMIN ACCOUNT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Animate button press
      _animationController.forward().then((_) {
        _animationController.reverse();
      });

      // Submit form
      final customUserProvider = Provider.of<CustomUserProvider>(context, listen: false);
      customUserProvider.addAdmin(
        email: _email,
        password: _password,
        name: _name,
        phoneNumber: _phoneNumber,
      );

      // Navigate back (keeping the original functionality)
      Navigator.pop(context);
    }
  }
}