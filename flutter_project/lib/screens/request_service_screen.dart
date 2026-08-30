import 'package:flutter/material.dart';
import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:sana3i_kuwait/core/services/firestore_service.dart';

class RequestServiceScreen extends StatefulWidget {
  const RequestServiceScreen({super.key});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();
  
  String? selectedService;
  bool isLoading = false;

  final List<String> services = [
    'سباكة',
    'كهرباء',
    'نجارة',
    'تكييف وتبريد',
    'نقاشة',
    'سيراميك',
    'حدادة',
    'أخرى',
  ];

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختار نوع الخدمة')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirestoreService.createGuestRequest({
        'name': nameController.text,
        'phone': phoneController.text,
        'service': selectedService,
        'details': detailsController.text,
        'status': 'جديد',
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلبك بنجاح ✅')),
        );
        nameController.clear();
        phoneController.clear();
        detailsController.clear();
        setState(() => selectedService = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب خدمة'),
        backgroundColor: Colors.blue[700],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'اكتب اسمك' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم التليفون',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'اكتب رقم التليفون' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                initialValue: selectedService,
                decoration: InputDecoration(
                  labelText: 'نوع الخدمة',
                  prefixIcon: const Icon(Icons.build),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: services.map((service) {
                  return DropdownMenuItem(
                    value: service,
                    child: Text(service),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedService = value);
                },
                validator: (value) =>
                    value == null ? 'اختار نوع الخدمة' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: detailsController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'تفاصيل المشكلة',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'اكتب تفاصيل المشكلة' : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'إرسال الطلب',
                          style: TextStyle(fontSize: 18, color: Colors.white),
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
