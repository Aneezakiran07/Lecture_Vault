import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;

  int _selectedNavIndex = 0;

  List<String> _subjects = [];
  String? _basePath;
  Map<String, int> _photoCounts = {};
  int _totalPhotos = 0;
  bool _isLoading = true;

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
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabScaleAnim = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.elasticOut,
    );
    _fabAnimController.forward();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
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
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
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
                  : SingleChildScrollView(
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
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnim,
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.pushNamed(context, '/upload');
            _loadData();
          },
          backgroundColor: AppColors.headerCard,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: const Text('Upload',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              color: Color(0x55035955),
              blurRadius: 18,
              offset: Offset(0, 6)),
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
                  Row(
                    children: [
                      _headerIconButton(Icons.refresh_rounded, _loadData),
                      const SizedBox(width: 8),
                      _headerIconButton(
                        Icons.settings_outlined,
                        () => Navigator.pushNamed(context, '/settings')
                            .then((_) => _loadData()),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Hi',
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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

  Widget _headerIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Subjects',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
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
      onTap: () => Navigator.pushNamed(
        context,
        '/folder',
        arguments: {
          'folderName': subject,
          'icon': icon,
          'basePath': _basePath,
        },
      ).then((_) => _loadData()),
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
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.grey.shade300, size: 14),
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
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 11),
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
              'Go to Settings to add your first subject folder',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/settings')
                      .then((_) => _loadData()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.headerCard,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Go to Settings',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
        setState(() => _selectedNavIndex = index);
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
              ? AppColors.headerCard.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected
                    ? AppColors.headerCard
                    : Colors.grey.shade400,
                size: 24),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.headerCard
                      : Colors.grey.shade400,
                  fontSize: 10,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

 