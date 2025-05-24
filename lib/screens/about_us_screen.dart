import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'اعرف عنا',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: StyleSystem.primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo & Name
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: StyleSystem.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        width: 150,
                        height: 150,
                        color: Colors.white,
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'SAMA',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: StyleSystem.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 800.ms).scale(delay: 200.ms),
                  const SizedBox(height: 20),
                  Text(
                    'SAMA سايبربانك ستور',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: StyleSystem.primaryColor.withOpacity(0.5),
                          blurRadius: 10,
                        )
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 10),
                  Text(
                    'تسوق المستقبل، اليوم',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // About Us Section
            _buildSectionTitle('من نحن'),
            _buildTextContent(
              'شركة SAMA هي شركة مبتكرة تجمع بين التكنولوجيا المتطورة وتصميم المنتجات عالية الجودة، تأسست عام 2020 بهدف توفير منتجات تقنية بتصاميم مستقبلية مستوحاة من عالم السايبربانك.',
            ),
            const SizedBox(height: 30),

            // Mission Section
            _buildSectionTitle('رؤيتنا ورسالتنا'),
            _buildTextContent(
              'نسعى لنكون الرواد في مجال التجارة الإلكترونية للمنتجات ذات الطابع المستقبلي، ونهدف لدمج التكنولوجيا بالتصميم الإبداعي لتوفير تجربة تسوق فريدة لعملائنا.',
            ),
            const SizedBox(height: 30),

            // Our Products Section
            _buildSectionTitle('منتجاتنا'),
            _buildTextContent(
              'نقدم مجموعة متنوعة من المنتجات التقنية وإكسسوارات الكمبيوتر والإضاءة وأجهزة الواقع الافتراضي، كلها بتصاميم مستقبلية تعكس رؤية عالم السايبربانك.',
            ),
            const SizedBox(height: 20),

            // Feature categories
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                _buildCategoryCard(
                  'إلكترونيات', 
                  Icons.devices, 
                  Colors.blue.shade800
                ),
                _buildCategoryCard(
                  'إكسسوارات', 
                  Icons.cable, 
                  Colors.purple.shade800
                ),
                _buildCategoryCard(
                  'إضاءة LED', 
                  Icons.lightbulb, 
                  Colors.amber.shade800
                ),
                _buildCategoryCard(
                  'واقع افتراضي', 
                  Icons.view_in_ar, 
                  Colors.green.shade800
                ),
              ],
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 30),

            // Contact Info Section
            _buildSectionTitle('تواصل معنا'),
            _buildContactItem(Icons.phone, '+966 50 123 4567'),
            _buildContactItem(Icons.email, 'info@samastore.com'),
            _buildContactItem(Icons.location_on, 'الرياض، المملكة العربية السعودية'),
            const SizedBox(height: 40),

            // Social Media Section
            Center(
              child: Wrap(
                spacing: 20,
                children: [
                  _buildSocialButton(Icons.facebook, Colors.blue),
                  _buildSocialButton(Icons.snapchat, Colors.yellow.shade700),
                  _buildSocialButton(Icons.email, Colors.red),
                  _buildSocialButton(Icons.message, StyleSystem.primaryColor),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Team Section
            _buildSectionTitle('فريقنا'),
            _buildTeamMembers(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 25,
            color: StyleSystem.primaryColor,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().moveX(begin: -20, end: 0);
  }

  Widget _buildTextContent(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        color: Colors.white.withOpacity(0.9),
        height: 1.6,
      ),
      textAlign: TextAlign.justify,
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return Card(
      color: StyleSystem.backgroundDark.withOpacity(0.7),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 35,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(
            icon,
            color: StyleSystem.primaryColor,
            size: 22,
          ),
          const SizedBox(width: 15),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildSocialButton(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 25,
      ),
    ).animate().scale(delay: 700.ms);
  }

  Widget _buildTeamMembers() {
    return Column(
      children: [
        _buildTeamMemberCard(
          'محمد السيد',
          'مطور البرمجيات',
          'محمد يعمل كمطور البرمجيات في شركة SAMA، وهو مهتم بتطوير تطبيقات الهاتف الذكية والويب، ويعمل على تحسين الميزات وإضافة الميزات الجديدة.',
          'https://example.com/mohamed.jpg'
        ),
        _buildTeamMemberCard(
          'إيمان السيد',
          'مصمم الموقع',
          'إيمان يعمل كمصمم الموقع في شركة SAMA، وهو مهتم بتصميم المواقع والتصاميم الإبداعية، ويعمل على جعل الموقع جذابًا ومبهجًا.',
          'https://example.com/eman.jpg'
        ),
        _buildTeamMemberCard(
          'أحمد السيد',
          'مدير المبيعات',
          'أحمد يعمل كمدير المبيعات في شركة SAMA، وهو مهتم بالتسويق والمبيعات، ويعمل على زيادة المبيعات وتحسين خدمة العملاء.',
          'https://example.com/ahmed.jpg'
        ),
      ],
    ).animate().fadeIn().moveX(begin: -20, end: 0);
  }

  Widget _buildTeamMemberCard(String name, String role, String description, String imageUrl) {
    return Card(
      color: StyleSystem.backgroundDark.withOpacity(0.7),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.network(
              imageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            role,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 