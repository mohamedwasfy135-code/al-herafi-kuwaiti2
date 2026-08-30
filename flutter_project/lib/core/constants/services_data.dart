import 'package:flutter/material.dart';

enum ServiceType { worker, business }

class ServiceModel {
  final String name;
  final String description;
  final IconData icon;
  final ServiceType type;

  const ServiceModel({
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
  });
}

// ── المحافظات الكويتية ─────────────────────────────────────
const List<String> kGovernorates = [
  'كل مناطق الكويت',
  'محافظة العاصمة',
  'محافظة حولي',
  'محافظة الفروانية',
  'محافظة الأحمدي',
  'محافظة الجهراء',
  'محافظة مبارك الكبير',
];

// ── المدن حسب المحافظة ─────────────────────────────────────
const Map<String, List<String>> kCitiesByGovernorate = {
  'كل مناطق الكويت': [
    'كل الكويت',
  ],
  'محافظة العاصمة': [
    'الشويخ','غرب الصليبيخات','الدسمة','الروضة','الصليبيخات',
    'الشامية','الصليبية','العديلية','القادسية','الفحيحيل',
    'نزهة','كيفان','المنصورية','الري','ميدان حولي',
  ],
  'محافظة حولي': [
    'السالمية','الرميثية','الجابرية','بيان','مشرف',
    'حطين','البدع','شرق','حولي','سلوى',
    'الرقعي','ميدان حولي','النزهة','الزهراء',
  ],
  'محافظة الفروانية': [
    'الفروانية','خيطان','العارضية','الرابية','الرقة',
    'أبو فطيرة','أبو الحصانية','الأندلس','الفردوس',
    'إشبيلية','جليب الشيوخ','الضجيج','الوسطى',
  ],
  'محافظة الأحمدي': [
    'الأحمدي','الفحيحيل','المنقف','أبو حليفة','الظهر',
    'هدية','الرقة','الزور','المقوع','ميناء عبدالله',
    'الجليعة','الوفرة','صباح الأحمد','بنيدر',
  ],
  'محافظة الجهراء': [
    'الجهراء','القصر','تيماء','النسيم','الوهدة',
    'الواحة','الاميرية','كبد','الصليبية','العيون',
    'الروضتين','الصبية',
  ],
  'محافظة مبارك الكبير': [
    'مبارك الكبير','صباح السالم','أبو فطيرة','أبو الحصانية',
    'القصور','العقيلة','المسيلة','الفنيطيس','ضاحية صباح السالم',
  ],
};

// ── جميع الخدمات ──────────────────────────────────────────
const List<ServiceModel> kServices = [
  ServiceModel(name: 'سباك', description: 'تصليح تسربات وتركيب أدوات صحية', icon: Icons.plumbing, type: ServiceType.worker),
  ServiceModel(name: 'كهربائي', description: 'تمديد أسلاك وتصليح أعطال الكهرباء', icon: Icons.electrical_services, type: ServiceType.worker),
  ServiceModel(name: 'نجار', description: 'تصليح وتركيب الأبواب والنوافذ', icon: Icons.carpenter, type: ServiceType.worker),
  ServiceModel(name: 'فني تكييف', description: 'صيانة وتنظيف وتركيب المكيفات', icon: Icons.ac_unit, type: ServiceType.worker),
  ServiceModel(name: 'دهان', description: 'دهان الجدران والأسقف', icon: Icons.format_paint, type: ServiceType.worker),
  ServiceModel(name: 'بناء ومقاولة', description: 'بناء وترميم المنازل والفلل', icon: Icons.construction, type: ServiceType.worker),
  ServiceModel(name: 'نقل أثاث', description: 'نقل الأثاث وفك وتركيب العفش', icon: Icons.local_shipping, type: ServiceType.worker),
];

// ── أقسام المحلات ─────────────────────────────────────────
const List<String> kShopCategories = [
  'محلات أدوات كهربائية',
  'أدوات صحية',
  'محلات سيراميك ورخام',
  'مواد بناء',
  'محلات معدات كهربائية',
  'تأجير معدات ومولدات',
  'محلات أصباغ',
  'محلات ديكورات',
  'محلات أحواض سباحة',
  'متجر',
];

// ── أقسام الشركات ─────────────────────────────────────────
const List<String> kCompanyCategories = [
  'شركات تشطيب',
  'شركات مقاولات وترميمات',
  'شركة',
  'مكتب',
];