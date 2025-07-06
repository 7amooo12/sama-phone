import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/distributors_provider.dart';
import '../../models/distributor_model.dart';
import '../../models/distribution_center_model.dart';

/// Professional screen for viewing and managing individual distributor details
class DistributorDetailsScreen extends StatefulWidget {
  const DistributorDetailsScreen({
    super.key,
    required this.distributor,
    required this.center,
  });

  final DistributorModel distributor;
  final DistributionCenterModel center;

  @override
  State<DistributorDetailsScreen> createState() => _DistributorDetailsScreenState();
}

class _DistributorDetailsScreenState extends State<DistributorDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن إجراء المكالمة: $phoneNumber',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _updateDistributorStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<DistributorsProvider>();
      final success = await provider.updateDistributorStatus(widget.distributor.id, DistributorStatus.fromString(newStatus));

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  'تم تحديث حالة الموزع بنجاح',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Refresh the screen or navigate back
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? 'فشل في تحديث حالة الموزع',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: $e',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteDistributor() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف الموزع "${widget.distributor.name}"؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final provider = context.read<DistributorsProvider>();
        final success = await provider.deleteDistributor(widget.distributor.id);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'تم حذف الموزع بنجاح',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.error ?? 'فشل في حذف الموزع',
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'حدث خطأ: $e',
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A), // Professional luxurious black
              Color(0xFF1A1A2E), // Darkened blue-black
              Color(0xFF16213E), // Deep blue-black
              Color(0xFF0F0F23), // Rich dark blue
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildCustomAppBar(),

              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.blue.shade200,
                      Colors.white,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'تفاصيل الموزع',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  widget.center.name,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Phone Button
          if (widget.distributor.contactPhone.isNotEmpty)
            IconButton(
              onPressed: () => _makePhoneCall(widget.distributor.contactPhone),
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.8),
                      Colors.teal.withOpacity(0.8),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.phone,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

          // Actions Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1A1A2E),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  // TODO: Navigate to edit screen
                  break;
                case 'activate':
                  _updateDistributorStatus('active');
                  break;
                case 'deactivate':
                  _updateDistributorStatus('inactive');
                  break;
                case 'suspend':
                  _updateDistributorStatus('suspended');
                  break;
                case 'delete':
                  _deleteDistributor();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'تعديل',
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (widget.distributor.status != DistributorStatus.active)
                PopupMenuItem(
                  value: 'activate',
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'تفعيل',
                        style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              if (widget.distributor.status == DistributorStatus.active)
                PopupMenuItem(
                  value: 'deactivate',
                  child: Row(
                    children: [
                      const Icon(Icons.pause_circle, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'إلغاء التفعيل',
                        style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'suspend',
                child: Row(
                  children: [
                    const Icon(Icons.block, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'تعليق',
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'حذف',
                      style: GoogleFonts.cairo(color: Colors.red, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distributor Header Card
          _buildDistributorHeader(),

          const SizedBox(height: 24),

          // Basic Information
          _buildInfoSection(
            'المعلومات الأساسية',
            Icons.person,
            [
              _buildInfoRow('الاسم', widget.distributor.name, Icons.person),
              _buildInfoRow('رقم الهاتف', widget.distributor.contactPhone, Icons.phone),
              _buildInfoRow('اسم المعرض', widget.distributor.showroomName, Icons.store),
              if (widget.distributor.showroomAddress?.isNotEmpty ?? false)
                _buildInfoRow('العنوان', widget.distributor.showroomAddress!, Icons.location_on),
              if (widget.distributor.email?.isNotEmpty ?? false)
                _buildInfoRow('البريد الإلكتروني', widget.distributor.email!, Icons.email),
              if (widget.distributor.nationalId?.isNotEmpty ?? false)
                _buildInfoRow('الرقم القومي', widget.distributor.nationalId!, Icons.badge),
            ],
          ),

          const SizedBox(height: 24),

          // Financial Information
          if (widget.distributor.commissionRate > 0 || widget.distributor.creditLimit > 0)
            _buildInfoSection(
              'المعلومات المالية',
              Icons.account_balance,
              [
                if (widget.distributor.commissionRate > 0)
                  _buildInfoRow('نسبة العمولة', '${widget.distributor.commissionRate}%', Icons.percent),
                if (widget.distributor.creditLimit > 0)
                  _buildInfoRow('حد الائتمان', '${widget.distributor.creditLimit} جنيه', Icons.credit_card),
              ],
            ),

          const SizedBox(height: 24),

          // Contract Information
          if (widget.distributor.contractStartDate != null || widget.distributor.contractEndDate != null)
            _buildInfoSection(
              'معلومات العقد',
              Icons.description,
              [
                if (widget.distributor.contractStartDate != null)
                  _buildInfoRow(
                    'تاريخ بداية العقد',
                    '${widget.distributor.contractStartDate!.day}/${widget.distributor.contractStartDate!.month}/${widget.distributor.contractStartDate!.year}',
                    Icons.calendar_today,
                  ),
                if (widget.distributor.contractEndDate != null)
                  _buildInfoRow(
                    'تاريخ نهاية العقد',
                    '${widget.distributor.contractEndDate!.day}/${widget.distributor.contractEndDate!.month}/${widget.distributor.contractEndDate!.year}',
                    Icons.calendar_today,
                  ),
              ],
            ),

          const SizedBox(height: 24),

          // System Information
          _buildInfoSection(
            'معلومات النظام',
            Icons.info,
            [
              _buildInfoRow(
                'تاريخ الإنشاء',
                '${widget.distributor.createdAt.day}/${widget.distributor.createdAt.month}/${widget.distributor.createdAt.year}',
                Icons.add_circle,
              ),
              if (widget.distributor.updatedAt != null)
                _buildInfoRow(
                  'آخر تحديث',
                  '${widget.distributor.updatedAt!.day}/${widget.distributor.updatedAt!.month}/${widget.distributor.updatedAt!.year}',
                  Icons.update,
                ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
  Widget _buildDistributorHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(widget.distributor.status.value).withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _getStatusColor(widget.distributor.status.value).withOpacity(0.8),
                  _getStatusColor(widget.distributor.status.value).withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(widget.distributor.status.value).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 40,
            ),
          ),

          const SizedBox(width: 20),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.distributor.name,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.distributor.status.value),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusText(widget.distributor.status.value),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                if (widget.distributor.showroomName.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.store,
                        size: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.distributor.showroomName,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.8),
                      Colors.indigo.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Content
          ...children,
        ],
      ),
    );
  }
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.white.withOpacity(0.7),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'نشط';
      case 'inactive':
        return 'غير نشط';
      case 'suspended':
        return 'معلق';
      case 'pending':
        return 'قيد المراجعة';
      default:
        return 'غير محدد';
    }
  }
}