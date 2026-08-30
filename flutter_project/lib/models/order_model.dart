enum ServiceType { electric, plumbing, carpentry, dish }
class OrderModel {
  final String id, customerName, customerPhone, address, problemDescription, serviceType, status;
  final double? latitude, longitude;
  final DateTime createdAt;
  final String? imageUrl;
  OrderModel({
    required this.id, required this.customerName, required this.customerPhone,
    required this.address, required this.problemDescription, required this.serviceType,
    this.status = 'pending', this.latitude, this.longitude, required this.createdAt, this.imageUrl,
  });
  Map<String, dynamic> toMap() => {
    'id': id, 'customerName': customerName, 'customerPhone': customerPhone,
    'address': address, 'problemDescription': problemDescription, 'serviceType': serviceType,
    'status': status, 'latitude': latitude, 'longitude': longitude,
    'createdAt': createdAt.millisecondsSinceEpoch, 'imageUrl': imageUrl,
  };
}
