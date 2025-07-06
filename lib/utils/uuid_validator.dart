/// UUID validation utility for SmartBizTracker
/// 
/// This utility provides helper functions for validating UUID strings
/// and handling UUID-related operations safely for PostgreSQL database.

class UuidValidator {
  // Regular expression for UUID v4 format validation
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  );

  /// Validates if a string is a valid UUID format
  /// 
  /// Returns true if the string matches UUID v4 format, false otherwise
  static bool isValidUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      return false;
    }
    return _uuidRegex.hasMatch(uuid);
  }

  /// Safely converts a string to UUID for database operations
  /// 
  /// Returns the UUID string if valid, null if invalid or empty
  /// This prevents PostgreSQL UUID validation errors
  static String? toValidUuidOrNull(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      return null;
    }
    return isValidUuid(uuid) ? uuid : null;
  }

  /// Prepares UUID for JSON serialization in database models
  /// 
  /// Only includes the UUID in the JSON map if it's valid
  /// This prevents sending empty strings to PostgreSQL UUID fields
  static void addUuidToJson(Map<String, dynamic> json, String key, String? uuid) {
    final validUuid = toValidUuidOrNull(uuid);
    if (validUuid != null) {
      json[key] = validUuid;
    }
  }

  /// Validates customer ID UUID for database operations
  /// 
  /// Throws an exception with Arabic error message if invalid
  static void validateCustomerId(String? customerId) {
    if (customerId == null || customerId.isEmpty) {
      throw Exception('معرف العميل مطلوب');
    }
    if (!isValidUuid(customerId)) {
      throw Exception('معرف العميل غير صحيح');
    }
  }

  /// Validates any UUID parameter with custom error message
  /// 
  /// Throws an exception with provided Arabic error message if invalid
  static void validateUuidWithMessage(String? uuid, String errorMessage) {
    if (uuid == null || uuid.isEmpty || !isValidUuid(uuid)) {
      throw Exception(errorMessage);
    }
  }

  /// Generates a safe UUID map entry for database insertion
  ///
  /// Returns a map with the UUID field only if it's valid
  /// Used for conditional UUID inclusion in database operations
  static Map<String, dynamic> createUuidMap(String key, String? uuid) {
    final validUuid = toValidUuidOrNull(uuid);
    return validUuid != null ? {key: validUuid} : <String, dynamic>{};
  }

  /// Validates advance ID UUID for database operations
  ///
  /// Throws an exception with Arabic error message if invalid
  static void validateAdvanceId(String? advanceId) {
    if (advanceId == null || advanceId.isEmpty) {
      throw Exception('معرف السلفة مطلوب');
    }
    if (!isValidUuid(advanceId)) {
      throw Exception('معرف السلفة غير صحيح');
    }
  }

  /// Validates created_by UUID for database operations
  ///
  /// Throws an exception with Arabic error message if invalid
  static void validateCreatedBy(String? createdBy) {
    if (createdBy == null || createdBy.isEmpty) {
      throw Exception('معرف منشئ السلفة مطلوب');
    }
    if (!isValidUuid(createdBy)) {
      throw Exception('معرف منشئ السلفة غير صحيح');
    }
  }

  /// Validates optional client ID UUID (only if not empty)
  ///
  /// Throws an exception with Arabic error message if invalid format
  static void validateOptionalClientId(String? clientId) {
    if (clientId != null && clientId.isNotEmpty && !isValidUuid(clientId)) {
      throw Exception('معرف العميل غير صحيح');
    }
  }
}
