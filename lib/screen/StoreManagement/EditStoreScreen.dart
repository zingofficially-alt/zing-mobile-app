import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Modal/types.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/StorageService.dart';
import '../../Service/SettingProvider.dart';

class AddEditStoreDialog extends StatefulWidget {
  final Store? store;
  final Function refreshStoreData;

  const AddEditStoreDialog({Key? key, this.store, required this.refreshStoreData}) : super(key: key);

  @override
  _AddEditStoreDialogState createState() => _AddEditStoreDialogState();
}

class _AddEditStoreDialogState extends State<AddEditStoreDialog> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController phoneNumberController;
  late TextEditingController deliveryCostController;
  LatLng? storeLocation;
  bool isEditMode = false;
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  String? selectedCategory;
  bool isLoading = false;

  // Form validation
  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;

  // Progress indicator
  int _currentStep = 0;

  final List<String> categories = [
    'Electronics', 'Clothing', 'Food', 'Sports', 'Beauty', 'Education',
    'Electrical', 'Kids', 'Mens', 'Womens', 'Phone'
  ];

  // Track selected delivery methods
  bool isStorePickupSelected = false;
  bool isHomeDeliverySelected = false;

  @override
  void initState() {
    super.initState();
    isEditMode = widget.store != null;

    nameController = TextEditingController(text: isEditMode ? widget.store!.name : '');
    descriptionController = TextEditingController(text: isEditMode ? widget.store!.description : '');
    phoneNumberController = TextEditingController(text: isEditMode ? widget.store!.phoneNumber : '');
    deliveryCostController = TextEditingController();

    if (isEditMode) {
      storeLocation = LatLng(widget.store!.location.latitude, widget.store!.location.longitude);
      selectedCategory = widget.store!.category;

      // Initialize delivery methods based on existing store
      isStorePickupSelected = widget.store!.deliveryOptions!.contains('Store Pickup');
      isHomeDeliverySelected = widget.store!.deliveryOptions!.contains('Home Delivery');
      if (widget.store!.deliveryCost != null) {
        deliveryCostController.text = widget.store!.deliveryCost!.toString();
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    phoneNumberController.dispose();
    deliveryCostController.dispose();
    super.dispose();
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
          _pickedImage = File(pickedFile.path);
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

  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
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
            Icon(Icons.error_outline, color: cs.onPrimary),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'store_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await StorageService.uploadFile(Buckets.store, fileName, imageFile);
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  void _showImagePickerOptions() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Image Source',
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromCamera();
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromGallery();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              boxShadow: ZingShadows.soft,
            ),
            child: Icon(
              icon,
              color: cs.primary,
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _selectLocation() async {
    LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationScreen(
          initialLocation: storeLocation,
        ),
      ),
    );

    if (selectedLocation != null) {
      setState(() {
        storeLocation = selectedLocation;
      });
    }
  }

  void _submitForm() async {
    final cs = Theme.of(context).colorScheme;

    if (_formKey.currentState!.validate()) {
      if (storeLocation == null || selectedCategory == null || (!isStorePickupSelected && !isHomeDeliverySelected)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: cs.onPrimary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please select a location, category, and at least one delivery method',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: cs.error,
            duration: Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(8),
          ),
        );
        return;
      }

      setState(() {
        isLoading = true;
      });

      try {
        String imageUrl;

        if (_pickedImage != null) {
          imageUrl = await _uploadImageToFirebase(_pickedImage!);
        } else if (isEditMode && widget.store!.imageUrl.isNotEmpty) {
          imageUrl = widget.store!.imageUrl;
        } else {
          imageUrl = '';
        }

        List<String> deliveryOptions = [];
        if (isStorePickupSelected) deliveryOptions.add('Store Pickup');
        if (isHomeDeliverySelected) deliveryOptions.add('Home Delivery');

        double? deliveryCost;
        if (isHomeDeliverySelected && deliveryCostController.text.isNotEmpty) {
          deliveryCost = double.tryParse(deliveryCostController.text);
        }

        final storeProvider = Provider.of<StoreProvider>(context, listen: false);
        final userProvider = Provider.of<CustomUserProvider>(context, listen: false);

        if (isEditMode) {
          Store updatedStore = Store(
            id: widget.store!.id,
            phoneNumber: phoneNumberController.text,
            name: nameController.text,
            description: descriptionController.text,
            category: selectedCategory!,
            imageUrl: imageUrl,
            location: GeoPoint(storeLocation!.latitude, storeLocation!.longitude),
            deliveryOptions: deliveryOptions,
            deliveryCost: deliveryCost,
            owner: widget.store!.owner,
            products: widget.store!.products,
          );

          await storeProvider.editStore(widget.store!.id!, updatedStore, userProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: cs.onPrimary),
                  SizedBox(width: 8),
                  Text('Store updated successfully!'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: ZingColors.success,
              duration: Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: EdgeInsets.all(8),
            ),
          );

          Navigator.pop(context);
          widget.refreshStoreData();
        } else {
          CustomUser? currentUser = userProvider.user;

          if (currentUser != null) {
            Store newStore = Store(
              id: '',
              phoneNumber: phoneNumberController.text,
              name: nameController.text,
              description: descriptionController.text,
              category: selectedCategory!,
              imageUrl: imageUrl,
              deliveryOptions: deliveryOptions,
              deliveryCost: deliveryCost,
              owner: Owner(
                id: currentUser.id,
                name: currentUser.name,
                email: currentUser.email,
                phone: currentUser.phoneNumber,
                profileImageUrl: currentUser.profileImageUrl,
              ),
              products: [],
              location: GeoPoint(storeLocation!.latitude, storeLocation!.longitude),
            );

            await storeProvider.addStore(newStore, userProvider);

            // Show bank details after store registration
            _showBankDetailsDialog();

            widget.refreshStoreData();
            Navigator.pop(context);
          }
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: cs.onPrimary),
                SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: cs.error,
            duration: Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(8),
          ),
        );
      }
    } else {
      setState(() {
        _autoValidate = true;
      });
    }
  }

  void _showBankDetailsDialog() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Icon(
                Icons.account_balance,
                size: 40,
                color: cs.primary,
              ),
              SizedBox(height: 8),
              Text(
                'Admin Bank Details',
                style: theme.textTheme.titleLarge!.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To complete your store registration, please pay the registration fee to the following bank account:',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: 16),
              _buildBankDetailRow(
                icon: Icons.account_balance,
                label: 'Bank',
                value: 'BOC BANK',
              ),
              _buildBankDetailRow(
                icon: Icons.account_balance_wallet,
                label: 'Account Number',
                value: '93597815',
              ),
              _buildBankDetailRow(
                icon: Icons.person,
                label: 'Account Name',
                value: 'M.Z.M SHAHIL',
              ),
              _buildBankDetailRow(
                icon: Icons.location_on,
                label: 'Branch',
                value: 'Kolonnawa branch',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: cs.onPrimary),
                        SizedBox(width: 8),
                        Text('Store added successfully!'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: ZingColors.success,
                    duration: Duration(seconds: 3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: EdgeInsets.all(8),
                  ),
                );
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBankDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 20),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cs.surface,
        ),
        child: isLoading
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
              SizedBox(height: 16),
              Text(
                isEditMode ? 'Updating Store...' : 'Creating Store...',
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : Stack(
          children: [
            Container(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidate
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditMode ? 'Edit Store' : 'Add New Store',
                            style: theme.textTheme.headlineSmall!.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Store Image
                      Center(
                        child: GestureDetector(
                          onTap: _showImagePickerOptions,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  boxShadow: ZingShadows.soft,
                                  image: _pickedImage != null
                                      ? DecorationImage(
                                    image: FileImage(_pickedImage!),
                                    fit: BoxFit.cover,
                                  )
                                      : isEditMode && widget.store!.imageUrl.isNotEmpty
                                      ? DecorationImage(
                                    image: NetworkImage(widget.store!.imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                ),
                                child: _pickedImage == null &&
                                    (!isEditMode || widget.store!.imageUrl.isEmpty)
                                    ? Icon(
                                  Icons.store,
                                  size: 50,
                                  color: cs.onSurfaceVariant,
                                )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: cs.onPrimary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Basic Info Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Basic Information',
                                style: theme.textTheme.titleLarge!.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              SizedBox(height: 16),

                              // Store Name Field
                              TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: 'Store Name',
                                  hintText: 'Enter the store name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.primary),
                                  ),
                                  prefixIcon: Icon(Icons.store, color: cs.primary),
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a store name';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),

                              // Phone Number Field
                              TextFormField(
                                controller: phoneNumberController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: 'Enter the store phone number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.primary),
                                  ),
                                  prefixIcon: Icon(Icons.phone, color: cs.primary),
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a phone number';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),

                              // Category Dropdown
                              DropdownButtonFormField<String>(
                                value: selectedCategory,
                                hint: Text('Select a category'),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.primary),
                                  ),
                                  prefixIcon: Icon(Icons.category, color: cs.primary),
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest,
                                ),
                                items: categories.map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedCategory = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a category';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),

                              // Description Field
                              TextFormField(
                                controller: descriptionController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Enter a brief description of the store',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.primary),
                                  ),
                                  prefixIcon: Icon(Icons.description, color: cs.primary),
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest,
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a description';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Delivery Options Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Options',
                                style: theme.textTheme.titleLarge!.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              SizedBox(height: 16),

                              // Delivery Method Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDeliveryOptionCard(
                                      icon: Icons.store,
                                      title: 'Store Pickup',
                                      isSelected: isStorePickupSelected,
                                      onTap: () {
                                        setState(() {
                                          isStorePickupSelected = !isStorePickupSelected;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDeliveryOptionCard(
                                      icon: Icons.delivery_dining,
                                      title: 'Home Delivery',
                                      isSelected: isHomeDeliverySelected,
                                      onTap: () {
                                        setState(() {
                                          isHomeDeliverySelected = !isHomeDeliverySelected;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Delivery Cost Field
                              if (isHomeDeliverySelected) ...[
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: deliveryCostController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Delivery Cost',
                                    hintText: 'Enter delivery cost',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cs.outline),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cs.outline),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cs.primary),
                                    ),
                                    prefixIcon: Icon(Icons.monetization_on, color: cs.primary),
                                    filled: true,
                                    fillColor: cs.surfaceContainerHighest,
                                  ),
                                  validator: (value) {
                                    if (isHomeDeliverySelected) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter delivery cost';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Please enter a valid number';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Location Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Store Location',
                                style: theme.textTheme.titleLarge!.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              SizedBox(height: 16),

                              // Location Status
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: storeLocation != null
                                      ? ZingColors.success.withOpacity(0.1)
                                      : cs.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: storeLocation != null
                                        ? ZingColors.success.withOpacity(0.5)
                                        : cs.error.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      storeLocation != null
                                          ? Icons.check_circle
                                          : Icons.location_off,
                                      color: storeLocation != null
                                          ? ZingColors.success
                                          : cs.error,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        storeLocation != null
                                            ? 'Location selected: ${storeLocation!.latitude.toStringAsFixed(4)}, ${storeLocation!.longitude.toStringAsFixed(4)}'
                                            : 'No location selected yet',
                                        style: theme.textTheme.bodyMedium!.copyWith(
                                          color: storeLocation != null
                                              ? ZingColors.success
                                              : cs.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Location Picker Button
                              ElevatedButton.icon(
                                onPressed: _selectLocation,
                                icon: Icon(
                                  Icons.location_pin,
                                  color: cs.onPrimary,
                                ),
                                label: Text(
                                  storeLocation == null
                                      ? 'Select Store Location'
                                      : 'Change Location',
                                  style: TextStyle(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Registration Fee (for new stores)
                      if (!isEditMode) ...[
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Registration Fee',
                                  style: theme.textTheme.titleLarge!.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: ZingColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ZingColors.warning.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: ZingColors.warning,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'One-time fee to register your store',
                                              style: theme.textTheme.bodyMedium!.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color: ZingColors.warning,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '${settingsProvider.registrationAmount?.toStringAsFixed(2)} ${settingsProvider.currency}',
                                              style: theme.textTheme.titleLarge!.copyWith(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: ZingColors.warning,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],

                      // Submit Button
                      ElevatedButton(
                        onPressed: _submitForm,
                        child: Text(
                          isEditMode ? 'Save Changes' : 'Create Store',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOptionCard({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.1) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                Icons.check,
                color: cs.onPrimary,
                size: 16,
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class SelectLocationScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const SelectLocationScreen({Key? key, this.initialLocation}) : super(key: key);

  @override
  _SelectLocationScreenState createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  late GoogleMapController _mapController;
  LatLng? pickedLocation;
  bool isMapReady = false;

  @override
  void initState() {
    super.initState();
    pickedLocation = widget.initialLocation;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      isMapReady = true;
    });

    if (pickedLocation != null) {
      _centerOnLocation(pickedLocation!);
    }
  }

  void _centerOnLocation(LatLng location) {
    if (isMapReady) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 15,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: Text(
          'Select Store Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (pickedLocation != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop(pickedLocation);
              },
              icon: Icon(Icons.check, color: cs.onPrimary),
              label: Text(
                'Confirm',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: pickedLocation ?? LatLng(6.9271, 79.8612), // Default to Colombo, Sri Lanka
              zoom: 13,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onTap: (LatLng latLng) {
              setState(() {
                pickedLocation = latLng;
              });
            },
            markers: pickedLocation != null
                ? {
              Marker(
                markerId: MarkerId('picked-location'),
                position: pickedLocation!,
                draggable: true,
                onDragEnd: (LatLng newPosition) {
                  setState(() {
                    pickedLocation = newPosition;
                  });
                },
              ),
            }
                : {},
          ),

          // Location Info Card
          if (pickedLocation != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Location',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: cs.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lat: ${pickedLocation!.latitude.toStringAsFixed(6)}, Long: ${pickedLocation!.longitude.toStringAsFixed(6)}',
                              style: theme.textTheme.bodyMedium!.copyWith(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You can drag the marker to adjust the location',
                        style: theme.textTheme.bodySmall!.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Button Bar
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // My Location Button
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ZingShadows.soft,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.my_location, color: cs.primary),
                    onPressed: () async {
                      // This would typically use geolocation, but for now just simulate it
                      setState(() {
                        pickedLocation = LatLng(6.9271, 79.8612);
                      });
                      _centerOnLocation(pickedLocation!);
                    },
                  ),
                ),
                SizedBox(width: 16),

                // Confirm Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickedLocation != null
                        ? () {
                      Navigator.of(context).pop(pickedLocation);
                    }
                        : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
