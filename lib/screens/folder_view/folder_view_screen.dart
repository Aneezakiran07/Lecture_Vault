import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../../services/storage_service.dart';
import '../image_viewer_screen.dart'; 

class FolderViewScreen extends StatefulWidget {
  final String folderName;
  final Color accentColor;
  final IconData folderIcon;
  final String basePath;

  const FolderViewScreen({
    super.key,
    this.folderName = 'Mathematics',
    this.accentColor = const Color(0xFF035955),
    this.folderIcon = Icons.calculate_rounded,
    this.basePath = '',
  });

  @override
  State<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends State<FolderViewScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimController;
  late Animation<double> _headerSlideAnim;

  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';
  bool _isGridView = true;
  bool _isLoading = true;

  final List<String> _filters = ['All', 'This Week', 'This Month'];
  final List<String> _sortOptions = ['Newest', 'Oldest', 'Name'];

  List<Map<String, dynamic>> _photos = [];
  final Set<int> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerSlideAnim = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _headerAnimController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPhotos();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);

    final args = ModalRoute.of(context)?.settings.arguments;
    String folderName = widget.folderName;
    String basePath = widget.basePath;

    if (args is Map) {
      folderName = args['folderName'] as String? ?? widget.folderName;
      basePath = args['basePath'] as String? ?? widget.basePath;
    }

    if (basePath.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final files = await StorageService.getPhotosInSubject(
      basePath: basePath,
      subject: folderName,
    );

    final photoData = files.map((file) {
      final stat = file.statSync();
      return {
        'id': file.path.hashCode,
        'path': file.path,
        'date': _formatDate(stat.modified),
        'label': file.path.split('/').last,
        'size': _formatSize(stat.size),
        'modified': stat.modified,
      };
    }).toList();

    _applySortToList(photoData);

    setState(() {
      _photos = photoData;
      _isLoading = false;
    });
  }

  void _applySortToList(List<Map<String, dynamic>> list) {
    if (_selectedSort == 'Newest') {
      list.sort((a, b) =>
          (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
    } else if (_selectedSort == 'Oldest') {
      list.sort((a, b) =>
          (a['modified'] as DateTime).compareTo(b['modified'] as DateTime));
    } else if (_selectedSort == 'Name') {
      list.sort((a, b) =>
          (a['label'] as String).compareTo(b['label'] as String));
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    if (diff.inDays == 0) return 'Today, $hour12:$minute $period';
    if (diff.inDays == 1) return 'Yesterday, $hour12:$minute $period';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get _totalSizeBytes {
    return _photos.fold(0, (sum, p) {
      try {
        return sum + File(p['path'] as String).lengthSync();
      } catch (_) {
        return sum;
      }
    });
  }

  void _toggleSelect(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // opens full-screen viewer at the tapped photo, all photos in folder are swipeable
  void _openViewer(int index) {
    HapticFeedback.lightImpact();
    final paths = _photos.map((p) => p['path'] as String).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          imagePaths: paths,
          initialIndex: index,
          title: _photos[index]['label'] as String,
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    HapticFeedback.mediumImpact();
    final toDelete =
        _photos.where((p) => _selectedIds.contains(p['id'])).toList();
    for (final photo in toDelete) {
      await StorageService.deletePhoto(photo['path'] as String);
    }
    setState(() => _selectedIds.clear());
    await _loadPhotos();
  }

  Future<void> _deleteSinglePhoto(String path) async {
    Navigator.pop(context); // close bottom sheet
    HapticFeedback.mediumImpact();
    await StorageService.deletePhoto(path);
    await _loadPhotos();
  }

  void _showPhotoOptions(BuildContext context, Map<String, dynamic> photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildBottomSheet(photo),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sort by',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _sortOptions.map((s) {
            return RadioListTile<String>(
              value: s,
              groupValue: _selectedSort,
              activeColor: const Color(0xFF89B0AE),
              title: Text(s),
              onChanged: (val) {
                setState(() {
                  _selectedSort = val!;
                  _applySortToList(_photos);
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }void _showFolderMenu() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _sheetTile(Icons.refresh_rounded, 'Refresh',
              const Color(0xFF035955), () {
            Navigator.pop(context);
            _loadPhotos();
          }),
          _sheetTile(Icons.delete_outline_rounded, 'Delete Folder',
              const Color(0xFFE07A5F), () {
            Navigator.pop(context); // close bottom sheet first
            _showDeleteFolderDialog();
          }),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

void _showDeleteFolderDialog() {
  final args = ModalRoute.of(context)?.settings.arguments;
  String folderName = widget.folderName;
  String basePath = widget.basePath;

  if (args is Map) {
    folderName = args['folderName'] as String? ?? widget.folderName;
    basePath = args['basePath'] as String? ?? widget.basePath;
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE07A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE07A5F), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Delete Folder',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          children: [
            const TextSpan(text: 'This will permanently delete '),
            TextSpan(
              text: '"$folderName"',
              style: const TextStyle(
                  color: Color(0xFFE07A5F), fontWeight: FontWeight.bold),
            ),
            const TextSpan(
                text: ' and ALL photos inside it from your device.\n\n'),
            const TextSpan(
              text: '⚠️ This cannot be undone.',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context); // close dialog
            await _deleteFolder(folderName, basePath);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE07A5F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Delete Everything'),
        ),
      ],
    ),
  );
}

Future<void> _deleteFolder(String folderName, String basePath) async {
  try {
    final folderPath = '$basePath/$folderName';
    final dir = Directory(folderPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    // also remove from subjects list in prefs
    final subjects = await StorageService.getSubjects();
    final updated = subjects.where((s) => s != folderName).toList();
    await StorageService.saveSubjects(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ "$folderName" deleted'),
          backgroundColor: const Color(0xFF035955),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // go back to home since folder no longer exists
      Navigator.pushNamedAndRemoveUntil(
          context, '/home', (route) => false);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete folder'),
          backgroundColor: const Color(0xFFE07A5F),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String displayName = widget.folderName;
    IconData displayIcon = widget.folderIcon;
    if (args is Map) {
      displayName = args['folderName'] as String? ?? widget.folderName;
      displayIcon = args['icon'] as IconData? ?? widget.folderIcon;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(_headerSlideAnim),
            child: _buildHeader(displayName, displayIcon),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.headerCard))
                : Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildFilterRow(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _photos.isEmpty
                            ? _buildEmptyState()
                            : _isGridView
                                ? _buildPhotoGrid()
                                : _buildPhotoList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelecting ? _buildSelectionBar() : null,
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/upload')
                  .then((_) => _loadPhotos()),
              backgroundColor: AppColors.headerCard,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_photo_alternate_rounded),
            ),
    );
  }

  Widget _buildHeader(String displayName, IconData displayIcon) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.headerCard,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x55035955),
              blurRadius: 18,
              offset: Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.maybePop(context);
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
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isGridView = !_isGridView);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showFolderMenu,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.more_vert_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(displayIcon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${_photos.length} photo${_photos.length != 1 ? 's' : ''} • ${_formatSize(_totalSizeBytes)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _headerStatChip(
                      Icons.photo_rounded, '${_photos.length} Photos'),
                  const SizedBox(width: 8),
                  _headerStatChip(
                      Icons.storage_rounded, _formatSize(_totalSizeBytes)),
                  const SizedBox(width: 8),
                  _headerStatChip(Icons.folder_rounded, displayName),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF89B0AE)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF89B0AE)
                              : Colors.grey.shade300,
                        ),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(
                                    color: Color(0x3389B0AE),
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ]
                            : [],
                      ),
                      child: Text(f,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showSortDialog,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.sort_rounded,
                  color: Colors.grey.shade600, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) => _buildPhotoCard(_photos[index], index),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo, int index) {
    final isSelected = _selectedIds.contains(photo['id']);
    return GestureDetector(
      onTap: () {
        if (_isSelecting) {
          _toggleSelect(photo['id'] as int);
        } else {
          // FIX: tap opens full-screen viewer
          _openViewer(index);
        }
      },
      onLongPress: () => _toggleSelect(photo['id'] as int),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF89B0AE)
                : const Color(0xFFEEEEEE),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0x3389B0AE)
                  : const Color(0x0A000000),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    child: Image.file(
                      File(photo['path'] as String),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(photo['label'] as String,
                          style: const TextStyle(
                              color: AppColors.bodyText,
                              fontWeight: FontWeight.w600,
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(photo['date'] as String,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Color(0xFF89B0AE), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            if (!_isSelecting)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _showPhotoOptions(context, photo),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.more_horiz_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        final isSelected = _selectedIds.contains(photo['id']);
        return GestureDetector(
          onTap: () {
            if (_isSelecting) {
              _toggleSelect(photo['id'] as int);
            } else {
              // FIX: tap opens full-screen viewer in list view too
              _openViewer(index);
            }
          },
          onLongPress: () => _toggleSelect(photo['id'] as int),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF89B0AE)
                    : const Color(0xFFEEEEEE),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.file(
                      File(photo['path'] as String),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_rounded,
                            color: Colors.grey, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(photo['label'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.bodyText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(photo['date'] as String,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11)),
                    ],
                  ),
                ),
                Text(photo['size'] as String,
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 11)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showPhotoOptions(context, photo),
                  child: Icon(Icons.more_vert_rounded,
                      color: Colors.grey.shade400, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF89B0AE).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF89B0AE), size: 52),
            ),
            const SizedBox(height: 20),
            const Text('No photos yet',
                style: TextStyle(
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Upload whiteboard photos and they\'ll be sorted here automatically',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/upload')
                  .then((_) => _loadPhotos()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B0AE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload Now',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedIds.clear());
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.grey, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${_selectedIds.length} selected',
                style: const TextStyle(
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          GestureDetector(
            onTap: _deleteSelected,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE07A5F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE07A5F).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFE07A5F), size: 16),
                  SizedBox(width: 6),
                  Text('Delete',
                      style: TextStyle(
                          color: Color(0xFFE07A5F),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(Map<String, dynamic> photo) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.file(
                      File(photo['path'] as String),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_rounded,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(photo['label'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(photo['date'] as String,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // FIX: "Open" option added to bottom sheet
          _sheetTile(Icons.open_in_full_rounded, 'Open',
              const Color(0xFF035955), () {
            Navigator.pop(context); // close sheet first
            final index =
                _photos.indexWhere((p) => p['path'] == photo['path']);
            if (index != -1) _openViewer(index);
          }),
          _sheetTile(Icons.share_rounded, 'Share',
              const Color(0xFF4A90D9), () => Navigator.pop(context)),
          _sheetTile(Icons.delete_outline_rounded, 'Delete',
              const Color(0xFFE07A5F),
              () => _deleteSinglePhoto(photo['path'] as String)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sheetTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}