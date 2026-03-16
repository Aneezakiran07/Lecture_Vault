import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/colors.dart';
import '../../services/storage_service.dart';

class FolderSetupScreen extends StatefulWidget {
  const FolderSetupScreen({super.key});

  @override
  State<FolderSetupScreen> createState() => _FolderSetupScreenState();
}

class _FolderSetupScreenState extends State<FolderSetupScreen> {
  String? _selectedPath;
  bool _isCreating = false;
  final TextEditingController _subjectController = TextEditingController();
  final List<String> _subjects = ['Mathematics', 'Physics'];

  void _addSubject() {
    final text = _subjectController.text.trim();
    if (text.isNotEmpty && !_subjects.contains(text)) {
      setState(() {
        _subjects.add(text);
        _subjectController.clear();
      });
    }
  }

  void _removeSubject(String subject) {
    setState(() => _subjects.remove(subject));
  }

  Future<void> _browseFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to save your lectures',
    );
    if (result != null) {
      setState(() => _selectedPath = '$result/LectureVault');
    }
  }

  Future<void> _continue() async {
    if (_selectedPath == null) {
      _showSnack('Please choose a storage location', isError: true);
      return;
    }
    if (_subjects.isEmpty) {
      _showSnack('Please add at least one subject', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    // ── REAL SAVE ────────────────────────────────────────────────
    await StorageService.saveBasePath(_selectedPath!);
    await StorageService.saveSubjects(_subjects);
    await StorageService.markSetupDone();
    // ────────────────────────────────────────────────────────────

    setState(() => _isCreating = false);

    if (mounted) {
      _showSnack('✓ Setup complete! ${_subjects.length} subjects saved');
      await Future.delayed(const Duration(milliseconds: 800));
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? const Color(0xFFE07A5F) : const Color(0xFF035955),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepIndicator(),
                  const SizedBox(height: 28),
                  _buildStorageSection(),
                  const SizedBox(height: 24),
                  const Divider(thickness: 1, color: Color(0xFFE0E0E0)),
                  const SizedBox(height: 24),
                  _buildSubjectSection(),
                ],
              ),
            ),
          ),
          _buildContinueButton(),
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
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x55035955), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('LectureVault',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome to LectureVault',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Let\'s set up your workspace',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  value: 0.5,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF89B0AE)),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(1, active: true),
        Expanded(child: Container(height: 2, color: const Color(0xFF89B0AE))),
        _stepDot(2, active: false),
      ],
    );
  }

  Widget _stepDot(int step, {required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 36 : 28,
      height: active ? 36 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.headerCard : Colors.white,
        border: Border.all(
          color: active ? AppColors.headerCard : Colors.grey.shade400,
          width: 2,
        ),
        boxShadow: active
            ? const [BoxShadow(color: Color(0x44035955), blurRadius: 8, offset: Offset(0, 2))]
            : [],
      ),
      child: Center(
        child: Text('$step',
            style: TextStyle(
                color: active ? Colors.white : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                fontSize: active ? 14 : 12)),
      ),
    );
  }

  Widget _buildStorageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose Storage Location',
            style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Photos will be saved to this folder on your device',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 14),
        InkWell(
          onTap: _browseFolder,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_rounded,
                    color: Color(0xFF89B0AE), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedPath ?? 'No folder selected',
                    style: TextStyle(
                        color: _selectedPath != null
                            ? AppColors.bodyText
                            : Colors.grey,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _browseFolder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89B0AE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Browse',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Create Subject Folders',
                style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF89B0AE).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_subjects.length}',
                  style: const TextStyle(
                      color: Color(0xFF89B0AE),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Add subjects you are currently studying',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        _subjects.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Center(
                  child: Text('No subjects yet. Add one below!',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _subjects.map((s) => _buildSubjectChip(s)).toList(),
              ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subjectController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSubject(),
                decoration: InputDecoration(
                  hintText: 'New subject name...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF89B0AE), width: 2)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _addSubject,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B0AE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                elevation: 0,
              ),
              child: const Text('ADD',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubjectChip(String subject) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF89B0AE),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Color(0x3389B0AE), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(subject,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeSubject(subject),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isCreating ? null : _continue,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.headerCard,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 2,
        ),
        child: _isCreating
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}