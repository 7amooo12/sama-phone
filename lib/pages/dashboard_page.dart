import 'package:smartbiztracker_new/widgets/feature_card.dart';
import 'package:smartbiztracker_new/pages/image_search_page.dart';

FeatureCard(
  title: 'البحث بالصورة',
  description: 'ابحث عن المنتجات المشابهة باستخدام الصور',
  icon: Icons.image_search,
  color: Colors.purple,
  isNew: true,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImageSearchPage()),
    );
  },
), 