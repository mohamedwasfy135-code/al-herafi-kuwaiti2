import 'package:flutter/material.dart';
import 'package:sana3i_kuwait/core/services/auth_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    _DashboardHome(),
    _UsersPage(),
    _OrdersPage(),
    _ServicesPage(),
    _SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(24),
                  child: const Row(
                    children: [
                      Icon(Icons.build_circle, color: Colors.blue, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Sana3i Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[700], height: 1),

                // Menu Items
                _buildMenuItem(0, Icons.dashboard, 'الرئيسية'),
                _buildMenuItem(1, Icons.people, 'المستخدمين'),
                _buildMenuItem(2, Icons.assignment, 'الطلبات'),
                _buildMenuItem(3, Icons.miscellaneous_services, 'الخدمات'),
                _buildMenuItem(4, Icons.settings, 'الإعدادات'),

                const Spacer(),
                Divider(color: Colors.grey[700], height: 1),
                _buildMenuItem(-1, Icons.logout, 'تسجيل خروج'),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getPageTitle(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.person, color: Colors.blue[700]),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            AuthService.currentUser?.email ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Page Content
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        if (index == -1) {
          AuthService.signOut();
          Navigator.pop(context);
        } else {
          setState(() => _selectedIndex = index);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected? Colors.white : Colors.grey[400], size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected? Colors.white : Colors.grey[400],
                fontWeight: isSelected? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'لوحة التحكم الرئيسية';
      case 1: return 'إدارة المستخدمين';
      case 2: return 'إدارة الطلبات';
      case 3: return 'إدارة الخدمات';
      case 4: return 'الإعدادات';
      default: return '';
    }
  }
}

// صفحة الرئيسية
class _DashboardHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('إجمالي المستخدمين', '1,245', '+12%', Icons.people, Colors.blue),
                _buildStatCard('الطلبات الجديدة', '89', '+8%', Icons.assignment, Colors.green),
                _buildStatCard('الصنايعية النشطين', '234', '+5%', Icons.handyman, Colors.orange),
                _buildStatCard('الإيرادات', '45,890 ج.م', '+23%', Icons.attach_money, Colors.purple),
              ],
            ),

            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Orders
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('أحدث الطلبات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildOrderRow('أحمد محمد', 'سباكة', 'قيد التنفيذ', Colors.orange),
                        _buildOrderRow('سارة علي', 'كهرباء', 'مكتمل', Colors.green),
                        _buildOrderRow('محمد حسن', 'نجارة', 'ملغي', Colors.red),
                        _buildOrderRow('فاطمة أحمد', 'دهان', 'قيد التنفيذ', Colors.orange),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Top Services
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('أكثر الخدمات طلباً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildServiceProgress('سباكة', 0.85, Colors.blue),
                        _buildServiceProgress('كهرباء', 0.72, Colors.green),
                        _buildServiceProgress('نجارة', 0.58, Colors.orange),
                        _buildServiceProgress('دهان', 0.43, Colors.purple),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String change, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(change, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildOrderRow(String name, String service, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: Colors.grey[200], child: Text(name[0])),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(service, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceProgress(String name, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('صفحة المستخدمين - قريباً'));
}

class _OrdersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('صفحة الطلبات - قريباً'));
}

class _ServicesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('صفحة الخدمات - قريباً'));
}

class _SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('صفحة الإعدادات - قريباً'));
}