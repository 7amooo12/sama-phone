import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/widgets/forms/error_report_form.dart';
import 'package:smartbiztracker_new/widgets/forms/product_return_form.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CustomerServiceScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const CustomerServiceScreen({
    Key? key, 
    this.initialTabIndex = 0
  }) : super(key: key);

  @override
  State<CustomerServiceScreen> createState() => _CustomerServiceScreenState();
}

class _CustomerServiceScreenState extends State<CustomerServiceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSubmitting = false;
  bool _showSuccess = false;
  String _successMessage = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_handleTabChange);
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    if (_showSuccess) {
      setState(() {
        _showSuccess = false;
      });
    }
  }
  
  // Handle error report submission
  void _handleErrorReportSubmit(Map<String, dynamic> errorReport) async {
    setState(() {
      _isSubmitting = true;
    });
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    
    // Show success message
    setState(() {
      _isSubmitting = false;
      _showSuccess = true;
      _successMessage = 'تم إرسال بلاغ الخطأ بنجاح! سنتواصل معك قريباً.';
    });
    
    // Log the submitted data
    print('Error Report Submitted: $errorReport');
  }
  
  // Handle product return submission
  void _handleReturnSubmit(Map<String, dynamic> returnData) async {
    setState(() {
      _isSubmitting = true;
    });
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    
    // Show success message
    setState(() {
      _isSubmitting = false;
      _showSuccess = true;
      _successMessage = 'تم إرسال طلب الإرجاع بنجاح! سنراجع طلبك ونتواصل معك خلال 24 ساعة.';
    });
    
    // Log the submitted data
    print('Return Request Submitted: $returnData');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خدمة العملاء'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: StyleSystem.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StyleSystem.primaryColor,
          labelColor: StyleSystem.primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.report_problem_outlined),
              text: 'الإبلاغ عن خطأ',
            ),
            Tab(
              icon: Icon(Icons.swap_horiz_outlined),
              text: 'طلب إرجاع منتج',
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background pattern
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              image: DecorationImage(
                image: const AssetImage('assets/images/pattern.png'),
                opacity: 0.03,
                repeat: ImageRepeat.repeat,
                scale: 8,
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Error Report Tab
                _buildErrorReportTab(),
                
                // Product Return Tab
                _buildReturnTab(),
              ],
            ),
          ),
          
          // Success Overlay
          if (_showSuccess)
            _buildSuccessOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildErrorReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Text(
            'الإبلاغ عن خطأ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: StyleSystem.primaryColor,
            ),
          ).animate().fadeIn(duration: 400.ms).moveY(begin: -10, end: 0),
          
          const SizedBox(height: 8),
          
          Text(
            'ساعدنا في تحسين خدماتنا من خلال الإبلاغ عن أي أخطاء تواجهها',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).moveY(begin: -10, end: 0),
          
          const SizedBox(height: 24),
          
          // Error Report Form
          ErrorReportForm(
            onSubmit: _handleErrorReportSubmit,
            isLoading: _isSubmitting,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  Widget _buildReturnTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Text(
            'طلب إرجاع منتج',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: StyleSystem.primaryColor,
            ),
          ).animate().fadeIn(duration: 400.ms).moveY(begin: -10, end: 0),
          
          const SizedBox(height: 8),
          
          Text(
            'تقديم طلب إرجاع للمنتجات التي لا تلبي توقعاتك أو بها عيوب',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).moveY(begin: -10, end: 0),
          
          const SizedBox(height: 24),
          
          // Return Form
          ProductReturnForm(
            onSubmit: _handleReturnSubmit,
            isLoading: _isSubmitting,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  Widget _buildSuccessOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: StyleSystem.shadowLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: StyleSystem.successColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: StyleSystem.successColor,
                  ),
                ).animate().scaleXY(begin: 0.5, end: 1.0, duration: 500.ms, curve: Curves.elasticOut),
                
                const SizedBox(height: 24),
                
                Text(
                  'تم الإرسال بنجاح!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: StyleSystem.primaryColor,
                  ),
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 16),
                
                Text(
                  _successMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ).animate().fadeIn(delay: 400.ms),
                
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showSuccess = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StyleSystem.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('حسناً'),
                ).animate().fadeIn(delay: 500.ms).moveY(begin: 20, end: 0)
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }
} 