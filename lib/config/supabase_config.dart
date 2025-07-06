class SupabaseConfig {
  static const String url = 'https://ivtjacsppwmjgmuskxis.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2dGphY3NwcHdtamdtdXNreGlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc3NzUyMjUsImV4cCI6MjA2MzM1MTIyNX0.Ls9Kh3VHhIebuied6N1-QlWkSrEDuLl5vy3XkUVRjHw';
  static const String serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2dGphY3NwcHdtamdtdXNreGlzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0Nzc3NTIyNSwiZXhwIjoyMDYzMzUxMjI1fQ.jfsux-fLn-cFEA4afkDCqYNI_v3g_F34vYw5Eu_fjeM';

  // S3 Storage Configuration
  static const String s3AccessKeyId = '26c3b0dac50200a2c77a7173d8ec8400';
  static const String s3SecretAccessKey = 'c8c227195853cbfa33d728aef98835165f05c511872d46748445abbc2125eeb3';
  static const String s3Region = 'eu-central-1'; // المنطقة الصحيحة حسب إعداد Supabase
  static const String s3Endpoint = 'https://ivtjacsppwmjgmuskxis.supabase.co/storage/v1/s3';

  // Storage Buckets
  static const Map<String, String> buckets = {
    'profile-images': 'profile-images',
    'product-images': 'product-images',
    'invoices': 'invoices',
    'attachments': 'attachments',
    'documents': 'documents',
    // Worker system buckets
    'task-attachments': 'task-attachments',
    'task-evidence': 'task-evidence',
    'worker-documents': 'worker-documents',
    'reward-certificates': 'reward-certificates',
  };

  // Storage Settings
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  ];

  static const List<String> allowedDocumentTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'text/csv',
  ];
}