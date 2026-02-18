import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Modal/CoustomUser.dart';
import '../../Service/ThemeProvider.dart';

class EnhancedGoogleMapWidget extends StatefulWidget {
  final Store userStore;
  final double? height;
  final bool showControls;
  final bool showStoreInfo;

  const EnhancedGoogleMapWidget({
    Key? key,
    required this.userStore,
    this.height,
    this.showControls = true,
    this.showStoreInfo = true,
  }) : super(key: key);

  @override
  State<EnhancedGoogleMapWidget> createState() => _EnhancedGoogleMapWidgetState();
}

class _EnhancedGoogleMapWidgetState extends State<EnhancedGoogleMapWidget>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  bool _isFullscreen = false;
  String _mapStyle = '';

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
    } catch (e) {
      // If custom style fails, use default
      _mapStyle = '''
      [
        {
          "featureType": "all",
          "elementType": "geometry.fill",
          "stylers": [{"color": "#f8f9fa"}]
        },
        {
          "featureType": "water",
          "elementType": "geometry.fill",
          "stylers": [{"color": "#a8dadc"}]
        },
        {
          "featureType": "poi",
          "elementType": "geometry.fill",
          "stylers": [{"color": "#e9ecef"}]
        }
      ]
      ''';
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_mapStyle.isNotEmpty) {
      _mapController!.setMapStyle(_mapStyle);
    }
    setState(() {
      _isMapReady = true;
    });
  }

  Future<void> _openDirections() async {
    final lat = widget.userStore.location.latitude;
    final lng = widget.userStore.location.longitude;
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open directions'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  Future<void> _centerOnStore() async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              widget.userStore.location.latitude,
              widget.userStore.location.longitude,
            ),
            zoom: 16,
          ),
        ),
      );
    }
  }

  Set<Marker> _createMarkers() {
    return {
      Marker(
        markerId: const MarkerId('store-location'),
        position: LatLng(
          widget.userStore.location.latitude,
          widget.userStore.location.longitude,
        ),
        infoWindow: InfoWindow(
          title: widget.userStore.name,
          snippet: '${widget.userStore.category} • Tap for directions',
          onTap: _openDirections,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
  }

  Widget _buildLoadingOverlay() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.surfaceContainerHighest,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading map...',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfoOverlay() {
    if (!widget.showStoreInfo) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Positioned(
      top: 16,
      left: 16,
      right: widget.showControls ? 72 : 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.surface,
                  cs.surface.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: cs.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: cs.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userStore.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userStore.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    if (!widget.showControls) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Positioned(
      top: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Fullscreen Toggle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _toggleFullscreen,
                  child: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Center on Store
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _centerOnStore,
                  child: Icon(
                    Icons.my_location_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionsButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Positioned(
      bottom: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ZingColors.success,
                Color(0xFF059669),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: ZingColors.success.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openDirections,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Directions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final mapHeight = _isFullscreen
        ? screenSize.height
        : (widget.height ?? 280.0);

    // Removed FadeTransition to fix semantics assertion error with platform views
    return RepaintBoundary(
      child: Container(
        height: mapHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Map - wrapped in RepaintBoundary for better performance
              RepaintBoundary(
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.userStore.location.latitude,
                      widget.userStore.location.longitude,
                    ),
                    zoom: 15,
                  ),
                  markers: _createMarkers(),
                  mapType: MapType.normal,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  buildingsEnabled: true,
                  trafficEnabled: false,
                  onTap: (LatLng position) {
                    // Handle map tap if needed
                  },
                ),
              ),

              // Loading Overlay
              if (!_isMapReady) _buildLoadingOverlay(),

              // Store Info Overlay
              _buildStoreInfoOverlay(),

              // Map Controls
              _buildMapControls(),

              // Directions Button
              _buildDirectionsButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// Usage function for backward compatibility
Widget buildGoogleMap(Store userStore) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: EnhancedGoogleMapWidget(userStore: userStore),
  );
}
