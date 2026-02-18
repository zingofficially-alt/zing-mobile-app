import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasChanges = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
    final user = userProvider.user;

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');

    // Track changes to enable/disable save button
    _nameController.addListener(_onFormChanged);
    _emailController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: cs.primary),
                title: Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: cs.primary),
                title: Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _captureImageFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _hasChanges = true;
        });
      }
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') {
        _showErrorSnackBar('Photo library access was denied. Please enable photo permissions in Settings.');
      } else {
        _showErrorSnackBar('Failed to access gallery: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select image. Please try again.');
    }
  }

  Future<void> _captureImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _hasChanges = true;
        });
      }
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        _showErrorSnackBar('Camera access was denied. Please enable camera permissions in Settings.');
      } else if (e.code == 'photo_access_denied') {
        _showErrorSnackBar('Photo library access was denied. Please enable photo permissions in Settings.');
      } else {
        _showErrorSnackBar('Failed to access camera: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture image. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onError),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _uploadImage(File image) async {
    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
    final userId = userProvider.user!.id;

    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child("user_images/$userId/profile.jpg");
      UploadTask uploadTask = ref.putFile(image);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  Future<void> _saveProfileChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? imageUrl;

        if (_selectedImage != null) {
          imageUrl = await _uploadImage(_selectedImage!);
        }

        final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
        CustomUser updatedUser = CustomUser(
          id: userProvider.user!.id,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: userProvider.user!.address,
          profileImageUrl: imageUrl ?? userProvider.user!.profileImageUrl,
          role: userProvider.user!.role,
          store: userProvider.user!.store,
          favorites: userProvider.user!.favorites,
        );

        await userProvider.saveUserDetails(updatedUser);

        if (updatedUser.role == 'Owner') {
          await _updateStoreOwnerDetails(updatedUser);
        }

        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ZingColors.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        print('Error saving profile: $e');
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: cs.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStoreOwnerDetails(CustomUser updatedUser) async {
    try {
      if (updatedUser.store != null && updatedUser.store!.id != null) {
        DocumentReference storeDocRef = FirebaseFirestore.instance
            .collection('stores')
            .doc(updatedUser.store!.id);

        DocumentSnapshot storeSnapshot = await storeDocRef.get();

        if (storeSnapshot.exists) {
          await storeDocRef.update({
            'owner.name': updatedUser.name,
            'owner.email': updatedUser.email,
            'owner.phone': updatedUser.phoneNumber,
            'owner.profileImageUrl': updatedUser.profileImageUrl,
          });
        }
      }
    } catch (e) {
      print('Error updating store owner details: $e');
      throw e;
    }
  }

  String? _validateEmail(String? value) {
    final RegExp emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (value == null || value.isEmpty) {
      return 'Email cannot be empty';
    } else if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number cannot be empty';
    } else if (value.length < 10) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  void _showDiscardChangesDialog() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Discard Changes?'),
          content: Text('You have unsaved changes. Are you sure you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('Discard', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<CustomUserProvider>(context);
    final user = userProvider.user;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          _showDiscardChangesDialog();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Profile'),
          centerTitle: true,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: () {
              if (_hasChanges) {
                _showDiscardChangesDialog();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _saveProfileChanges,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(
          child: SpinKitFadingCircle(
            color: cs.primary,
            size: 60.0,
          ),
        )
            : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primary.withOpacity(0.1),
                cs.surface,
              ],
            ),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                SizedBox(height: 30),
                _buildProfileImage(user),
                SizedBox(height: 30),
                _buildSectionTitle('Personal Information'),
                SizedBox(height: 15),
                _buildFormFields(),
                SizedBox(height: 40),
                _buildSaveButton(),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildProfileImage(CustomUser? user) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: ZingShadows.medium,
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: cs.surfaceContainerHighest,
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : (user?.profileImageUrl.isNotEmpty ?? false)
                  ? NetworkImage(user!.profileImageUrl) as ImageProvider
                  : null,
              child: _selectedImage == null &&
                  (user?.profileImageUrl == null || user!.profileImageUrl.isEmpty)
                  ? Icon(Icons.person, size: 60, color: cs.onPrimary)
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: cs.onPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person_outline,
          validator: (value) => value == null || value.isEmpty ? 'Name cannot be empty' : null,
        ),
        SizedBox(height: 20),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          validator: _validateEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 20),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          validator: _validatePhone,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ZingShadows.soft,
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: cs.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.error),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          filled: true,
          fillColor: cs.surface,
          errorStyle: TextStyle(
            color: cs.error,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        validator: validator,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildSaveButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ElevatedButton(
      onPressed: (_isLoading || !_hasChanges) ? null : _saveProfileChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        shadowColor: cs.primary.withOpacity(0.5),
        disabledBackgroundColor: cs.surfaceContainerHighest,
      ),
      child: _isLoading
          ? SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
          strokeWidth: 2,
        ),
      )
          : Text(
        'Save Changes',
        style: theme.textTheme.titleLarge?.copyWith(
          color: cs.onPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
