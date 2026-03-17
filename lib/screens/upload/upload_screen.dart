//upload screen
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../services/ocr_service.dart';
import '../../services/classifier_service.dart';
import '../../services/storage_service.dart';
import '../../services/permission_service.dart';
import '../../services/ocr_result.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimController;
  late Animation<double> _headerFadeAnim;

  final ImagePicker _picker = ImagePicker();
  final List<Map<String, dynamic>> _selectedPhotos = [];

  List<String> _allSubjects = [];
  String? _basePath;

  bool _isSaving = false;
  int _currentStep = 0;
  int? _expandedIndex;

  static const int _maxPhotos = 20;

  final List<String> _debugLines = [];

  void _log(String msg) {
    print(msg);
    setState(() {
      _debugLines.add(msg);
      if (_debugLines.length > 100) _debugLines.removeAt(0);
    });
  }

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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final subjects = await StorageService.getSubjects();
    final basePath = await StorageService.getBasePath();
    setState(() {
      _allSubjects = [...subjects, 'Unclassified'];
      _basePath = basePath;
    });
    _log('Loaded ${subjects.length} subjects: $subjects');
    _log('Base path: $basePath');
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  Future<void> _runBatchClassification(List<OcrResult> batchOcrResults) async {
    _log('Starting batch classification for ${batchOcrResults.length} photos...');
    setState(() {
      for (var photo in _selectedPhotos) {
        photo['isProcessing'] = true;
      }
    });
    final subjects = _allSubjects.where((s) => s != 'Unclassified').toList();
    final results = await ClassifierService.classifyAllFromOcr(
      batchOcrResults,
      subjects,
      onLog: _log,
      onProgress: (completed, total) {
        _log('Classification progress: $completed/$total');
      },
    );
    setState(() {
      for (int i = 0; i < results.length; i++) {
        if (i < _selectedPhotos.length) {
          _selectedPhotos[i]['subject'] = results[i].subject;
          _selectedPhotos[i]['confidence'] = results[i].confidence;
          _selectedPhotos[i]['isProcessing'] = false;
        }
      }
    });
    _log('Batch classification complete! ${results.length} results applied.');
  }

  Future<void> _pickFromGallery() async {
    _log('Gallery picker started');

    final hasPermission = await PermissionService.requestStoragePermission();
    _log('Permission: $hasPermission');
    if (!hasPermission) {
      _showSnack('Storage permission required', isError: true);
      return;
    }

    final remaining = _maxPhotos - _selectedPhotos.length;
    if (remaining <= 0) {
      _showSnack('Max $_maxPhotos photos per session reached', isError: true);
      return;
    }

    var picked = await _picker.pickMultiImage(imageQuality: 90);
    _log('Picked ${picked.length} photos');
    if (picked.isEmpty) return;

    // FIX: if user picked more than remaining slots, trim and tell them exactly
    // how many were removed and that they were the ones above the limit
    if (picked.length > remaining) {
      final removed = picked.length - remaining;
      picked = picked.take(remaining).toList();
      _showSnack(
        'Only $remaining slot${remaining == 1 ? '' : 's'} left — '
        '$removed photo${removed == 1 ? '' : 's'} above the $_maxPhotos limit removed',
        isError: true,
      );
      _log('Removed $removed photos exceeding session limit of $_maxPhotos');
    }

    final paths = picked.map((x) => x.path).toList();
    final subjects = _allSubjects.where((s) => s != 'Unclassified').toList();

    _log('Total photos to process: ${paths.length}');
    _log('Subjects available: $subjects');

    setState(() {
      _currentStep = 1;
      for (final path in paths) {
        _selectedPhotos.add({
          'path': path,
          'ocrText': 'Scanning...',
          'subject': '',
          'confidence': 0.0,
          'override': null,
          'isProcessing': true,
        });
      }
    });

    final startIdx = _selectedPhotos.length - paths.length;
    _log('startIdx: $startIdx');

    _log('--- OCR PHASE START ---');
    _log('Running OCR on ${paths.length} images in parallel...');
    List<OcrResult> ocrResults;
    try {
      ocrResults = await Future.wait(
        paths.map((p) => OcrService.extractRich(p)),
        eagerError: false,
      );
      _log('OCR complete for ${ocrResults.length} images');
      for (int i = 0; i < ocrResults.length; i++) {
        _log('OCR[$i]: rawLen=${ocrResults[i].rawText.length} keywords=${ocrResults[i].keywords.take(5).toList()}');
        _log('OCR[$i] rawText preview: ${ocrResults[i].rawText.substring(0, ocrResults[i].rawText.length.clamp(0, 80))}');
      }
      _log('--- OCR PHASE END ---');
    } catch (e) {
      _log('OCR failed: $e');
      return;
    }

    setState(() => _currentStep = 2);

    _log('--- GEMINI BATCH PHASE START ---');
    _log('Sending ${ocrResults.length} OCR results to Gemini in ONE request...');
    List<({String subject, double confidence})> results;
    try {
      results = await ClassifierService.classifyAllFromOcr(
        ocrResults,
        subjects,
        onLog: _log,
        onProgress: (completed, total) {
          _log('Gemini progress: $completed/$total');
        },
      );
      _log('--- GEMINI BATCH PHASE END ---');
      _log('Gemini returned ${results.length} results for ${ocrResults.length} photos');
      for (int i = 0; i < results.length; i++) {
        _log('Gemini result[$i]: subject="${results[i].subject}" confidence=${(results[i].confidence * 100).toStringAsFixed(0)}%');
      }
      if (results.length != ocrResults.length) {
        _log('WARNING: Gemini returned ${results.length} results but expected ${ocrResults.length}');
      }
    } catch (e) {
      _log('Classification failed: $e');
      return;
    }

    _log('--- UI UPDATE PHASE ---');
    setState(() {
      for (int i = 0; i < paths.length; i++) {
        final idx = startIdx + i;
        if (idx >= _selectedPhotos.length) {
          _log('SKIP idx=$idx out of bounds (total=${_selectedPhotos.length})');
          continue;
        }
        final ocr = ocrResults[i];
        final result = i < results.length
            ? results[i]
            : (subject: 'Unclassified', confidence: 0.0);
        _log('Applying result[$i] to photo idx=$idx: subject="${result.subject}"');
        if (result.subject == 'No Internet') {
          _selectedPhotos[idx]['ocrText'] = 'Connect to internet to classify';
          _selectedPhotos[idx]['subject'] = 'Unclassified';
          _selectedPhotos[idx]['confidence'] = 0.0;
        } else {
          _selectedPhotos[idx]['ocrText'] = ocr.keywords.isNotEmpty
              ? ocr.keywords.take(8).join(', ')
              : 'No text detected';
          _selectedPhotos[idx]['subject'] = result.subject;
          _selectedPhotos[idx]['confidence'] = result.confidence;
        }
        _selectedPhotos[idx]['isProcessing'] = false;
      }
      _currentStep = 2;
    });
    _log('--- UI UPDATE DONE ---');

    if (results.any((r) => r.subject == 'No Internet')) {
      _showSnack('No internet. Connect to classify photos', isError: true);
    }
  }

  Future<void> _pickFromCamera() async {
    _log('Camera picker started');

    if (_selectedPhotos.length >= _maxPhotos) {
      _showSnack('Max $_maxPhotos photos per session reached', isError: true);
      return;
    }

    final hasCam = await PermissionService.requestCameraPermission();
    _log('Camera permission: $hasCam');
    if (!hasCam) {
      _showSnack('Camera permission required', isError: true);
      return;
    }

    final xFile = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 90);
    if (xFile == null) {
      _log('No photo taken');
      return;
    }

    _log('Photo taken: ${xFile.path}');
    setState(() => _currentStep = 1);

    final entry = {
      'path': xFile.path,
      'ocrText': '',
      'subject': '',
      'confidence': 0.0,
      'override': null,
      'isProcessing': true,
    };
    setState(() => _selectedPhotos.add(entry));

    try {
      _log('Running OCR...');
      final ocrResult = await OcrService.extractRich(xFile.path);
      _log('OCR done: ${ocrResult.keywords.length} keywords');
      _log('keywords: ${ocrResult.keywords.take(8).toList()}');
      _log('rawLen: ${ocrResult.rawText.length}');

      final subjects = _allSubjects.where((s) => s != 'Unclassified').toList();
      _log('Classifying single into: $subjects');

      final match = await ClassifierService.classify(ocrResult, subjects);
      _log('Single result: ${match.subject} (${match.confidence})');

      setState(() {
        final idx = _selectedPhotos.indexOf(entry);
        if (idx != -1) {
          _selectedPhotos[idx]['ocrText'] = ocrResult.keywords.isNotEmpty
              ? ocrResult.keywords.take(8).join(', ')
              : 'No text detected';
          _selectedPhotos[idx]['subject'] = match.subject;
          _selectedPhotos[idx]['confidence'] = match.confidence;
          _selectedPhotos[idx]['isProcessing'] = false;
        }
      });
    } catch (e) {
      _log('Camera classify error: $e');
      setState(() {
        final idx = _selectedPhotos.indexOf(entry);
        if (idx != -1) {
          _selectedPhotos[idx]['ocrText'] = 'Processing failed';
          _selectedPhotos[idx]['subject'] = 'Unclassified';
          _selectedPhotos[idx]['confidence'] = 0.0;
          _selectedPhotos[idx]['isProcessing'] = false;
        }
      });
    }
  }

  void _showPickOptions() {
    if (_selectedPhotos.length >= _maxPhotos) {
      _showSnack('Max $_maxPhotos photos per session reached', isError: true);
      return;
    }
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
            const Text('Add Photos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _pickOptionTile(
              Icons.photo_library_rounded,
              'Choose from Gallery',
              'Select multiple photos at once',
              const Color(0xFF035955),
              _pickFromGallery,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _pickOptionTile(
              Icons.camera_alt_rounded,
              'Take a Photo',
              'Capture whiteboard directly',
              const Color(0xFF89B0AE),
              _pickFromCamera,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _pickOptionTile(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 13, color: Colors.grey.shade400),
    );
  }

  Future<void> _confirmAndSave() async {
    if (_basePath == null) {
      _showSnack('No storage path set.', isError: true);
      return;
    }
    setState(() {
      _isSaving = true;
      _currentStep = 3;
    });
    int saved = 0;
    int failed = 0;
    for (final photo in _selectedPhotos) {
      final subject =
          photo['override'] as String? ?? photo['subject'] as String;
      final path = photo['path'] as String;
      await StorageService.createSubjectFolder(_basePath!, subject);
      final result = await StorageService.savePhotoToSubject(
        sourcePath: path,
        basePath: _basePath!,
        subject: subject,
      );
      if (result != null) {
        saved++;
      } else {
        failed++;
      }
    }
    setState(() => _isSaving = false);
    if (mounted) {
      if (failed == 0) {
        _showSnack('$saved photo${saved > 1 ? 's' : ''} saved successfully!');
        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnack('$saved saved, $failed failed.', isError: true);
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
      if (_selectedPhotos.isEmpty) _currentStep = 0;
    });
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          FadeTransition(
            opacity: _headerFadeAnim,
            child: _buildHeader(),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildUploadZone(),
                  if (_debugLines.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Debug Log',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _debugLines.clear()),
                                child: const Text('clear',
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 10)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ..._debugLines.map((line) => Text(
                                line,
                                style: const TextStyle(
                                    fontSize: 10, fontFamily: 'monospace'),
                              )),
                        ],
                      ),
                    ),
                  if (_selectedPhotos.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                        'Selected Photos',
                        Icons.photo_library_rounded,
                        '${_selectedPhotos.length}/$_maxPhotos'),
                    const SizedBox(height: 14),
                    _buildPhotoStrip(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Classification Preview',
                        Icons.auto_awesome_rounded, 'AI powered'),
                    const SizedBox(height: 14),
                    _buildClassificationList(),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final steps = ['Select', 'OCR Scan', 'Classify', 'Save'];
    final icons = [
      Icons.upload_rounded,
      Icons.document_scanner_rounded,
      Icons.auto_awesome_rounded,
      Icons.save_rounded,
    ];
    final count = _selectedPhotos.length;
    final atLimit = count >= _maxPhotos;

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
                    child: Text('Upload Photos',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  // FIX: photo counter in top-right corner of header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: atLimit
                          ? const Color(0xFFE07A5F).withOpacity(0.9)
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          atLimit
                              ? Icons.block_rounded
                              : Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$count/$_maxPhotos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: List.generate(steps.length * 2 - 1, (i) {
                  if (i.isOdd) {
                    final stepIdx = i ~/ 2;
                    final passed = _currentStep > stepIdx;
                    return Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: passed
                            ? Colors.white.withOpacity(0.7)
                            : Colors.white.withOpacity(0.2),
                      ),
                    );
                  }
                  final stepIdx = i ~/ 2;
                  final isActive = _currentStep == stepIdx;
                  final isPassed = _currentStep > stepIdx;
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isActive || isPassed
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icons[stepIdx],
                          color: isActive || isPassed
                              ? AppColors.headerCard
                              : Colors.white70,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[stepIdx],
                        style: TextStyle(
                          color: isActive || isPassed
                              ? Colors.white
                              : Colors.white60,
                          fontSize: 9,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    final remaining = _maxPhotos - _selectedPhotos.length;
    final atLimit = remaining <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: atLimit ? null : _showPickOptions,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: atLimit ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: atLimit
                  ? Colors.grey.shade300
                  : const Color(0xFF89B0AE).withOpacity(0.5),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: atLimit
                      ? Colors.grey.withOpacity(0.1)
                      : const Color(0xFF89B0AE).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  atLimit
                      ? Icons.block_rounded
                      : Icons.add_photo_alternate_rounded,
                  color: atLimit
                      ? Colors.grey.shade400
                      : const Color(0xFF89B0AE),
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                atLimit
                    ? 'Session limit reached'
                    : 'Tap to select photos',
                style: TextStyle(
                    color: atLimit ? Colors.grey : AppColors.bodyText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                atLimit
                    ? 'Save & confirm these $_maxPhotos photos first'
                    : 'You can only upload 20 images per session -  $remaining of $_maxPhotos slots remaining this session /n',
                style: TextStyle(
                    color: atLimit ? Colors.grey.shade400 : Colors.grey,
                    fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (!atLimit) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _featurePill(Icons.photo_library_rounded, 'Gallery'),
                    const SizedBox(width: 8),
                    _featurePill(Icons.camera_alt_rounded, 'Camera'),
                    const SizedBox(width: 8),
                    _featurePill(Icons.auto_awesome_rounded, 'AI Sort'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF89B0AE).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF89B0AE).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF89B0AE), size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF89B0AE),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStrip() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _selectedPhotos.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedPhotos.length) {
            final atLimit = _selectedPhotos.length >= _maxPhotos;
            return GestureDetector(
              onTap: atLimit ? null : _showPickOptions,
              child: Container(
                width: 82,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      atLimit ? Icons.block_rounded : Icons.add_rounded,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      atLimit ? 'Full' : 'Add more',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          }

          final photo = _selectedPhotos[index];
          final isProcessing = photo['isProcessing'] as bool;

          return Stack(
            children: [
              Container(
                width: 82,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(photo['path'] as String),
                        fit: BoxFit.cover,
                      ),
                      if (isProcessing)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isProcessing)
                Positioned(
                  top: 4,
                  right: 14,
                  child: GestureDetector(
                    onTap: () => _removePhoto(index),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Color(0xFFE07A5F),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 11),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClassificationList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _selectedPhotos.asMap().entries.map((entry) {
          final index = entry.key;
          final photo = entry.value;
          final isExpanded = _expandedIndex == index;
          final isProcessing = photo['isProcessing'] as bool;
          final subject =
              photo['override'] as String? ?? photo['subject'] as String;
          final confidence = photo['confidence'] as double;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF89B0AE)
                    : const Color(0xFFEEEEEE),
                width: isExpanded ? 1.5 : 1,
              ),
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
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: isProcessing
                              ? Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF89B0AE),
                                      ),
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(photo['path'] as String),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isProcessing
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Scanning...',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.grey.shade200,
                                      color: const Color(0xFF89B0AE),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Photo ${index + 1}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: subject == 'Unclassified'
                                              ? const Color(0xFFE07A5F)
                                              : const Color(0xFF89B0AE),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          subject.isEmpty
                                              ? 'Classifying...'
                                              : subject,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (photo['override'] != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3CD),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text('Edited',
                                              style: TextStyle(
                                                  color: Color(0xFF856404),
                                                  fontSize: 9,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: confidence,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            color: confidence > 0.5
                                                ? const Color(0xFF27AE60)
                                                : confidence > 0.2
                                                    ? const Color(0xFFE07A5F)
                                                    : Colors.red,
                                            minHeight: 4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(confidence * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: confidence > 0.5
                                              ? const Color(0xFF27AE60)
                                              : const Color(0xFFE07A5F),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((photo['ocrText'] as String)
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'OCR: ${(photo['ocrText'] as String).substring(0, ((photo['ocrText'] as String).length).clamp(0, 60))}...',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      if (!isProcessing) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() =>
                              _expandedIndex = isExpanded ? null : index),
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? const Color(0xFF89B0AE).withOpacity(0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: isExpanded
                                    ? const Color(0xFF89B0AE)
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isExpanded && !isProcessing) ...[
                  Container(height: 1, color: const Color(0xFFEEEEEE)),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Override subject:',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allSubjects.map((s) {
                            final isSel =
                                (photo['override'] ?? photo['subject']) == s;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedPhotos[index]['override'] = s;
                                _expandedIndex = null;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFF89B0AE)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFF89B0AE)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        color: isSel
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                        fontSize: 12,
                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomActions() {
    final anyProcessing =
        _selectedPhotos.any((p) => p['isProcessing'] as bool);

    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_selectedPhotos.isEmpty ||
                      anyProcessing ||
                      _isSaving)
                  ? null
                  : _confirmAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.headerCard,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              child: _isSaving || anyProcessing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          anyProcessing ? 'Scanning...' : 'Saving...',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Confirm & Save',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}