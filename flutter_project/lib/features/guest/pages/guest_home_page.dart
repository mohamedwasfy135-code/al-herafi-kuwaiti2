import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/services_data.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/pages/auth_page.dart';

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});
  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  String? _selService, _selGov, _selCity;
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  bool  _submitting  = false;
  List<String> _cities = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitGuestRequest() async {
    if (_nameCtrl.text.trim().isEmpty)   { _snack('write_your_name'.tr()); return; }
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 8) { _snack('invalid_phone'.tr()); return; }
    if (_selService == null)  { _snack('choose_service'.tr()); return; }
    if (_selGov     == null)  { _snack('choose_area'.tr()); return; }

    setState(() => _submitting = true);
    try {
      await FirestoreService.createGuestRequest({
        'guestName':    _nameCtrl.text.trim(),
        'guestPhone':   _phoneCtrl.text.trim(),
        'service':      _selService,
        'governorate':  _selGov,
        'city':         _selCity ?? '',
        'address':      _addressCtrl.text.trim(),
        'notes':        _notesCtrl.text.trim(),
        'status':       'pending',
        'createdAt':    DateTime.now().toIso8601String(),
      });
      if (mounted) {
        _showSuccessDialog();
        setState(() {
          _selService = null; _selGov = null; _selCity = null; _cities = [];
          _nameCtrl.clear(); _phoneCtrl.clear();
          _addressCtrl.clear(); _notesCtrl.clear();
        });
      }
    } catch (e) {
      _snack('❌ ${'error_label'.tr()}: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text('request_received'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('will_call_soon'.tr(),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AuthPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('register_account'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app_name'.tr()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // ✅ زر تغيير اللغة
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'language'.tr(),
            onPressed: () {
              final newLocale = context.locale == const Locale('ar')
                  ? const Locale('en')
                  : const Locale('ar');
              context.setLocale(newLocale);
            },
          ),
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AuthPage())),
            child: Text('login_register'.tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Welcome banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.handyman, color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('request_without_account'.tr(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('just_phone_message'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // بيانات الزائر
          Text('your_data'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              controller: _nameCtrl,
              decoration: _dec('name_label'.tr(), Icons.person),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _dec('phone_label'.tr(), Icons.phone),
            )),
          ]),
          const SizedBox(height: 16),

          // الخدمة
          Text('required_service'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.85),
            itemCount: kServices.where((s) => s.type == ServiceType.worker).length,
            itemBuilder: (_, i) {
              final s   = kServices.where((s) => s.type == ServiceType.worker).toList()[i];
              final sel = _selService == s.name;
              return GestureDetector(
                onTap: () => setState(() => _selService = s.name),
                child: Container(
                  decoration: BoxDecoration(
                    color: sel ? Colors.blue : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? Colors.blue : Colors.grey.shade300),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(s.icon, color: sel ? Colors.white : Colors.blue, size: 28),
                    const SizedBox(height: 4),
                    Text(s.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11,
                          color: sel ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // المنطقة
          Text('area_label'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _selGov,
              decoration: _dec('governorate_label'.tr(), Icons.location_city),
              items: kGovernorates.map((g) =>
                  DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (g) => setState(() {
                _selGov = g; _selCity = null;
                _cities = kCitiesByGovernorate[g] ?? [];
              }),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _selCity,
              decoration: _dec('city_label'.tr(), Icons.location_on),
              items: _cities.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (c) => setState(() => _selCity = c),
            )),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _addressCtrl, decoration: _dec('address_label'.tr(), Icons.home)),
          const SizedBox(height: 10),
          TextField(controller: _notesCtrl, maxLines: 2,
              decoration: _dec('notes_label'.tr(), Icons.notes)),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 36,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitGuestRequest,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'sending'.tr() : 'send_request_now'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AuthPage())),
            child: Text('already_have_account'.tr(),
                style: const TextStyle(color: Colors.blue)),
          )),
        ]),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    prefixIcon: Icon(icon),
  );
}
