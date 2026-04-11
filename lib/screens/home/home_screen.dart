import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  final int _selectedNavIndex = 0;

  List<String> _subjects = [];
  String? _basePath;
  Map<String, int> _photoCounts = {};
  int _totalPhotos = 0;
  bool _isLoading = true;

  final TextEditingController _newSubjectController = TextEditingController();

  // fade-in animation for the grid
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  final List<IconData> _subjectIcons = [
    Icons.calculate_rounded,
    Icons.science_rounded,
    Icons.biotech_rounded,
    Icons.history_edu_rounded,
    Icons.eco_rounded,
    Icons.menu_book_rounded,
    Icons.public_rounded,
    Icons.computer_rounded,
    Icons.music_note_rounded,
    Icons.palette_rounded,
    Icons.sports_soccer_rounded,
    Icons.psychology_rounded,
  ];

  final List<Color> _cardColors = [
    const Color(0xFFE8F5F4),
    const Color(0xFFEAF0F6),
    const Color(0xFFF0EAF6),
    const Color(0xFFF6F0EA),
    const Color(0xFFEAF6F0),
    const Color(0xFFF6EAF0),
  ];

  final List<Color> _iconColors = [
    const Color(0xFF035955),
    const Color(0xFF4A90D9),
    const Color(0xFF9B59B6),
    const Color(0xFFE07A5F),
    const Color(0xFF27AE60),
    const Color(0xFFE91E8C),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _newSubjectController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final subjects = await StorageService.getSubjects();
    final basePath = await StorageService.getBasePath();

    if (basePath == null || subjects.isEmpty) {
      setState(() {
        _subjects = subjects;
        _basePath = basePath;
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
      return;
    }

    final counts =
        await StorageService.getSubjectPhotoCounts(basePath, subjects);
    final total = counts.values.fold(0, (a, b) => a + b);

    setState(() {
      _subjects = subjects;
      _basePath = basePath;
      _photoCounts = counts;
      _totalPhotos = total;
      _isLoading = false;
    });
    _fadeController.forward(from: 0);
  }

  Future<void> _addSubject(String name) async {
    if (name.isEmpty || _subjects.contains(name)) return;
    final updated = [..._subjects, name];
    await StorageService.saveSubjects(updated);
    if (_basePath != null) {
      await StorageService.createSubjectFolder(_basePath!, name);
    }
    await _loadData();
    _showSnack('Subject "$name" added');
  }

  Future<void> _deleteSubjectFromListOnly(String name) async {
    final updated = [..._subjects]..remove(name);
    await StorageService.saveSubjects(updated);
    await _loadData();
    _showSnack('Subject "$name" removed from app');
  }

  Future<void> _deleteSubjectWithFolder(String name) async {
    try {
      if (_basePath != null) {
        final dir = Directory('$_basePath/$name');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
    final updated = [..._subjects]..remove(name);
    await StorageService.saveSubjects(updated);
    await _loadData();
    _showSnack('"$name" and its photos deleted');
  }

  void _showAddSubjectDialog() {
    _newSubjectController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Subject',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _newSubjectController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Subject name...',
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF89B0AE), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          // vivid solid button, never dim
          ElevatedButton(
            onPressed: () {
              final name = _newSubjectController.text.trim();
              Navigator.pop(context);
              _addSubject(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF035955),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteSubjectDialog(String name) {
    if (name == 'Unclassified') return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
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
            const Text('Remove Subject',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: Colors.grey, height: 1.5),
            children: [
              const TextSpan(text: 'What would you like to do with '),
              TextSpan(
                text: '"$name"',
                style: const TextStyle(
                    color: Color(0xFFE07A5F),
                    fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          // blue solid button for softer action
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSubjectFromListOnly(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90D9),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('App only',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          // red solid button for destructive action
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSubjectWithFolder(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete all',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError
          ? const Color(0xFFE07A5F)
          : const Color(0xFF035955),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.headerCard,
        onRefresh: _loadData,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.headerCard))
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildStatCards(),
                            const SizedBox(height: 24),
                            if (_subjects.isEmpty)
                              _buildEmptyState()
                            else ...[
                              _buildSectionHeader(),
                              const SizedBox(height: 16),
                              _buildSubjectGrid(),
                            ],
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
Widget _buildHeader() {
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
            color: Color(0x55035955), blurRadius: 18, offset: Offset(0, 6)),
      ],
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_stories_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'LectureVault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                // search button opens the search screen
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/search');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Hi there!',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ready to organize\nyour notes?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 18),
            if (_basePath != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _basePath!,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatCards() {
    final stats = [
      {
        'label': 'Total Photos',
        'value': '$_totalPhotos',
        'icon': Icons.photo_library_rounded,
        'color': const Color(0xFF035955),
      },
      {
        'label': 'Subjects',
        'value': '${_subjects.length}',
        'icon': Icons.folder_rounded,
        'color': const Color(0xFF89B0AE),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: stats.asMap().entries.map((entry) {
          final s = entry.value;
          final isLast = entry.key == stats.length - 1;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: (s['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s['icon'] as IconData,
                        color: s['color'] as Color, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s['value'] as String,
                    style: TextStyle(
                      color: s['color'] as Color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.headerCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33035955),
                blurRadius: 8,
                offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Subjects',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_subjects.length} folder${_subjects.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // add button is always clearly visible on the teal header
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showAddSubjectDialog();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Use full names e.g. Calculus not calc for better results',
              style: TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.1,
        ),
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          return _buildSubjectCard(index);
        },
      ),
    );
  }

  Widget _buildSubjectCard(int index) {
    final subject = _subjects[index];
    final count = _photoCounts[subject] ?? 0;
    final bgColor = _cardColors[index % _cardColors.length];
    final iconColor = _iconColors[index % _iconColors.length];
    final icon = _subjectIcons[index % _subjectIcons.length];

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(
          context,
          '/folder',
          arguments: {
            'folderName': subject,
            'icon': icon,
            'basePath': _basePath,
          },
        ).then((_) => _loadData());
      },
      onLongPress: () => _showDeleteSubjectDialog(subject),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                // delete button always uses a solid color, never dim
                if (subject != 'Unclassified')
                  GestureDetector(
                    onTap: () => _showDeleteSubjectDialog(subject),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE07A5F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFE07A5F),
                          size: 14),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              subject,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.photo_outlined,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  '$count photo${count != 1 ? 's' : ''}',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF89B0AE).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_rounded,
                  color: Color(0xFF89B0AE), size: 52),
            ),
            const SizedBox(height: 20),
            const Text('No subjects yet',
                style: TextStyle(
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first subject',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            // big vivid CTA button, never dim
            ElevatedButton.icon(
              onPressed: _showAddSubjectDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF035955),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: const Color(0xFF035955).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Subject',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'Home', 0),
              _navItem(Icons.upload_rounded, 'Upload', 1),
              _navItem(Icons.settings_rounded, 'Settings', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (index == 1) {
          await Navigator.pushNamed(context, '/upload');
          _loadData();
        }
        if (index == 2) {
          await Navigator.pushNamed(context, '/settings');
          _loadData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.headerCard.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                // selected is brand teal, unselected is medium gray (not dim)
                color: isSelected
                    ? AppColors.headerCard
                    : const Color(0xFF8A9BA8),
                size: 24),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.headerCard
                      : const Color(0xFF8A9BA8),
                  fontSize: 10,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}