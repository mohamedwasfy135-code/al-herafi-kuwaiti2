import 'package:geolocator/geolocator.dart';

/// أدوات الموقع الجغرافي
/// يستخدم geolocator.distanceBetween() الدقيقة بدلاً من حساب Haversine يدوياً
class LocationUtils {
  LocationUtils._();

  /// احسب المسافة بالكيلومترات بين نقطتين
  /// يستخدم Vincenty formula عبر geolocator — أدق بكثير من Haversine المبسّطة
  static double distanceKm(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1000.0;
  }

  /// اطلب صلاحية الموقع وأرجع الموضع الحالي
  /// يرجع null إذا رُفض الإذن أو الخدمة معطّلة
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  /// حوّل موضع إلى Map مناسب لـ Firestore
  static Map<String, double>? positionToMap(Position? pos) {
    if (pos == null) return null;
    return {'latitude': pos.latitude, 'longitude': pos.longitude};
  }

  /// حساب ETA تقديري بناءً على المسافة
  /// متوسط سرعة 30 كم/ساعة داخل الكويت
  static String estimateETA(double distKm) {
    final minutes = ((distKm / 30.0) * 60).round();
    if (minutes < 5)  return 'أقل من ٥ دقائق 🚀';
    if (minutes < 60) return 'حوالي $minutes دقيقة 🚗';
    final hours = minutes ~/ 60;
    final mins  = minutes % 60;
    return 'حوالي $hours ساعة${mins > 0 ? ' و$mins دقيقة' : ''} 🚗';
  }
}
