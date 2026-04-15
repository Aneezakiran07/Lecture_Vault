import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/colors.dart';
import '../../services/storage_service.dart';
import '../../services/permission_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {

  late AnimationController _headerAnimController;
  late Animation<double> _headerFadeAnim;

  String _storagePath = '';
  List<String> _subjects = [];
  int _totalPhotos = 0;

  bool _autoClassify = true;
  bool _showConfidence = true;
  bool _saveOriginal = false; // false means move, true means keep a copy
  bool _isLoading = true;

  final TextEditingController _newSubjectController =
      TextEditingController();

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
  ];

  final List<Color> _iconColors = [
    const Color(0xFF035955),
    const Color(0xFF4A90D9),
    const Color(0xFF9B59B6),
    const Color(0xFFE07A5F),
    const Color(0xFF27AE60),
    const Color(0xFFE91E8C),
    const Color(0xFF035955),
    const Color(0xFF4A90D9),
    const Color(0xFF9B59B6),
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final path = await StorageService.getBasePath();
    final subjects = await StorageService.getSubjects();
    final classSettings = await StorageService.getClassificationSettings();

    int total = 0;
    if (path != null) {
      final counts =
          await StorageService.getSubjectPhotoCounts(path, subjects);
      total = counts.values.fold(0, (a, b) => a + b);
    }

    setState(() {
      _storagePath = path ?? 'Not set';
      _subjects = subjects;
      _totalPhotos = total;
      _autoClassify = classSettings['autoClassify']!;
      _showConfidence = classSettings['showConfidence']!;
      _saveOriginal = classSettings['saveOriginal'] ?? false;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _newSubjectController.dispose();
    super.dispose();
  }

  Future<void> _changeStoragePath() async {
    final hasPermission =
        await PermissionService.requestStoragePermission();
    if (!hasPermission) {
      _showSnack('Storage permission required', isError: true);
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose new storage location',
    );

    if (result != null) {
      final newPath = '$result/LectureVault';
      await StorageService.createAllSubjectFolders(newPath, _subjects);
      await StorageService.saveBasePath(newPath);
      setState(() => _storagePath = newPath);
      _showSnack('Storage location updated');
    }
  }

  Future<void> _addSubject(String name) async {
    if (name.isEmpty || _subjects.contains(name)) return;
    final newSubjects = [..._subjects, name];
    await StorageService.saveSubjects(newSubjects);
    if (_storagePath.isNotEmpty && _storagePath != 'Not set') {
      await StorageService.createSubjectFolder(_storagePath, name);
    }
    setState(() => _subjects = newSubjects);
    _showSnack('Subject "$name" added');
  }

  Future<void> _renameSubject(int index, String newName) async {
    if (newName.isEmpty || _subjects.contains(newName)) return;
    final newSubjects = [..._subjects];
    newSubjects[index] = newName;
    await StorageService.saveSubjects(newSubjects);
    if (_storagePath.isNotEmpty && _storagePath != 'Not set') {
      await StorageService.createSubjectFolder(_storagePath, newName);
    }
    setState(() => _subjects = newSubjects);
    _showSnack('Renamed to "$newName"');
  }

  Future<void> _deleteSubjectFromListOnly(int index) async {
    final name = _subjects[index];
    final newSubjects = [..._subjects]..removeAt(index);
    await StorageService.saveSubjects(newSubjects);
    setState(() => _subjects = newSubjects);
    _showSnack('Subject "$name" removed from list');
  }

  Future<void> _deleteSubjectWithFolder(int index) async {
    final name = _subjects[index];
    try {
      if (_storagePath.isNotEmpty && _storagePath != 'Not set') {
        final dir = Directory('$_storagePath/$name');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
    final newSubjects = [..._subjects]..removeAt(index);
    await StorageService.saveSubjects(newSubjects);
    setState(() => _subjects = newSubjects);
    _showSnack('Subject "$name" and its photos deleted');
  }

  Future<void> _clearAllData() async {
    await StorageService.clearAll();
    setState(() {
      _subjects = [];
      _storagePath = 'Not set';
    });
    _showSnack('All data cleared');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/onboarding', (route) => false);
    }
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

  void _showRenameDialog(int index) {
    _newSubjectController.text = _subjects[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Subject',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _newSubjectController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New name...',
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
          ElevatedButton(
            onPressed: () {
              final name = _newSubjectController.text.trim();
              Navigator.pop(context);
              _renameSubject(index, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF035955),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteSubjectDialog(int index) {
    final name = _subjects[index];
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSubjectFromListOnly(index);
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSubjectWithFolder(index);
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

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'This will reset the app completely. You will be taken back to setup. Your actual photo files will NOT be deleted.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reset App',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? const Color(0xFFE07A5F) : const Color(0xFF035955),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          FadeTransition(
            opacity: _headerFadeAnim,
            child: _buildHeader(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.headerCard))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildProfileCard(),
                        const SizedBox(height: 12),
                        _buildDataSafetyCard(),
                        const SizedBox(height: 20),
                        _buildSectionHeader(
                            'Storage', Icons.storage_rounded),
                        _buildStorageSection(),
                        const SizedBox(height: 16),
                        _buildSectionHeader(
                            'Subjects', Icons.folder_rounded),
                        _buildSubjectsSection(),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Classification',
                            Icons.auto_awesome_rounded),
                        _buildClassificationSection(),
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
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Settings',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: _loadData,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _headerStatPill(Icons.folder_rounded,
                      '${_subjects.length}', 'Subjects'),
                  const SizedBox(width: 10),
                  _headerStatPill(
                      Icons.photo_rounded, '$_totalPhotos', 'Photos'),
                  const SizedBox(width: 10),
                  _headerStatPill(
                      Icons.storage_rounded, 'Local', 'Storage'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStatPill(
      IconData icon, String value, String label) {
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 10)),
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
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF035955), Color(0xFF89B0AE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              // show the actual app logo instead of LV text
              child: Center(
                child: SvgPicture.asset(
                  'assets/logo.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
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
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF035955).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('v1.0.0',
                  style: TextStyle(
                      color: Color(0xFF035955),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSafetyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF035955).withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF035955).withOpacity(0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF035955).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFF035955),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your photos are always safe',
                    style: TextStyle(
                      color: Color(0xFF035955),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'We never touch your camera roll. LectureVault makes a copy of your photos and stores them in your chosen folder. Your originals stay exactly where they are.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 13),
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
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
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
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2)),
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
                  Text(
                    _storagePath.isEmpty ||
                            _storagePath == 'Not set'
                        ? 'Not configured'
                        : _storagePath,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // solid button replaces the dim "Change" text link
            ElevatedButton(
              onPressed: _changeStoragePath,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF035955),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
              ),
              child: const Text('Change',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
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
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13)),
            ),
          ..._subjects.asMap().entries.map((entry) {
            final index = entry.key;
            final subject = entry.value;
            final isLast = index == _subjects.length - 1;
            final iconColor =
                _iconColors[index % _iconColors.length];
            final icon =
                _subjectIcons[index % _subjectIcons.length];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(subject,
                            style: const TextStyle(
                                color: AppColors.bodyText,
                                fontWeight: FontWeight.w500,
                                fontSize: 14)),
                      ),
                      // edit button uses solid teal color, clearly visible
                      GestureDetector(
                        onTap: () => _showRenameDialog(index),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF035955)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: Color(0xFF035955), size: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // delete button uses solid red, clearly visible
                      if (subject != 'Unclassified')
                        GestureDetector(
                          onTap: () =>
                              _showDeleteSubjectDialog(index),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE07A5F)
                                  .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFE07A5F),
                                size: 15),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                      height: 1,
                      color: Color(0xFFF0F0F0),
                      indent: 16,
                      endIndent: 16),
              ],
            );
          }),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // add subject row uses solid teal icon and text
          GestureDetector(
            onTap: _showAddSubjectDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF035955).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Color(0xFF035955), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('Add Subject',
                      style: TextStyle(
                          color: Color(0xFF035955),
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
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF035955),
            title: 'Auto-classify on upload',
            subtitle: 'Automatically sort photos using AI',
            value: _autoClassify,
            onChanged: (v) async {
              setState(() => _autoClassify = v);
              await StorageService.saveClassificationSettings(
                autoClassify: v,
                showConfidence: _showConfidence,
                saveOriginal: _saveOriginal,
              );
            },
            showDivider: true,
          ),
          _buildToggleTile(
            icon: Icons.percent_rounded,
            iconColor: const Color(0xFF4A90D9),
            title: 'Show confidence score',
            subtitle: 'Display AI accuracy percentage',
            value: _showConfidence,
            onChanged: (v) async {
              setState(() => _showConfidence = v);
              await StorageService.saveClassificationSettings(
                autoClassify: _autoClassify,
                showConfidence: v,
                saveOriginal: _saveOriginal,
              );
            },
            showDivider: true,
          ),
          _buildToggleTile(
            icon: Icons.copy_rounded,
            iconColor: const Color(0xFF9B59B6),
            title: 'Keep original in gallery',
            subtitle: _saveOriginal
                // when ON we copy the photo so original stays in gallery
                ? 'Photos are copied — originals stay in your gallery'
                // when OFF we move the photo out of gallery into our folder
                : 'Photos are moved into LectureVault folder',
            value: _saveOriginal,
            onChanged: (v) async {
              setState(() => _saveOriginal = v);
              await StorageService.saveClassificationSettings(
                autoClassify: _autoClassify,
                showConfidence: _showConfidence,
                saveOriginal: v,
              );
            },
            showDivider: false,
          ),
          // info card explaining what this toggle actually does
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9B59B6).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF9B59B6).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: const Color(0xFF9B59B6).withOpacity(0.8),
                    size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saveOriginal
                        ? 'ON: LectureVault makes a copy of each photo and saves it to your subject folder. Your gallery stays untouched.'
                        : 'OFF: LectureVault moves the photo from your gallery into your subject folder. This saves storage space.',
                    style: TextStyle(
                      color: const Color(0xFF9B59B6).withOpacity(0.9),
                      fontSize: 11,
                      height: 1.5,
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

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                // active track uses solid brand teal
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF035955),
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade200,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
              height: 1,
              color: Color(0xFFF0F0F0),
              indent: 16,
              endIndent: 16),
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
          border: Border.all(
              color: const Color(0xFFE07A5F).withOpacity(0.3)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2)),
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
            const Divider(
                height: 1,
                color: Color(0xFFF0F0F0),
                indent: 16,
                endIndent: 16),
            ListTile(
              onTap: _showClearDataDialog,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
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
              subtitle: const Text(
                  'Clear all settings and go back to setup',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Color(0xFFE07A5F)),
            ),
          ],
        ),
      ),
    );
  }
}