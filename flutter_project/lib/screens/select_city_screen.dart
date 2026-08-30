import 'package:flutter/material.dart';
import 'home_screen.dart';

class SelectCityScreen extends StatefulWidget {
  final Service service;
  const SelectCityScreen({super.key, required this.service});
  @override
  State<SelectCityScreen> createState() => _SelectCityScreenState();
}

class _SelectCityScreenState extends State<SelectCityScreen> {
  String? selectedCity;
  List<String> cities = ['القاهرة', 'الجيزة', 'الإسكندرية', 'المنيا', 'ديروط', 'سمالوط'];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اختر المحافظة - ${widget.service.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'المحافظة / المدينة',
                border: OutlineInputBorder(),
              ),
              initialValue: selectedCity,
              items: cities.map((city) {
                return DropdownMenuItem(value: city, child: Text(city));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCity = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: selectedCity == null ? null : () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => WorkersListScreen(
                    service: widget.service,
                    city: selectedCity!,
                  ),
                ));
              },
              child: const Text('عرض الصنايعية'),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkersListScreen extends StatelessWidget {
  final Service service;
  final String city;
  const WorkersListScreen({super.key, required this.service, required this.city});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${service.name} في $city')),
      body: Center(child: Text('قائمة ${service.name} في $city')),
    );
  }
}
