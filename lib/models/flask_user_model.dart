

class FlaskUserModel {

  const FlaskUserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
    required this.status,
    required this.role,
    this.createdAt,
  });

  factory FlaskUserModel.fromJson(Map<String, dynamic> json) {
    return FlaskUserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      isAdmin: json['is_admin'] as bool,
      status: json['status'] as String? ?? 'pending',
      role: json['role'] as String? ?? 'user',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
  final int id;
  final String username;
  final String email;
  final bool isAdmin;
  final String status;
  final String role;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_admin': isAdmin,
      'status': status,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Check if user is approved
  bool get isApproved => status == 'active';

  // Check if user is pending approval
  bool get isPending => status == 'pending';

  @override
  String toString() => 'FlaskUserModel(id: $id, username: $username, email: $email, status: $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlaskUserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}