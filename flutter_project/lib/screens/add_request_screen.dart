import 'package:flutter/material.dart';

class AddRequestScreen extends StatefulWidget {
  const AddRequestScreen({super.key});

  @override
  State<AddRequestScreen> createState() => _AddRequestScreenState();
}

class _AddRequestScreenState extends State<AddRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _jobType;
  final _detailsController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<String> jobTypes = [
    'سباك',
    'كهربائي', 
    'نجار',
    'نقاش',
    'حداد',
    'محارة',
    'سيراميك',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب صنايعي جديد'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'اختار نوع الصنايعي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _jobType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'مثلا: سباك',
                ),
                items: jobTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _jobType = value;
                  });
                },
                validator: (value) => value == null ? 'اختار نوع الصنايعي' : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'اشرح المشكلة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _detailsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'مثلا: حنفية المطبخ بتنقط',
                ),
                validator: (value) => value!.isEmpty ? 'اكتب تفاصيل المشكلة' : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'رقم موبايلك',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '01xxxxxxxxx',
                ),
                validator: (value) => value!.length < 11 ? 'رقم الموبايل غلط' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمام! هنوصل طلبك للصنايعية')),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('إرسال الطلب', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
