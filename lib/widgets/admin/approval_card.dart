import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:timeago/timeago.dart' as timeago;

class ApprovalCard extends StatefulWidget {
  const ApprovalCard({
    super.key,
    required this.user,
    required this.onApprove,
  });
  final UserModel user;
  final Function(UserModel user, String role) onApprove;

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard> {
  bool _isExpanded = false;
  String _selectedRole = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _getTimeAgo(widget.user.createdAt);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.safeOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Info Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.safeOpacity(0.1),
                  child: Text(
                    widget.user.name.isNotEmpty
                        ? widget.user.name[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.user.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.safeOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Email
                      Text(
                        widget.user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.safeOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Role tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRoleColor(widget.user.role.value)
                              .safeOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRoleName(widget.user.role.value),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(widget.user.role.value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Expand button
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),

            // Expanded section with role selection and approve button
            if (_isExpanded) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'الدور',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: UserRole.client.value,
                          child: const Text('عميل'),
                        ),
                        DropdownMenuItem(
                          value: UserRole.worker.value,
                          child: const Text('عامل'),
                        ),
                        DropdownMenuItem(
                          value: UserRole.owner.value,
                          child: const Text('صاحب عمل'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() {
                              _isLoading = true;
                            });

                            await widget.onApprove(widget.user, _selectedRole);

                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                                _isExpanded = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('موافقة'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime? date) {
    if (date == null) return 'غير متوفر';
    return timeago.format(date, locale: 'ar');
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'owner':
        return 'صاحب عمل';
      case 'client':
        return 'عميل';
      case 'worker':
        return 'عامل';
      case 'accountant':
        return 'محاسب';
      default:
        return 'مستخدم';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'owner':
        return Colors.blue;
      case 'client':
        return Colors.green;
      case 'worker':
        return Colors.orange;
      case 'accountant':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
