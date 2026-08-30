import 'package:flutter/material.dart';
import 'package:sana3i_kuwait/core/services/auth_service.dart';
import 'select_city_screen.dart';
import 'login_screen.dart';
import 'admin/admin_dashboard.dart';

// تعريف أنواع الخدمات
enum ServiceType { worker, company, office, store }

// موديل الخدمة
class Service {
  String name;
  IconData icon;
  ServiceType type;
  String description;
  
  Service({ 
    required this.name, 
    required this.icon, 
    required this.type, 
    required this.description 
  });
}

// قائمة الخدمات
List<Service> services = [
  // عمال
  Service(name: 'سباك', icon: Icons.plumbing, type: ServiceType.worker, description: 'أعمال السباكة والصرف الصحي'),
  Service(name: 'كهربائي', icon: Icons.electric_bolt, type: ServiceType.worker, description: 'تركيب وصيانة الكهرباء'),
  Service(name: 'نجار', icon: Icons.handyman, type: ServiceType.worker, description: 'أعمال النجارة والأثاث'),
  Service(name: 'بناء', icon: Icons.construction, type: ServiceType.worker, description: 'أعمال البناء والمحارة'),
  
  // شركات
  Service(name: 'شركات تشطيب', icon: Icons.home_repair_service, type: ServiceType.company, description: 'تشطيبات كاملة للشقق والفيلل'),
  
  // مكاتب
  Service(name: 'مكاتب إشراف', icon: Icons.engineering, type: ServiceType.office, description: 'إشراف هندسي على المشاريع'),
  
  // محلات
  Service(name: 'محلات السباكة', icon: Icons.store, type: ServiceType.store, description: 'مواسير، خلاطات، أدوات صحية'),
  Service(name: 'محلات الكهرباء', icon: Icons.lightbulb, type: ServiceType.store, description: 'أسلاك، لمبات، مفاتيح'),
  Service(name: 'محلات مواد البناء', icon: Icons.foundation, type: ServiceType.store, description: 'أسمنت، رمل، طوب'),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.build_circle, size: 32),
            SizedBox(width: 8),
            Text('Sana3i', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('تسجيل دخول', style: TextStyle(color: Colors.white)),
          ),
          IconButton(icon: const Icon(Icons.person), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section زي المواقع
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.blue[50],
              child: const Column(
                children: [
                  Text(
                    'كل خدمات البناء والتشطيب في مكان واحد',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text('صنايعية، شركات، مكاتب، محلات', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            
            // قسم العمال
            _buildSectionTitle('الصنايعية'),
            _buildServiceGrid(ServiceType.worker),
            
            // قسم الشركات
            _buildSectionTitle('شركات التشطيب'),
            _buildServiceGrid(ServiceType.company),
            
            // قسم المكاتب
            _buildSectionTitle('مكاتب الإشراف'),
            _buildServiceGrid(ServiceType.office),
            
            // قسم المحلات
            _buildSectionTitle('محلات مواد البناء'),
            _buildServiceGrid(ServiceType.store),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildServiceGrid(ServiceType type) {
    var filteredServices = services.where((s) => s.type == type).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredServices.length,
      itemBuilder: (context, index) {
        return _ServiceCard(service: filteredServices[index]);
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleServiceTap(context),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(service.icon, size: 40, color: Colors.blue[700]),
              const SizedBox(height: 8),
              Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                service.description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleServiceTap(BuildContext context) async {
    Sana3iUser? user = AuthService.currentUser;
    
    if (user == null) {
      // مش مسجل
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تسجيل الدخول مطلوب'),
          content: Text('يجب تسجيل الدخول أولاً لاستخدام خدمة ${service.name}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const Text('تسجيل دخول'),
            ),
          ],
        ),
      );
    } else {
      // مسجل → ادمن ولا لا؟
      bool isAdmin = user.role == 'admin';
      
      if (isAdmin) {
        // لو ادمن → روح لوحة التحكم
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
      } else {
        // لو مستخدم عادي → روح لصفحة اختيار المحافظة
        Navigator.push(context, MaterialPageRoute(builder: (_) => SelectCityScreen(service: service)));
      }
    }
  }
}
