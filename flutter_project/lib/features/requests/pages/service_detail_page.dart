import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/services_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auto_assign_service.dart';
import '../../../core/services/ai_pricing_service.dart';
import '../../../core/services/ai_request_intake_service.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/pages/auth_page.dart';
import '../../shared/ai/ai_assistant_page.dart';

class ServiceDetailPage extends StatefulWidget {
  final ServiceModel service;
  const ServiceDetailPage({super.key, required this.service});
  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  String? _uid;
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selGov, _selCity;
  List<String> _cities = [];
  bool _submitting = false;
  bool _isBusiness = false;
  bool _loadingPrice = false;
  PricingResult? _pricing;

  RequestIntakeResult? _aiIntake;
  bool _analyzingIntake = false;

  List<Map<String, dynamic>> _providers = [];
  bool _loadingProviders = true;

  static const String _allRegions = 'كل المناطق';

  @override
  void initState() {
    super.initState();
    _isBusiness = widget.service.type != ServiceType.worker;
    _uid = AuthService.currentUser?.id;

    // ✅ طرد الزائر فوراً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.currentUser == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthPage()),
          (route) => false,
        );
        return;
      }
      // لو كان مسجلاً وبيزنس نحمل المزودين
      if (_isBusiness) _loadProviders();
    });
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() => _loadingProviders = true);
    final products = await FirestoreService.getProducts();
    if (mounted) {
      setState(() {
        _providers = products;
        _loadingProviders = false;
      });
    }
  }

  Future<void> _fetchAiPricing() async {
    if (_selGov == null || _notesCtrl.text.trim().isEmpty) return;
    setState(() {
      _loadingPrice = true;
      _pricing = null;
    });
    final result = await AiPricingService.getPricing(
      service: widget.service.name,
      governorate: _selGov!,
      problemDescription: _notesCtrl.text.trim(),
    );
    if (mounted) setState(() {
      _pricing = result;
      _loadingPrice = false;
    });
  }

  void _openAiAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, __) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Expanded(child: AiAssistantPage()),
          ]),
        ),
      ),
    ).then((result) {
      if (result is String && result.isNotEmpty) {
        _notesCtrl.text = result;
        _fetchAiPricing();
      }
    });
  }

  Future<void> _runAiIntake() async {
    final desc = _notesCtrl.text.trim();
    if (desc.split(RegExp(r'\s+')).length < 3) {
      setState(() => _aiIntake = null);
      return;
    }

    setState(() => _analyzingIntake = true);
    final result = await AiRequestIntakeService.analyze(
      description: desc,
      userSelectedService: widget.service.name,
    );
    if (mounted) {
      setState(() {
        _aiIntake = result;
        _analyzingIntake = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_uid == null) {
      _snack('يجب تسجيل الدخول أولاً');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      return;
    }

    if (_selGov != _allRegions && _selGov == null) {
      _snack('📍 اختر المحافظة');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty && _selGov != _allRegions) {
      _snack('🏠 اكتب العنوان');
      return;
    }

    if (_notesCtrl.text.trim().isNotEmpty && _aiIntake == null) {
      _snack('🔍 جارٍ تحليل المشكلة بالذكاء الاصطناعي… سيُرسل طلبك على أية حال.');
    }

    setState(() => _submitting = true);

    try {
      final userData = await FirestoreService.getUser(_uid!) ?? {};
      final clientName = userData['name'] as String? ?? 'عميل';
      final clientPhone = userData['phone'] as String? ?? '';

      Position? pos;
      try {
        pos = await LocationUtils.getCurrentPosition();
      } catch (_) {}

      final effectiveGovernorate = _selGov ?? _allRegions;

      debugPrint('=== SUBMIT REQUEST ===');
      debugPrint('service  : "${widget.service.name}"');
      debugPrint('governorate: "$effectiveGovernorate"');

      final requestData = <String, dynamic>{
        'clientId': _uid,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientGovernorate': effectiveGovernorate,
        'clientCity': _selCity ?? '',
        'service': widget.service.name,
        'address': _addressCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'status': kStatusPending,
        'createdAt': DateTime.now().toIso8601String(),
        if (_pricing != null) ...{
          'aiPricingMin': _pricing!.minPrice,
          'aiPricingMax': _pricing!.maxPrice,
          'aiPricingRec': _pricing!.recommended,
          'aiUrgency': _pricing!.urgencyLevel,
        },
        if (pos != null) ...{
          'clientLatitude': pos.latitude,
          'clientLongitude': pos.longitude,
        },
      };

      final result = await FirestoreService.createRequest(requestData);
      final requestId = result?['id'] as String? ?? result?['requestId'] as String? ?? '';

      debugPrint('✅ Request created: $requestId');

      await AutoAssignService.assignRequest(
        requestId: requestId,
        service: widget.service.name,
        governorate: effectiveGovernorate,
        clientLat: pos?.latitude,
        clientLng: pos?.longitude,
        clientName: clientName,
        clientPhone: clientPhone,
        clientId: _uid!,
      );

      debugPrint('✅ assignRequest completed for $requestId');

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e, st) {
      debugPrint('❌ _submitRequest error: $e\n$st');
      _snack('❌ خطأ: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('تم إرسال طلبك!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'طلبك قيد المعالجة…\nسيقوم النظام الذكي بإسناده لأفضل حرفي متاح، وستظهر لك التفاصيل فوراً في قسم "طلباتي".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0071E3),
                foregroundColor: const Color(0xFF1D1D1F),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ocean_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
          // المحتوى مع شريط علم الكويت
          Column(
            children: [
              // شريط علوي بألوان علم الكويت
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF007A3D), // أخضر
                      Color(0xFFFFFFFF), // أبيض
                      Color(0xFFCE1126), // أحمر
                      Color(0xFF000000), // أسود
                    ],
                    stops: [0.0, 0.35, 0.75, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          '${widget.service.name} - طلب خدمة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // باقي المحتوى
              Expanded(
                child: _isBusiness ? _buildBusinessView() : _buildWorkerForm(isDesktop),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerForm(bool isDesktop) {
    final formColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _serviceBanner(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openAiAssistant,
          icon: const Icon(Icons.auto_awesome, color: Color(0xFF0071E3)),
          label: const Text('اسأل الذكاء الاصطناعي عن مشكلتك',
              style: TextStyle(color: Color(0xFF0071E3))),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            side: const BorderSide(color: Color(0xFF0071E3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('📍 المنطقة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _glassDropdown(
            value: _selGov,
            hint: 'المحافظة',
            items: [_allRegions, ...kGovernorates],
            onChanged: (g) {
              setState(() {
                _selGov = g;
                _selCity = null;
                _cities = g == _allRegions ? [] : (kCitiesByGovernorate[g] ?? []);
                _pricing = null;
              });
              if (_notesCtrl.text.trim().isNotEmpty && g != _allRegions) _fetchAiPricing();
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: _glassDropdown(
            value: _selCity,
            hint: 'الفرعية',
            items: _cities,
            onChanged: (c) => setState(() => _selCity = c),
          )),
        ]),
        const SizedBox(height: 12),
        _glassField(_addressCtrl, 'العنوان التفصيلي', Icons.home),
        const SizedBox(height: 20),
        Row(children: [
          const Text('📝 وصف المشكلة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          TextButton.icon(
            onPressed: _openAiAssistant,
            icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0071E3)),
            label: const Text('AI', style: TextStyle(color: Color(0xFF0071E3), fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        _glassField(_notesCtrl, 'صف المشكلة بالتفصيل للحصول على تسعير دقيق...', Icons.notes, maxLines: 3, onChanged: (_) {
          setState(() => _pricing = null);
          _runAiIntake();
        }),
        if (_analyzingIntake)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0071E3))),
              SizedBox(width: 8),
              Text('جاري التحليل الذكي...', style: TextStyle(color: Colors.white70)),
            ]),
          ),
        if (_aiIntake != null) _buildAiIntakeCard(),
        const SizedBox(height: 12),
        if (_selGov != null && _selGov != _allRegions && _notesCtrl.text.trim().isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadingPrice ? null : _fetchAiPricing,
              icon: _loadingPrice
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0071E3)))
                  : const Icon(Icons.price_check, color: Color(0xFF0071E3)),
              label: Text(
                _loadingPrice ? 'جاري التسعير...' : 'احسب السعر بالذكاء الاصطناعي',
                style: const TextStyle(color: Color(0xFF0071E3)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0071E3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (_pricing != null) _pricingCard(),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submitRequest,
            icon: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF1D1D1F), strokeWidth: 2))
                : const Icon(Icons.send, color: Color(0xFF1D1D1F)),
            label: Text(
              _submitting ? 'جاري الإرسال...' : 'أرسل الطلب',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1D1D1F)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0071E3),
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: formColumn),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(
                  children: [
                    if (_pricing != null) _pricingCard(),
                    if (_aiIntake != null) _buildAiIntakeCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: formColumn,
    );
  }

  Widget _buildAiIntakeCard() {
    final intake = _aiIntake!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.auto_awesome, color: Color(0xFF0071E3), size: 20),
                SizedBox(width: 8),
                Text('تحليل المساعد الذكي',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0071E3))),
              ]),
              const SizedBox(height: 8),
              if (intake.serviceMismatch && intake.suggestedService.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('🔧 الخدمة المقترحة: ${intake.suggestedService}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              Text('⏱️ درجة الاستعجال: ${intake.urgency == 'urgent' ? 'عاجل' : intake.urgency == 'low' ? 'منخفض' : 'متوسط'}',
                  style: const TextStyle(color: Colors.white)),
              if (intake.notes != null && intake.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('📝 ملاحظات: ${intake.notes}',
                      style: const TextStyle(color: Colors.white70, height: 1.4)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessView() {
    if (_loadingProviders) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }
    if (_providers.isEmpty) {
      return const Center(child: Text('لا توجد منتجات/خدمات متاحة حالياً', style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _providers.length,
      itemBuilder: (_, i) {
        final d = _providers[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: ListTile(
                leading: const Icon(Icons.storefront, color: Color(0xFF0071E3)),
                title: Text(d['name'] as String? ?? '', style: const TextStyle(color: Colors.white)),
                subtitle: Text(d['description'] as String? ?? '', style: const TextStyle(color: Colors.white70)),
                trailing: Text(
                  '${(d['price'] as num?)?.toStringAsFixed(3) ?? '-'} د.ك',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0071E3)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pricingCard() {
    final p = _pricing!;
    final urgencyColors = {
      'low': Colors.green,
      'medium': Colors.orange,
      'high': Colors.deepOrange,
      'emergency': Colors.red,
    };
    final urgencyLabels = {
      'low': '🟢 منخفض',
      'medium': '🟡 متوسط',
      'high': '🟠 عالي',
      'emergency': '🔴 طارئ',
    };
    final color = urgencyColors[p.urgencyLevel] ?? Colors.blue;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.price_check, color: Color(0xFF0071E3), size: 20),
              SizedBox(width: 8),
              Text('التسعير الذكي',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0071E3), fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _priceBox('الحد الأدنى', '${p.minPrice.toStringAsFixed(3)} د.ك', Colors.blue),
              const SizedBox(width: 8),
              _priceBox('المقترح', '${p.recommended.toStringAsFixed(3)} د.ك', Colors.green, isMain: true),
              const SizedBox(width: 8),
              _priceBox('الحد الأقصى', '${p.maxPrice.toStringAsFixed(3)} د.ك', Colors.orange),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('مستوى الإلحاح: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  urgencyLabels[p.urgencyLevel] ?? '',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(p.reasoning, style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.white)),
            if (p.factors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: p.factors
                    .map((f) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(f, style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ))
                    .toList(),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _priceBox(String label, String value, Color color, {bool isMain = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(isMain ? .2 : .1),
            borderRadius: BorderRadius.circular(10),
            border: isMain ? Border.all(color: color.withOpacity(.5)) : null,
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: isMain ? 14 : 12, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _serviceBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(widget.service.icon, color: const Color(0xFF0071E3), size: 32),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.service.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(widget.service.description,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ]),
      );

  Widget _glassField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0071E3)),
        ),
      ),
    );
  }

  Widget _glassDropdown({String? value, required String hint, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          dropdownColor: const Color(0xFF003366),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
