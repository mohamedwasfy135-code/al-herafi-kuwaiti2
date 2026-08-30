import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/pages/auth_page.dart';

enum UploadStatus { idle, uploading, done, error }

class DocumentUploadPage extends StatefulWidget {
  const DocumentUploadPage({super.key});

  @override
  State<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  final _uid = AuthService.currentUser?.id ?? '';
  final _picker = ImagePicker();

  XFile? _civilIdFile, _profileImageFile;
  PlatformFile? _licenseFile;
  UploadStatus _civilIdStatus = UploadStatus.idle;
  UploadStatus _profileStatus = UploadStatus.idle;
  UploadStatus _licenseStatus = UploadStatus.idle;
  String? _civilIdUrl, _profileUrl, _licenseUrl;

  bool _submitting = false;
  String? _error;
  bool _submitted = false;   // ✅ شاشة النجاح بعد الإرسال

  String _role = kRoleClient;
  bool _isBusiness = false;
  bool _isCraftsman = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final data = await FirestoreService.getUser(_uid);
    if (data != null) {
      setState(() {
        _role = data['role'] ?? kRoleClient;
        _isBusiness = (_role == kRoleBusiness);
        _isCraftsman = (_role == kRoleCraftsman);
      });
    }
  }

  // ========== دوال الرفع ==========
  Future<void> _pickAndUploadCivilId() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() { _civilIdFile = file; _civilIdStatus = UploadStatus.uploading; _error = null; });
      final url = await _uploadImageFile(file, '${kStoragePathCivilIds}/$_uid.jpg');
      setState(() {
        _civilIdStatus = url != null ? UploadStatus.done : UploadStatus.error;
        _civilIdUrl = url;
        if (url == null) _error = 'فشل رفع البطاقة المدنية';
      });
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() { _profileImageFile = file; _profileStatus = UploadStatus.uploading; _error = null; });
      final url = await _uploadImageFile(file, 'profiles/$_uid.jpg');
      setState(() {
        _profileStatus = url != null ? UploadStatus.done : UploadStatus.error;
        _profileUrl = url;
        if (url == null) _error = 'فشل رفع الصورة الشخصية';
      });
    }
  }

  Future<void> _pickAndUploadLicense() async {
    final type = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('نوع ملف الرخصة'),
        content: const Text('اختر صورة أو PDF'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'image'), child: const Text('صورة')),
          TextButton(onPressed: () => Navigator.pop(context, 'pdf'), child: const Text('PDF')),
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('إلغاء')),
        ],
      ),
    );
    if (type == null || type == 'cancel') return;

    if (type == 'image') {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file != null) {
        setState(() { _licenseFile = null; _licenseStatus = UploadStatus.uploading; _error = null; });
        final url = await _uploadImageFile(file, '${kStoragePathLicenses}/$_uid.jpg');
        setState(() {
          _licenseStatus = url != null ? UploadStatus.done : UploadStatus.error;
          _licenseUrl = url;
          if (url == null) _error = 'فشل رفع الرخصة';
        });
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;
        setState(() { _licenseFile = platformFile; _licenseStatus = UploadStatus.uploading; _error = null; });
        final url = await _uploadBytes(
          bytes: platformFile.bytes!,
          path: '${kStoragePathLicenses}/$_uid.pdf',
          contentType: 'application/pdf',
        );
        setState(() {
          _licenseStatus = url != null ? UploadStatus.done : UploadStatus.error;
          _licenseUrl = url;
          if (url == null) _error = 'فشل رفع الرخصة';
        });
      }
    }
  }

  Future<String?> _uploadImageFile(XFile file, String path) async {
    return _uploadFileViaApi(filePath: file.path, path: path, contentType: 'image/jpeg');
  }

  Future<String?> _uploadBytes({
    required List<int> bytes,
    required String path,
    String contentType = 'application/octet-stream',
  }) async {
    // For byte uploads, we write to a temp file and upload via API
    // This is a simplification; in production you might use a different approach
    try {
      final res = await ApiService.uploadFile(
        '/api/upload',
        filePath: path, // Note: bytes uploads need temp file handling
        fieldName: 'file',
        fields: {
          'userId': _uid,
          'contentType': contentType,
          'storagePath': path,
        },
      );
      if (res.success && res.data != null) {
        return res.data!['url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<String?> _uploadFileViaApi({
    required String filePath,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final res = await ApiService.uploadFile(
        '/api/upload',
        filePath: filePath,
        fieldName: 'file',
        fields: {
          'userId': _uid,
          'contentType': contentType,
          'storagePath': path,
        },
      );
      if (res.success && res.data != null) {
        return res.data!['url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // ✅ تم تصحيح شرط التحقق – يعتمد على وجود روابط الملفات فعلياً
  bool get _allRequiredUploaded {
    // عميل عادي لا يحتاج وثائق
    if (!_isBusiness && !_isCraftsman && _role == kRoleClient) return true;
    // إذا لم يتم تحميل الدور بعد، لا نسمح
    if (!_isBusiness && !_isCraftsman) return false;
    if (_isBusiness) {
      return _civilIdUrl != null && _civilIdUrl!.isNotEmpty &&
             _licenseUrl != null && _licenseUrl!.isNotEmpty;
    }
    if (_isCraftsman) {
      return _civilIdUrl != null && _civilIdUrl!.isNotEmpty &&
             _profileUrl != null && _profileUrl!.isNotEmpty;
    }
    return false;
  }

  Future<void> _submitForReview() async {
    // تحقق أولي من وجود الملفات المرفوعة فعلياً
    final hasCivilId = _civilIdUrl != null && _civilIdUrl!.isNotEmpty;
    final hasLicense = _licenseUrl != null && _licenseUrl!.isNotEmpty;
    final hasProfile = _profileUrl != null && _profileUrl!.isNotEmpty;

    if ((_isBusiness && (!hasCivilId || !hasLicense)) ||
        (_isCraftsman && (!hasCivilId || !hasProfile)) ||
        (!_isBusiness && !_isCraftsman && _role != kRoleClient)) {
      setState(() => _error = 'يرجى رفع جميع الوثائق المطلوبة');
      return;
    }

    if (!_allRequiredUploaded) {
      setState(() => _error = 'يرجى رفع جميع الوثائق المطلوبة');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final updateData = <String, dynamic>{
        'documentsUploaded': true,
        'verificationStatus': 'submitted',
        'civilIdImage': _civilIdUrl,
        if (_profileUrl != null) 'profileImage': _profileUrl,
        if (_licenseUrl != null) 'licenseImage': _licenseUrl,
      };
      await FirestoreService.updateUser(_uid, updateData);
      if (_isCraftsman) {
        await ApiService.put('/api/craftsmen/$_uid', body: updateData);
      } else if (_isBusiness) {
        await FirestoreService.updateBusiness(_uid, updateData);
      }

      // ✅ إشعار للفني بأن وثائقه قيد المراجعة
      try {
        await NotificationService.sendNotification(
          toUid: _uid,
          title: '📋 وثائقك قيد المراجعة',
          body: 'تم استلام وثائقك بنجاح. سنقوم بمراجعتها في أقرب وقت.',
          data: {'type': 'documents_submitted'},
        );
      } catch (_) {}

      // ✅ عرض شاشة التأكيد
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = 'فشل حفظ البيانات: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logout() async {
    await AuthPage.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/ocean_bg.jpg', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
          Column(children: [
            // شريط علوي
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF007A3D), Color(0xFFFFFFFF), Color(0xFFCE1126), Color(0xFF000000)],
                  stops: [0.0, 0.35, 0.75, 1.0],
                ),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('رفع الوثائق',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ),
            // المحتوى
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _submitted ? _buildSuccessView() : _buildUploadForm(),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildUploadForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('يجب رفع الوثائق التالية لإكمال التسجيل',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 13)),
      const SizedBox(height: 24),
      _buildUploadTile('البطاقة المدنية', Icons.credit_card, _civilIdStatus, _pickAndUploadCivilId),
      if (_isCraftsman)
        _buildUploadTile('الصورة الشخصية', Icons.person, _profileStatus, _pickAndUploadProfileImage),
      if (_isBusiness)
        _buildUploadTile('الرخصة التجارية', Icons.badge, _licenseStatus, _pickAndUploadLicense),
      const SizedBox(height: 32),
      if (_error != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _submitting ? null : _submitForReview,
        icon: _submitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.cloud_upload),
        label: Text(_submitting ? 'جاري الإرسال...' : 'إرسال للمراجعة'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0071E3),
          foregroundColor: const Color(0xFF1D1D1F),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: Colors.grey.shade400,
        ),
      ),
    ]);
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 100, color: Colors.greenAccent),
        const SizedBox(height: 24),
        const Text(
          'تم إرسال الوثائق للمراجعة بنجاح',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'سنقوم بمراجعة مستنداتك في أقرب وقت. سيتم إعلامك عند اكتمال المراجعة.',
          style: TextStyle(fontSize: 14, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTile(String label, IconData icon, UploadStatus status, VoidCallback onTap) {
    Widget trailing;
    switch (status) {
      case UploadStatus.uploading:
        trailing = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
        break;
      case UploadStatus.done:
        trailing = const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24);
        break;
      case UploadStatus.error:
        trailing = const Icon(Icons.error, color: Colors.redAccent, size: 24);
        break;
      default:
        trailing = const Icon(Icons.cloud_upload_outlined, color: Colors.white70, size: 24);
    }
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 28),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}