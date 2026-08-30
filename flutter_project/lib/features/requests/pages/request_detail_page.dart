import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/request_status_banner.dart';
import '../widgets/request_info_card.dart';
import '../widgets/request_action_buttons.dart';

class RequestDetailPage extends StatefulWidget {
  final String requestId;
  final bool isClient;
  final bool isAdminView;

  const RequestDetailPage({
    super.key,
    required this.requestId,
    required this.isClient,
    this.isAdminView = false,
  });

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage>
    with WidgetsBindingObserver {
  final _uid = AuthService.currentUser?.id ?? '';

  StreamSubscription? _requestSub;
  final _amountCtrl = TextEditingController();

  Map<String, dynamic>? _requestData;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequest();
    _requestSub = SocketService.onChatUpdated.listen((data) {
      final updatedId = data['requestId'] ?? data['_id'];
      if (updatedId == widget.requestId) {
        _loadRequest();
      }
    });
      final updatedId = data['requestId'] ?? data['_id'];
      if (updatedId == widget.requestId) {
        _loadRequest();
      }
    });
    // ✅ الاستماع إلى تحديثات الطلب عبر Socket.IO بدلاً من Polling
      }
    });
    // Poll for updates every 10 seconds
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRequest();
      final updatedId = data['requestId'] ?? data['_id'];
      if (updatedId == widget.requestId) {
        _loadRequest();
      }
    });
    // ✅ الاستماع إلى تحديثات الطلب عبر Socket.IO بدلاً من Polling
      }
    });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountCtrl.dispose();
    _requestSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    try {
      final data = await FirestoreService.getRequest(widget.requestId);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _requestData = data;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'الطلب غير موجود';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'خطأ في تحميل التفاصيل';
        });
      }
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: const Color(0xFF0071E3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: Stack(
        children: [
          // صورة الخلفية
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
          // طبقة داكنة شفافة
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          // تأثير زجاجي خفيف
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
          // المحتوى
          Column(
            children: [
              // ✅ شريط علوي بألوان علم الكويت واضح تماماً
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
                          'تفاصيل الطلب',
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
              // جسم الصفحة
              Expanded(
                child: _buildBody(isDesktop),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0071E3)),
      );
    }

    if (_error != null || _requestData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _error ?? 'الطلب غير موجود',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRequest,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0071E3),
              ),
            ),
          ],
        ),
      );
    }

    final d = _requestData!;
    final stat = d['status'] as String? ?? kStatusPending;
    final hasMap = widget.isClient &&
        stat == kStatusInProgress &&
        d['craftsmanLatitude'] != null &&
        d['craftsmanLongitude'] != null;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                RequestStatusBanner(status: stat),
                const SizedBox(height: 16),
                RequestInfoCard(data: d, isClient: widget.isClient),
                const SizedBox(height: 16),
                if (stat == 'payment_pending' || d['paymentStatus'] == 'link_sent')
                  _paymentPendingBanner(),
                RequestActionButtons(
                  data: d,
                  status: stat,
                  requestId: widget.requestId,
                  isClient: widget.isClient,
                  uid: _uid,
                  amountCtrl: _amountCtrl,
                  showSnack: _snack,
                  onStateChanged: _loadRequest,
                  context: context,
                  isAdminView: widget.isAdminView,
                ),
              ]),
            ),
          ),
          if (hasMap)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
                child: _buildCraftsmanMap(d),
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        RequestStatusBanner(status: stat),
        const SizedBox(height: 16),
        RequestInfoCard(data: d, isClient: widget.isClient),
        const SizedBox(height: 16),
        if (hasMap) _buildCraftsmanMap(d),
        if (stat == 'payment_pending' || d['paymentStatus'] == 'link_sent')
          _paymentPendingBanner(),
        RequestActionButtons(
          data: d,
          status: stat,
          requestId: widget.requestId,
          isClient: widget.isClient,
          uid: _uid,
          amountCtrl: _amountCtrl,
          showSnack: _snack,
          onStateChanged: _loadRequest,
          context: context,
          isAdminView: widget.isAdminView,
        ),
      ]),
    );
  }

  Widget _buildCraftsmanMap(Map<String, dynamic> d) {
    final lat = (d['craftsmanLatitude'] as num).toDouble();
    final lng = (d['craftsmanLongitude'] as num).toDouble();
    final name = (d['assignedCraftsmanName'] as String?) ?? 'الحرفي';

    final marker = Marker(
      markerId: const MarkerId('craftsman'),
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: name),
    );

    return Container(
      height: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15,
          ),
          markers: {marker},
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }

  Widget _paymentPendingBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_top, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بانتظار تأكيد الدفع',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'بعد إتمام الدفع في بوابة ماي فاتورة، سيتم التحقق تلقائياً. يمكنك أيضاً الضغط على زر التحقق أدناه.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadRequest,
                  icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF0071E3)),
                  label: const Text('تحقق من الدفع الآن',
                      style: TextStyle(color: Color(0xFF0071E3))),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0071E3),
                    side: const BorderSide(color: Color(0xFF0071E3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
