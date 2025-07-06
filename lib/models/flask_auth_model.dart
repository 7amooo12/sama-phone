

import 'flask_user_model.dart';

class FlaskAuthModel {

  const FlaskAuthModel({
    required this.success,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.message,
    this.error,
    this.status,
  });

  factory FlaskAuthModel.fromJson(Map<String, dynamic> json) {
    return FlaskAuthModel(
      success: json['success'] as bool? ?? false,
      user: json['user'] != null
          ? FlaskUserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      accessToken: json['tokens']?['access_token'] as String?,
      refreshToken: json['tokens']?['refresh_token'] as String?,
      message: json['message'] as String?,
      error: json['error'] as String?,
      status: json['status'] as String?,
    );
  }

  // Create an error model
  factory FlaskAuthModel.error(String errorMessage, {String? status}) {
    return FlaskAuthModel(
      success: false,
      error: errorMessage,
      status: status,
    );
  }
  final bool success;
  final FlaskUserModel? user;
  final String? accessToken;
  final String? refreshToken;
  final String? message;
  final String? error;
  final String? status;

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'user': user?.toJson(),
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'message': message,
      'error': error,
      'status': status,
    };
  }

  // Check if the authentication was successful and has all required data
  bool get isAuthenticated => success && user != null && accessToken != null;

  // Check if the account is pending approval
  bool get isPendingApproval => status == 'pending' || (user?.isPending ?? false);

  @override
  String toString() => 'FlaskAuthModel(success: $success, user: ${user?.username}, error: $error, status: $status)';
}