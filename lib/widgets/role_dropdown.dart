import 'package:flutter/material.dart';

class RoleDropdown extends StatefulWidget {
  const RoleDropdown({
    super.key,
    required this.onChanged,
    this.initialValue,
  });
  final Function(String) onChanged;
  final String? initialValue;

  @override
  State<RoleDropdown> createState() => _RoleDropdownState();
}

class _RoleDropdownState extends State<RoleDropdown> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialValue ?? 'client';
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: const InputDecoration(
        labelText: 'الدور',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 'admin',
          child: Text('مدير'),
        ),
        DropdownMenuItem(
          value: 'client',
          child: Text('عميل'),
        ),
        DropdownMenuItem(
          value: 'worker',
          child: Text('عامل'),
        ),
        DropdownMenuItem(
          value: 'owner',
          child: Text('صاحب عمل'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedRole = value;
          });
          widget.onChanged(value);
        }
      },
    );
  }
}
