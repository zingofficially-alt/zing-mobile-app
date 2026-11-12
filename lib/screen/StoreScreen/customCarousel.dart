import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import '../../Modal/CoustomUser.dart';
import '../../Service/StoreProvider.dart';

class EnhancedCarousel extends StatefulWidget {
  final Store store;
  final Function(int)? onPageChanged;
  final double height;
  final bool autoPlay;
  final bool showControls;
  final bool enableInfiniteScroll;
  final BoxFit imageFit;
  final Duration autoPlayInterval;
  final Curve animationCurve;
  final bool showIndicator;
  final Color indicatorActiveColor;
  final Color indicatorInactiveColor;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final bool showGradientOverlay;
  final bool fullScreenOnTap;

  const EnhancedCarousel({
    Key? key,
    required this.store,
    this.onPageChanged,
    this.height = 280.0,
    this.autoPlay = false,
    this.showControls = true,
    this.enableInfiniteScroll = true,
    this.imageFit = BoxFit.cover,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.animationCurve = Curves.fastOutSlowIn,
    this.showIndicator = true,
    this.indicatorActiveColor = Colors.blueAccent,
    this.indicatorInactiveColor = Colors.grey,
    this.loadingWidget,
    this.emptyWidget,
    this.showGradientOverlay = true,
    this.fullScreenOnTap = true,
  }) : super(key: key);

  @override
  _EnhancedCarouselState createState() => _EnhancedCarouselState();
}

