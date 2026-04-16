import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final String? title;

  const ImageViewerScreen({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.title,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  bool _isZoomed = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // one controller per page so zoom state is independent per photo
  late List<TransformationController> _transformControllers;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // create a TransformationController for each image
    _transformControllers = List.generate(
      widget.imagePaths.length,
      (_) => TransformationController(),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
Widget _buildImage(String path) {
  const errorWidget = Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
        SizedBox(height: 12),
        Text('Image not found', style: TextStyle(color: Colors.white38)),
      ],
    ),
  );

  if (path.startsWith('content://')) {
    return FutureBuilder<Uint8List>(
      future: XFile(path).readAsBytes(),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!, fit: BoxFit.contain,
              filterQuality: FilterQuality.high);
        }
        if (snap.hasError) return errorWidget;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        );
      },
    );
  }
  return Image.file(File(path), fit: BoxFit.contain,
      filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => errorWidget);
}
  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    for (final c in _transformControllers) {
      c.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    // only toggle controls when not zoomed
    if (!_isZoomed) {
      setState(() => _showControls = !_showControls);
    }
  }

  void _resetZoom(int index) {
    _transformControllers[index].value = Matrix4.identity();
    setState(() => _isZoomed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // SWIPEABLE PHOTO PAGES 
          PageView.builder(
            controller: _pageController,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.imagePaths.length,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              // reset zoom on previous page when swiping
              _resetZoom(_currentIndex);
              setState(() => _currentIndex = i);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleControls,
                onDoubleTapDown: (details) {
                  final controller = _transformControllers[index];
                  if (controller.value != Matrix4.identity()) {
                    // zoom out
                    controller.value = Matrix4.identity();
                    setState(() => _isZoomed = false);
                  } else {
                    // zoom in to tapped position
                    final position = details.localPosition;
                    controller.value = Matrix4.identity()
                      ..translate(-position.dx * 2, -position.dy * 2)
                      ..scale(3.0);
                    setState(() => _isZoomed = true);
                  }
                },
                child: Center(
                  child: InteractiveViewer(
                    transformationController:
                        _transformControllers[index],
                    minScale: 0.8,
                    maxScale: 5.0,
                    scaleEnabled: true,
                    panEnabled: true,
                    // allow panning beyond bounds for smooth feel
                    boundaryMargin:
                        const EdgeInsets.all(double.infinity),
                    onInteractionStart: (_) {
                      // show controls when interaction starts
                      if (!_showControls) {
                        setState(() => _showControls = true);
                      }
                    },
                    onInteractionUpdate: (details) {
                      final scale = _transformControllers[index]
                          .value
                          .getMaxScaleOnAxis();
                      final zoomed = scale > 1.05;
                      if (zoomed != _isZoomed) {
                        setState(() => _isZoomed = zoomed);
                      }
                    },
                    onInteractionEnd: (_) {
                      // if fully zoomed out snap back cleanly
                      final scale = _transformControllers[index]
                          .value
                          .getMaxScaleOnAxis();
                      if (scale < 1.0) {
                        _transformControllers[index].value =
                            Matrix4.identity();
                        setState(() => _isZoomed = false);
                      }
                    },
                    child: _buildImage(widget.imagePaths[index]),)
                  
                ),
              );
            },
          ),

          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      // back button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // title
                      Expanded(
                        child: Text(
                          widget.title ??
                              'Photo ${_currentIndex + 1} of ${widget.imagePaths.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // counter pill
                      if (widget.imagePaths.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.imagePaths.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // share button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Share.shareXFiles(
                            [XFile(widget.imagePaths[_currentIndex])],
                            text: 'Shared from LectureVault',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.share_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          //  BOTTOM DOTS INDICATOR
          if (widget.imagePaths.length > 1)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.imagePaths.length.clamp(0, 20),
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentIndex == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentIndex == i
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}