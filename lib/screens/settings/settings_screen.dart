import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimController;
  late Animation<double> _headerFadeAnim;

  // ── MOCK DATA ────────────────────────────────────────────────────
  String _storagePath = '/storage/emulated/0/LectureVault';
  List<String> _subjects = ['Mathematics', 'Physics', 'Chemistry', 'AI & ML'];
  final int _totalPhotos = 51;
  final bool _isLoading = false;
  // ────────────────────────────────────────────────────────────────

  bool _autoClassify = true;
  bool _showConfidence = true;
  bool _saveOriginal = false;

  final String _appVersion = '1.0.0 (Build 1)';
  final TextEditingController _newSubjectController = TextEditingController();

  final List<IconData> _subjectIcons = [
    Icons.calculate_rounded, Icons.science_rounded, Icons.biotech_rounded,
    Icons.history_edu_rounded, Icons.eco_rounded, Icons.menu_book_rounded,
    Icons.public_rounded, Icons.computer_rounded, Icons.music_note_rounded,
    Icons.palette_rounded,
  ];

  final List<Color> _iconColors = [
    const Color(0xFF035955), const Color(0xFF4A90D9), const Color(0xFF9B59B6),
    const Color(0xFFE07A5F), const Color(0xFF27AE60), const Color(0xFFE91E8C),
    const Color(0xFF035955), const Color(0xFF4A90D9), const Color(0xFF9B59B6),
    const Color(0xFFE07A5F),
  ];

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _headerAnimController.forward();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _newSubjectController.dispose();
    super.dispose();
  }

  Future<void> _addSubject(String name) async {
    if (name.isEmpty || _subjects.contains(name)) return;
    setState(() => _subjects = [..._subjects, name]);
    _showSnack('✓ Subject "$name" added');
  }

  Future<void> _renameSubject(int index, String newName) async {
    if (newName.isEmpty || _subjects.contains(newName)) return;
    final newSubjects = [..._subjects];
    newSubjects[index] = newName;
    setState(() => _subjects = newSubjects);
    _showSnack('✓ Renamed to "$newName"');
  }

  void _deleteSubject(int index) {
    final name = _subjects[index];
    setState(() => _subjects = [..._subjects]..removeAt(index));
    _showSnack('Subject "$name" removed from list');
  }

  void _showAddSubjectDialog() {
    _newSubjectController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Subject',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _newSubjectController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Subject name...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF89B0AE), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _newSubjectController.text.trim();
              Navigator.pop(context);
              _addSubject(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89B0AE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(int index) {
    _newSubjectController.text = _subjects[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Subject',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _newSubjectController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New name...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF89B0AE), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _newSubjectController.text.trim();
              Navigator.pop(context);
              _renameSubject(index, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.headerCard,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSubjectDialog(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Subject',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Remove "${_subjects[index]}" from your list? Photos inside will not be deleted.',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _deleteSubject(index); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'This will reset the app completely. You will be taken back to setup. Your actual photo files will NOT be deleted.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                  context, '/onboarding', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reset App'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFE07A5F) : const Color(0xFF035955),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          FadeTransition(opacity: _headerFadeAnim, child: _buildHeader()),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.headerCard))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildProfileCard(),
                        const SizedBox(height: 20),
                        _buildSectionHeader('Storage', Icons.storage_rounded),
                        _buildStorageSection(),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Subjects', Icons.folder_rounded),
                        _buildSubjectsSection(),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Classification', Icons.auto_awesome_rounded),
                        _buildClassificationSection(),
                        const SizedBox(height: 16),
                        _buildSectionHeader('About', Icons.info_rounded),
                        _buildAboutSection(),
                        const SizedBox(height: 16),
                        _buildDangerZone(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
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
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Settings',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _headerStatPill(Icons.folder_rounded, '${_subjects.length}', 'Subjects'),
                  const SizedBox(width: 10),
                  _headerStatPill(Icons.photo_rounded, '$_totalPhotos', 'Photos'),
                  const SizedBox(width: 10),
                  _headerStatPill(Icons.storage_rounded, 'Local', 'Storage'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStatPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF035955), Color(0xFF89B0AE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('LV',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LectureVault',
                      style: TextStyle(
                          color: AppColors.bodyText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  SizedBox(height: 3),
                  Text('Your personal lecture organizer',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF89B0AE).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('v1.0.0',
                  style: TextStyle(
                      color: Color(0xFF89B0AE),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.headerCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x33035955), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildStorageSection() {
    return _buildCard(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF035955).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_open_rounded,
                  color: Color(0xFF035955), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Storage Location',
                      style: TextStyle(
                          color: AppColors.bodyText,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(_storagePath,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      overflow: TextOverflow.ellipsis, maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showSnack('✓ Storage location updated'),
              child: const Text('Change',
                  style: TextStyle(
                      color: Color(0xFF89B0AE),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsSection() {
    return _buildCard(
      Column(
        children: [
          if (_subjects.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No subjects yet. Add one below!',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
          ..._subjects.asMap().entries.map((entry) {
            final index = entry.key;
            final subject = entry.value;
            final isLast = index == _subjects.length - 1;
            final iconColor = _iconColors[index % _iconColors.length];
            final icon = _subjectIcons[index % _subjectIcons.length];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(subject,
                            style: const TextStyle(
                                color: AppColors.bodyText,
                                fontWeight: FontWeight.w500,
                                fontSize: 14)),
                      ),
                      GestureDetector(
                        onTap: () => _showRenameDialog(index),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF035955).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: Color(0xFF035955), size: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showDeleteSubjectDialog(index),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE07A5F).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFE07A5F), size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                      height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
              ],
            );
          }),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          GestureDetector(
            onTap: _showAddSubjectDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF89B0AE).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Color(0xFF89B0AE), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('Add Subject',
                      style: TextStyle(
                          color: Color(0xFF89B0AE),
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection() {
    return _buildCard(
      Column(
        children: [
          _buildToggleTile(
            icon: Icons.auto_awesome_rounded, iconColor: const Color(0xFF035955),
            title: 'Auto-classify on upload', subtitle: 'Automatically sort photos using AI',
            value: _autoClassify, onChanged: (v) => setState(() => _autoClassify = v),
            showDivider: true,
          ),
          _buildToggleTile(
            icon: Icons.percent_rounded, iconColor: const Color(0xFF4A90D9),
            title: 'Show confidence score', subtitle: 'Display AI accuracy percentage',
            value: _showConfidence, onChanged: (v) => setState(() => _showConfidence = v),
            showDivider: true,
          ),
          _buildToggleTile(
            icon: Icons.save_alt_rounded, iconColor: const Color(0xFF9B59B6),
            title: 'Keep original copy', subtitle: 'Save original before moving',
            value: _saveOriginal, onChanged: (v) => setState(() => _saveOriginal = v),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon, required Color iconColor, required String title,
    required String subtitle, required bool value,
    required ValueChanged<bool> onChanged, required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.bodyText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: value, onChanged: onChanged,
                activeColor: const Color(0xFF89B0AE),
                activeTrackColor: const Color(0xFF89B0AE).withOpacity(0.3),
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade200,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildCard(
      Column(
        children: [
          _buildAboutTile(icon: Icons.info_outline_rounded, iconColor: const Color(0xFF035955),
            title: 'App Version', trailing: Text(_appVersion,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            showDivider: true, onTap: () {}),
          _buildAboutTile(icon: Icons.star_outline_rounded, iconColor: const Color(0xFFFFB300),
            title: 'Rate LectureVault', showDivider: true, onTap: () {}),
          _buildAboutTile(icon: Icons.privacy_tip_outlined, iconColor: const Color(0xFF4A90D9),
            title: 'Privacy Policy', showDivider: false, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildAboutTile({
    required IconData icon, required Color iconColor, required String title,
    required VoidCallback onTap, required bool showDivider, Widget? trailing,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.bodyText,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
          trailing: trailing ??
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Colors.grey.shade400),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE07A5F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFE07A5F), size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('Danger Zone',
                      style: TextStyle(
                          color: Color(0xFFE07A5F),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
            ListTile(
              onTap: _showClearDataDialog,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE07A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_sweep_rounded,
                    color: Color(0xFFE07A5F), size: 18),
              ),
              title: const Text('Reset App',
                  style: TextStyle(
                      color: Color(0xFFE07A5F),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              subtitle: const Text('Clear all settings and go back to setup',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              trailing: Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: const Color(0xFFE07A5F).withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
