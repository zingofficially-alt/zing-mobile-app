import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:zing/Service/PushService.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/Service/ApiClient.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zing/Service/ThameProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Service/CoustomUserProvider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  bool _notificationsEnabled = true;
  final bool _showCurrentPassword = false;
  final bool _showNewPassword = false;
  bool _isLoading = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    PushService.isEnabled().then((v) {
      if (mounted) setState(() => _notificationsEnabled = v);
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _changePassword(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool localShowCurrentPassword = false;
    bool localShowNewPassword = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: cs.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Change Password',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Form fields
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        // Current password field
                        TextFormField(
                          controller: currentPasswordController,
                          obscureText: !localShowCurrentPassword,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            labelStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: cs.onSurfaceVariant,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                localShowCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  localShowCurrentPassword = !localShowCurrentPassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Please enter your current password'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // New password field
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: !localShowNewPassword,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: cs.onSurfaceVariant,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                localShowNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  localShowNewPassword = !localShowNewPassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) =>
                          value == null || value.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Confirm password field
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: !localShowNewPassword,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: cs.onSurfaceVariant,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) =>
                          value != newPasswordController.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: cs.onSurfaceVariant,
                            side: BorderSide(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'Cancel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(context).pop();
                              await _updatePassword(
                                currentPasswordController.text.trim(),
                                newPasswordController.text.trim(),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                          ),
                          child: Text(
                            'Update',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updatePassword(String currentPassword, String newPassword) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Verify the current password, then set the new one.
        await Supabase.instance.client.auth
            .signInWithPassword(email: user.email!, password: currentPassword);
        await Supabase.instance.client.auth
            .updateUser(UserAttributes(password: newPassword));

        _showSuccessSnackBar('Password updated successfully');
      }
    } catch (e) {
      String errorMessage = 'Error updating password';
      if (e.toString().toLowerCase().contains('invalid login') || e.toString().contains('invalid_credentials')) {
        errorMessage = 'Incorrect current password';
      } else if (e.toString().contains('requires-recent-login')) {
        errorMessage = 'Please log in again to change your password';
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeEmail(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final TextEditingController newEmailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool showPassword = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          color: cs.tertiary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Change Email',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Form fields
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        // New email field
                        TextFormField(
                          controller: newEmailController,
                          keyboardType: TextInputType.emailAddress,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            labelText: 'New Email Address',
                            labelStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.email,
                              color: cs.onSurfaceVariant,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your new email';
                            }
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password field for re-authentication
                        TextFormField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            labelStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: cs.onSurfaceVariant,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Please enter your password'
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ZingColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: ZingColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A verification email will be sent to your new email address.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: cs.onSurfaceVariant,
                            side: BorderSide(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'Cancel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(context).pop();
                              await _updateEmail(
                                newEmailController.text.trim(),
                                passwordController.text.trim(),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                          ),
                          child: Text(
                            'Update',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateEmail(String newEmail, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Re-authenticate, then request the change (Supabase emails a confirmation link).
        await Supabase.instance.client.auth
            .signInWithPassword(email: user.email!, password: password);
        await Supabase.instance.client.auth
            .updateUser(UserAttributes(email: newEmail));
        await Supabase.instance.client
            .from('profiles')
            .update({'email': newEmail}).eq('id', user.id);

        // Update the user provider
        if (!mounted) return;
        final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
        await userProvider.fetchUserDetails();

        _showSuccessSnackBar('Verification email sent to $newEmail. Please verify to complete the change.');
      }
    } catch (e) {
      String errorMessage = 'Error updating email';
      if (e.toString().toLowerCase().contains('invalid login') || e.toString().contains('invalid_credentials')) {
        errorMessage = 'Incorrect password';
      } else if (e.toString().contains('requires-recent-login')) {
        errorMessage = 'Please log in again to change your email';
      } else if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'This email is already in use by another account';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address';
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _shareApp() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const String appLink = 'https://play.google.com/store/apps/details?id=com.zing.app'; // Replace with your actual app link
    const String shareMessage = 'Check out Zing - Your one-stop shop for all your needs! Download now: $appLink';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Share Zing App',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Share the app with your friends and family',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // WhatsApp
                _buildShareOption(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: ZingColors.success,
                  onTap: () {
                    Navigator.pop(context);
                    _shareToWhatsApp(shareMessage);
                  },
                ),

                // More options
                _buildShareOption(
                  icon: Icons.share,
                  label: 'More',
                  color: cs.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _shareGeneral(shareMessage);
                  },
                ),

                // Copy link
                _buildShareOption(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: cs.tertiary,
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(const ClipboardData(text: appLink));
                    _showSuccessSnackBar('App link copied to clipboard');
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp(String message) async {
    try {
      await Share.share(
        message,
        subject: 'Check out Zing App!',
      );
    } catch (e) {
      _showErrorSnackBar('Could not share to WhatsApp');
    }
  }

  Future<void> _shareGeneral(String message) async {
    try {
      await Share.share(
        message,
        subject: 'Check out Zing App!',
      );
    } catch (e) {
      _showErrorSnackBar('Could not share the app');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showErrorSnackBar('No user is logged in');
      return;
    }

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever,
                  color: cs.error,
                  size: 32,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Delete Account',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'This action cannot be undone. All your data will be permanently deleted, including:',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeleteListItem('Your profile and settings'),
                    _buildDeleteListItem('Order history and cart'),
                    _buildDeleteListItem('Saved favorites and preferences'),
                    _buildDeleteListItem('Chat messages and conversations'),
                    _buildDeleteListItem('Store data (if you\'re an owner)'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZingColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Are you absolutely sure you want to continue?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.error,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: cs.onSurfaceVariant,
                        side: BorderSide(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete My Account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onError,
                        ),
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

    if (confirm == true) {
      // Perform the deletion
      await _performAccountDeletion(user);
    }
  }

  Widget _buildDeleteListItem(String text) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: cs.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Attempt to delete - if re-authentication is needed, handle it
      await _deleteUserDataAndAccount(user);
    } catch (e) {
      if (e.toString().contains('requires-recent-login')) {
        // User needs to re-authenticate
        setState(() {
          _isLoading = false;
        });

        bool? reauthenticated = await _showReauthenticationDialog(user);

        if (reauthenticated == true) {
          // Try deletion again after re-authentication
          setState(() {
            _isLoading = true;
          });
          try {
            await _deleteUserDataAndAccount(user);
          } catch (e) {
            setState(() {
              _isLoading = false;
            });
            _showErrorSnackBar('Error deleting account: ${e.toString()}');
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error deleting account: ${e.toString()}');
      }
    }
  }

  Future<bool?> _showReauthenticationDialog(User user) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final TextEditingController passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool showPassword = false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ZingColors.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security,
                      color: ZingColors.warning,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Confirm Your Identity',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'For your security, please enter your password to continue with account deletion.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.primary,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.lock,
                          color: cs.onSurfaceVariant,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Please enter your password'
                          : null,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: cs.onSurfaceVariant,
                            side: BorderSide(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'Cancel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                // Re-authenticate the user
                                await Supabase.instance.client.auth.signInWithPassword(
                                  email: user.email!,
                                  password: passwordController.text.trim(),
                                );
                                if (context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Incorrect password. Please try again.',
                                      ),
                                      backgroundColor: cs.error,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirm',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteUserDataAndAccount(User user) async {
    // The Node API deletes the auth user; the database cascades to the profile,
    // cart, payments, orders, store, products, chats and favorites.
    await ApiClient.delete('/users/${user.id}');
    await Supabase.instance.client.auth.signOut();

    if (mounted) {
      _showSuccessSnackBar('Account deleted successfully');

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: cs.onPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: cs.onError,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: AnimationLimiter(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // Account section
                  _buildSectionTitle('Account', Icons.person_outline),

                  AnimationConfiguration.staggeredList(
                    position: 0,
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSettingCard(
                          title: 'Change Email',
                          subtitle: 'Update your account email address',
                          icon: Icons.email_outlined,
                          iconColor: cs.tertiary,
                          onTap: () => _changeEmail(context),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  AnimationConfiguration.staggeredList(
                    position: 1,
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSettingCard(
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          icon: Icons.lock_outline,
                          iconColor: cs.primary,
                          onTap: () => _changePassword(context),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Preferences section
                  _buildSectionTitle('Preferences', Icons.settings_outlined),

                  AnimationConfiguration.staggeredList(
                    position: 2,
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 100),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSwitchCard(
                          title: 'Notifications',
                          subtitle: 'Order updates on this device',
                          icon: Icons.notifications_outlined,
                          iconColor: cs.tertiary,
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            HapticFeedback.lightImpact();
                            PushService.setEnabled(value);
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  AnimationConfiguration.staggeredList(
                    position: 3,
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 200),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSwitchCard(
                          title: 'Dark Mode',
                          subtitle: 'Toggle between light and dark theme',
                          icon: themeProvider.isDarkMode
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          iconColor: themeProvider.isDarkMode
                              ? ZingColors.warning
                              : cs.tertiary,
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme(value);
                            HapticFeedback.lightImpact();
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // About section
                  _buildSectionTitle('About', Icons.info_outline),

                  AnimationConfiguration.staggeredList(
                    position: 4,
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSettingCard(
                          title: 'About Us',
                          subtitle: 'Learn more about Zing',
                          icon: Icons.business_outlined,
                          iconColor: cs.tertiary,
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  AnimationConfiguration.staggeredList(
                    position: 5,
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 400),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSettingCard(
                          title: 'Privacy Policy',
                          subtitle: 'Read our privacy policy',
                          icon: Icons.privacy_tip_outlined,
                          iconColor: ZingColors.success,
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Share section
                  _buildSectionTitle('Share', Icons.share_outlined),

                  AnimationConfiguration.staggeredList(
                    position: 6,
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSettingCard(
                          title: 'Share App',
                          subtitle: 'Share Zing with friends via WhatsApp & more',
                          icon: Icons.share,
                          iconColor: ZingColors.success,
                          onTap: () => _shareApp(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Account actions section
                  _buildSectionTitle('Account Actions', Icons.manage_accounts_outlined),

                  AnimationConfiguration.staggeredList(
                    position: 7,
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSettingCard(
                          title: 'Logout',
                          subtitle: 'Log out of your account',
                          icon: Icons.logout_outlined,
                          iconColor: ZingColors.warning,
                          onTap: () {
                            Supabase.instance.client.auth.signOut();
                            Navigator.of(context).pushReplacementNamed('/login');
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  AnimationConfiguration.staggeredList(
                    position: 8,
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 700),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      child: FadeInAnimation(
                        child: _buildSettingCard(
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account and all data',
                          icon: Icons.delete_outline,
                          iconColor: cs.error,
                          onTap: () => _deleteAccount(context),
                          isDestructive: true,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: cs.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait...',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Section title widget
  Widget _buildSectionTitle(String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
      child: Text(
        title.toUpperCase(),
        style: ZingType.footnote(cs.onSurfaceVariant).copyWith(letterSpacing: 0.2),
      ),
    );
  }

  // One iOS settings cell.
  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ZingRadius.md),
      child: ColoredBox(
        color: cs.surface,
        child: ZingListRow(
          icon: icon,
          iconColor: isDestructive ? ZingColors.error : iconColor,
          title: title,
          subtitle: subtitle,
          destructive: isDestructive,
          onTap: onTap,
        ),
      ),
    );
  }

  // Settings cell with an iOS switch.
  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ZingRadius.md),
      child: ColoredBox(
        color: cs.surface,
        child: ZingListRow(
          icon: icon,
          iconColor: iconColor,
          title: title,
          subtitle: subtitle,
          trailing: CupertinoSwitch(
            value: value,
            activeTrackColor: ZingColors.success,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
