import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

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

  // ── MOCK DATA ────────────────────────────────────────────────────
  final List<String> _subjects = [
    'Mathematics', 'Physics', 'Chemistry', 'AI & ML', 'History', 'English'
  ];
  final String _basePath = '/storage/emulated/0/LectureVault';
  final Map<String, int> _photoCounts = {
    'Mathematics': 12, 'Physics': 8, 'Chemistry': 5,
    'AI & ML': 17, 'History': 3, 'English': 6,
  };
  final int _totalPhotos = 51;
  final int _unclassified = 0;
  final bool _isLoading = false;
  // ────────────────────────────────────────────────────────────────

  final List<IconData> _subjectIcons = [
    Icons.calculate_rounded, Icons.science_rounded, Icons.biotech_rounded,
    Icons.history_edu_rounded, Icons.eco_rounded, Icons.menu_book_rounded,
    Icons.public_rounded, Icons.computer_rounded, Icons.music_note_rounded,
    Icons.palette_rounded, Icons.sports_soccer_rounded, Icons.psychology_rounded,
  ];

  final List<Color> _cardColors = [
    const Color(0xFFE8F5F4), const Color(0xFFEAF0F6), const Color(0xFFF0EAF6),
    const Color(0xFFF6F0EA), const Color(0xFFEAF6F0), const Color(0xFFF6EAF0),
  ];

  final List<Color> _iconColors = [
    const Color(0xFF035955), const Color(0xFF4A90D9), const Color(0xFF9B59B6),
    const Color(0xFFE07A5F), const Color(0xFF27AE60), const Color(0xFFE91E8C),
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
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.headerCard))
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildStatCards(),
                          const SizedBox(height: 24),
                          if (_unclassified > 0) _buildUnclassifiedBanner(),
                          if (_unclassified > 0) const SizedBox(height: 24),
                          _buildSectionHeader(),
                          const SizedBox(height: 16),
                          _buildSubjectGrid(),
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
          onPressed: () => Navigator.pushNamed(context, '/upload'),
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
          BoxShadow(color: Color(0x55035955), blurRadius: 18, offset: Offset(0, 6)),
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
                      const Text('LectureVault',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                  Row(
                    children: [
                      _headerIconButton(Icons.refresh_rounded, () {}),
                      const SizedBox(width: 8),
                      _headerIconButton(Icons.settings_outlined,
                          () => Navigator.pushNamed(context, '/settings')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Good morning! 👋',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Ready to organize\nyour lectures?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.25)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      child: Text(_basePath,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
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
      {'label': 'Total Photos', 'value': '$_totalPhotos',
        'icon': Icons.photo_library_rounded, 'color': const Color(0xFF035955)},
      {'label': 'Subjects', 'value': '${_subjects.length}',
        'icon': Icons.folder_rounded, 'color': const Color(0xFF89B0AE)},
      {'label': 'Unclassified', 'value': '$_unclassified',
        'icon': Icons.help_outline_rounded, 'color': const Color(0xFFE07A5F)},
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
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
                  Text(s['value'] as String,
                      style: TextStyle(
                          color: s['color'] as Color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(s['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnclassifiedBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFF3F1), Color(0xFFFFECE8)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE07A5F).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFE07A5F), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_unclassified photo${_unclassified > 1 ? 's' : ''} need attention',
                      style: const TextStyle(
                          color: Color(0xFFB85C45),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  const Text('These could not be auto-classified',
                      style: TextStyle(color: Color(0xFFB85C45), fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE07A5F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Review',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.headerCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x33035955), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Your Subjects',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        itemBuilder: (context, index) => _buildSubjectCard(index),
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
      onTap: () => Navigator.pushNamed(context, '/folder', arguments: {
        'folderName': subject,
        'icon': icon,
        'basePath': _basePath,
      }),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
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
            Text(subject,
                style: const TextStyle(
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.photo_outlined, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('$count photo${count != 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
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
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
        if (index == 1) await Navigator.pushNamed(context, '/upload');
        if (index == 2) await Navigator.pushNamed(context, '/settings');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                color: isSelected ? AppColors.headerCard : Colors.grey.shade400,
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
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}