class _EnhancedCarouselState extends State<EnhancedCarousel>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  CarouselSliderController buttonCarouselController =
      CarouselSliderController();
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;

  Store? _store;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Media items list
  List<MediaItem> _mediaItems = [];

  // YouTube controllers for each video
  Map<String, YoutubePlayerController> _youtubeControllers = {};

  // Track which video is currently playing
  String? _activeVideoId;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _fetchStoreData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController!.forward();
  }

  Future<void> _fetchStoreData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      Store? fetchedStore = await storeProvider.fetchStore(widget.store.id!);

      if (fetchedStore != null) {
        setState(() {
          _store = fetchedStore;
          _prepareMediaItems();
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = "Failed to load store data";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = "Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  void _prepareMediaItems() {
    _mediaItems.clear();

    // Add store main image
    if (_store!.imageUrl.isNotEmpty) {
      _mediaItems.add(MediaItem(
        type: MediaType.image,
        url: _store!.imageUrl,
        id: 'main_image',
      ));
    }

    // Add YouTube videos
    if (_store!.videos != null && _store!.videos!.isNotEmpty) {
      for (int i = 0; i < _store!.videos!.length; i++) {
        final video = _store!.videos![i];
        final videoId = YoutubePlayer.convertUrlToId(video.url);

        if (videoId != null) {
          _mediaItems.add(MediaItem(
            type: MediaType.video,
            url: video.url,
            videoId: videoId,
            id: 'video_$i',
          ));

          // Create YouTube controller
          _youtubeControllers[videoId] = YoutubePlayerController(
            initialVideoId: videoId,
            flags: YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              loop: false,
              disableDragSeek: false,
              enableCaption: true,
              controlsVisibleAtStart: true,
              hideControls: false,
            ),
          );
        }
      }
    }
  }

  void _pauseAllVideos() {
    _youtubeControllers.forEach((videoId, controller) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    });
    _activeVideoId = null;
  }

  void _handlePageChange(int index, CarouselPageChangedReason reason) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });

    // Pause all videos when page changes
    _pauseAllVideos();

    // Notify parent
    if (widget.onPageChanged != null) {
      widget.onPageChanged!(index);
    }
  }

  void _toggleVideo(String videoId) {
    final controller = _youtubeControllers[videoId];
    if (controller == null) return;

    if (_activeVideoId == videoId) {
      // Same video - toggle play/pause
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    } else {
      // New video - pause all others and play this one
      _pauseAllVideos();
      controller.play();
      setState(() {
        _activeVideoId = videoId;
      });
    }
  }

  @override
  void dispose() {
    // Dispose YouTube controllers
    for (var controller in _youtubeControllers.values) {
      controller.dispose();
    }

    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_mediaItems.isEmpty) {
      return _buildEmptyState();
    }

    // Removed AnimatedBuilder + Transform.scale to fix semantics assertion error
    return RepaintBoundary(
      child: _buildCarouselContent(),
    );
  }

  Widget _buildCarouselContent() {
    return Container(
      decoration: widget.showGradientOverlay
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent.withOpacity(0.8), Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Column(
        children: [
          // Carousel - removed FadeInUp to fix semantics issues
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CarouselSlider.builder(
              carouselController: buttonCarouselController,
              itemCount: _mediaItems.length,
              itemBuilder: (context, index, realIndex) {
                return RepaintBoundary(
                  child: _buildCarouselItem(_mediaItems[index]),
                );
              },
              options: CarouselOptions(
                height: widget.height,
                viewportFraction: 0.92,
                enlargeCenterPage: true,
                enableInfiniteScroll:
                    widget.enableInfiniteScroll && _mediaItems.length > 1,
                autoPlay: widget.autoPlay && _activeVideoId == null,
                autoPlayInterval: widget.autoPlayInterval,
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                autoPlayCurve: widget.animationCurve,
                onPageChanged: _handlePageChange,
                scrollDirection: Axis.horizontal,
              ),
            ),
          ),

          // Page indicator - removed FadeIn to fix semantics issues
          if (widget.showIndicator && _mediaItems.length > 1)
            _buildPageIndicator(_mediaItems.length),

          // Navigation controls - removed FadeInUp to fix semantics issues
          if (widget.showControls && _mediaItems.length > 1)
            _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(MediaItem item) {
    if (item.type == MediaType.image) {
      return _buildImageItem(item);
    } else {
      return _buildVideoItem(item);
    }
  }

  Widget _buildImageItem(MediaItem item) {
    return GestureDetector(
      onTap:
          widget.fullScreenOnTap ? () => _showFullScreenImage(item.url) : null,
      child: Hero(
        tag: 'store-image-${widget.store.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: item.url,
                  fit: widget.imageFit,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      color: Colors.grey[200],
                      width: double.infinity,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ),
                // Media type indicator
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Photo',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoItem(MediaItem item) {
    final controller = _youtubeControllers[item.videoId!];
    final isPlaying = _activeVideoId == item.videoId;

    // Removed ZoomIn animation to fix semantics issues
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Video player or thumbnail - wrapped in RepaintBoundary
            if (isPlaying && controller != null)
              RepaintBoundary(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                  child: YoutubePlayer(
                    controller: controller,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Colors.red,
                    progressColors: const ProgressBarColors(
                      playedColor: Colors.red,
                      handleColor: Colors.redAccent,
                      bufferedColor: Colors.grey,
                      backgroundColor: Colors.white24,
                    ),
                    onReady: () {
                      print('Video ready: ${item.videoId}');
                    },
                    onEnded: (metaData) {
                      if (mounted) {
                        setState(() {
                          _activeVideoId = null;
                        });
                      }
                    },
                  ),
                ),
              )
            else
              // Show thumbnail when not playing
              Stack(
                children: [
                  _buildVideoThumbnail(item.url),
                  // Play button overlay
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: GestureDetector(
                          onTap: () => _toggleVideo(item.videoId!),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.red,
                              size: 45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            // Media type indicator
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPlaying ? 'Playing' : 'Video',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fullscreen button for videos
            if (widget.fullScreenOnTap)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => _showFullScreenVideo(item),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.fullscreen,
                      color: Colors.white,
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

  Widget _buildVideoThumbnail(String videoUrl) {
    String? videoId = YoutubePlayer.convertUrlToId(videoUrl);
    String thumbnailUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
        : '';

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          color: Colors.grey[200],
          width: double.infinity,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[800],
        child: const Icon(
          Icons.video_library_rounded,
          color: Colors.white,
          size: 50,
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int itemCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: SizedBox(
        height: 16,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final bool isActive = _currentIndex == index;
            final MediaItem item = _mediaItems[index];

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              width: isActive ? 20.0 : 8.0,
              height: 8.0,
              decoration: BoxDecoration(
                color: isActive
                    ? widget.indicatorActiveColor
                    : widget.indicatorInactiveColor,
                borderRadius: BorderRadius.circular(4.0),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: widget.indicatorActiveColor.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: isActive
                  ? Center(
                      child: Icon(
                        item.type == MediaType.video
                            ? Icons.play_arrow
                            : Icons.image,
                        color: Colors.white,
                        size: 6,
                      ),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavButton(
            icon: Icons.arrow_back_ios_rounded,
            onPressed: () {
              buttonCarouselController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              HapticFeedback.mediumImpact();
            },
          ),
          const SizedBox(width: 40),
          _buildNavButton(
            icon: Icons.arrow_forward_ios_rounded,
            onPressed: () {
              buttonCarouselController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              HapticFeedback.mediumImpact();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Ink(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.9),
        pageBuilder: (context, _, __) {
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(80),
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Hero(
                      tag: 'store-image-${widget.store.id}',
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Pinch to zoom • Tap to close',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _showFullScreenVideo(MediaItem item) {
    if (item.videoId == null) return;

    // Pause current video
    _pauseAllVideos();

    // Create new controller for fullscreen
    final fullscreenController = YoutubePlayerController(
      initialVideoId: item.videoId!,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: false,
        controlsVisibleAtStart: true,
      ),
    );

    HapticFeedback.mediumImpact();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: YoutubePlayer(
                    controller: fullscreenController,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Colors.red,
                    progressColors: const ProgressBarColors(
                      playedColor: Colors.red,
                      handleColor: Colors.redAccent,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .then((_) {
      fullscreenController.dispose();
    });
  }

  // States
  Widget _buildLoadingState() {
    if (widget.loadingWidget != null) {
      return widget.loadingWidget!;
    }

    return Container(
      height: widget.height + 80,
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load media',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchStoreData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Retry',
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onError,
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (widget.emptyWidget != null) {
      return widget.emptyWidget!;
    }

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: Colors.grey[500],
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            'No media available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper classes
enum MediaType { image, video }

class MediaItem {
  final MediaType type;
  final String url;
  final String? videoId;
  final String id;

  MediaItem({
    required this.type,
    required this.url,
    this.videoId,
    required this.id,
  });
}
