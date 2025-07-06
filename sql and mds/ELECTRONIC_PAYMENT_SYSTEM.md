# Electronic Payment System - SmartBizTracker

## Overview
A comprehensive electronic payment system for Vodafone Cash and InstaPay integration in the SmartBizTracker Flutter application. The system allows clients to make electronic payments, upload proof of payment, and enables admin/accountant approval workflow with automatic wallet balance updates.

## Features

### Client Features
- **Payment Method Selection**: Choose between Vodafone Cash and InstaPay
- **Account Selection**: Select from available payment accounts with swipe gestures
- **USSD Integration**: Automatic phone dialer launch for Vodafone Cash payments
- **Proof Upload**: Camera integration for payment proof screenshots
- **Payment History**: View all payment requests and their status
- **Real-time Status Updates**: Track payment approval status

### Admin/Accountant Features
- **Payment Management**: View, approve, or reject payment requests
- **Payment Statistics**: Dashboard with payment analytics
- **Proof Verification**: View uploaded payment proofs
- **Account Management**: Manage payment accounts (admin only)
- **Bulk Operations**: Filter and manage multiple payments
- **Audit Trail**: Complete payment history with admin notes

## Architecture

### Database Schema
```sql
-- Payment Accounts Table
payment_accounts (
    id UUID PRIMARY KEY,
    account_type TEXT ('vodafone_cash', 'instapay'),
    account_number TEXT,
    account_holder_name TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)

-- Electronic Payments Table
electronic_payments (
    id UUID PRIMARY KEY,
    client_id UUID REFERENCES auth.users(id),
    payment_method TEXT ('vodafone_cash', 'instapay'),
    amount DECIMAL(10,2),
    proof_image_url TEXT,
    recipient_account_id UUID REFERENCES payment_accounts(id),
    status TEXT ('pending', 'approved', 'rejected'),
    admin_notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP,
    metadata JSONB
)
```

### File Structure
```
lib/
├── models/
│   ├── electronic_payment_model.dart
│   └── payment_account_model.dart
├── services/
│   └── electronic_payment_service.dart
├── providers/
│   └── electronic_payment_provider.dart
├── screens/
│   ├── client/
│   │   ├── payment_method_selection_screen.dart
│   │   ├── payment_account_selection_screen.dart
│   │   └── payment_form_screen.dart
│   └── admin/
│       └── electronic_payment_management_screen.dart
└── supabase/
    └── migrations/
        ├── 20241220000000_create_electronic_payment_system.sql
        └── 20241220000001_create_payment_proofs_bucket.sql
```

## Implementation Details

### State Management
- **Provider Pattern**: Uses Flutter Provider for state management
- **Real-time Updates**: Supabase subscriptions for live data
- **Error Handling**: Comprehensive error states and user feedback
- **Loading States**: Proper loading indicators throughout the flow

### Security
- **RLS Policies**: Row Level Security for data access control
- **Role-based Access**: Different permissions for clients, accountants, and admins
- **File Upload Security**: Secure image upload with validation
- **Authentication**: Supabase Auth integration

### UI/UX Design
- **Dark Theme**: Consistent with project's black background design
- **Arabic RTL**: Full right-to-left language support
- **Green Accents**: Project's signature green color scheme
- **Smooth Animations**: Fade and slide transitions
- **Responsive Design**: Works on various screen sizes

## Usage

### For Clients
1. Navigate to wallet page ("محفظتي")
2. Click "الدفع الإلكتروني" button
3. Select payment method (Vodafone Cash or InstaPay)
4. Choose recipient account with swipe gesture
5. Enter payment amount and optional notes
6. For Vodafone Cash: Phone dialer opens with USSD code
7. For InstaPay: Manual transfer instructions provided
8. Upload payment proof screenshot
9. Submit payment request
10. Track status in payment history

### For Admin/Accountant
1. Access "المدفوعات الإلكترونية" tab in dashboard
2. View payment statistics and pending requests
3. Review payment details and proof images
4. Approve or reject payments with optional notes
5. Manage payment accounts (admin only)
6. Export payment reports

## API Integration

### USSD Integration
```dart
// Vodafone Cash USSD format
final ussdCode = '*9*7*${accountNumber}*${amount}#';
final uri = Uri(scheme: 'tel', path: ussdCode);
await launchUrl(uri);
```

### Image Upload
```dart
// Upload payment proof to Supabase Storage
final imageUrl = await _storageService.uploadPaymentProof(
  clientId: userId,
  paymentId: paymentId,
  file: proofImage,
);
```

### Wallet Integration
```sql
-- Automatic wallet balance update on payment approval
UPDATE public.wallets 
SET balance = balance + NEW.amount,
    updated_at = now()
WHERE user_id = NEW.client_id;
```

## Configuration

### Environment Setup
1. Ensure Supabase project is configured
2. Run database migrations
3. Set up storage buckets with RLS policies
4. Configure authentication providers
5. Update app permissions for camera and phone access

### Dependencies
```yaml
dependencies:
  url_launcher: ^6.2.2  # For USSD integration
  image_picker: ^1.0.4  # For camera access
  supabase_flutter: ^2.0.0  # Database and storage
  provider: ^6.1.1  # State management
```

### Permissions
```xml
<!-- Android permissions -->
<uses-permission android:name="android.permission.CALL_PHONE" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

## Testing

### Test Scenarios
1. **Payment Flow**: Complete payment process from selection to approval
2. **USSD Integration**: Test phone dialer launch with correct codes
3. **Image Upload**: Verify proof upload and storage
4. **Approval Workflow**: Test admin approval/rejection process
5. **Wallet Integration**: Confirm balance updates on approval
6. **Error Handling**: Test network failures and invalid inputs

### Test Data
```sql
-- Insert test payment accounts
INSERT INTO payment_accounts (account_type, account_number, account_holder_name) VALUES
('vodafone_cash', '01000000000', 'SAMA Store - Vodafone Cash'),
('instapay', 'SAMA@instapay', 'SAMA Store - InstaPay');
```

## Deployment

### Production Checklist
- [ ] Database migrations applied
- [ ] Storage buckets created with proper RLS policies
- [ ] Payment accounts configured
- [ ] App permissions granted
- [ ] USSD codes tested with actual phone numbers
- [ ] Image upload limits configured
- [ ] Error monitoring enabled
- [ ] User training completed

### Monitoring
- Payment success/failure rates
- Average approval time
- Image upload success rates
- USSD integration effectiveness
- User adoption metrics

## Support

### Common Issues
1. **USSD not launching**: Check phone permissions and URL launcher setup
2. **Image upload failing**: Verify storage bucket permissions and file size limits
3. **Payment not appearing**: Check RLS policies and user authentication
4. **Balance not updating**: Verify wallet integration and trigger functions

### Troubleshooting
- Enable debug logging in development
- Check Supabase logs for database errors
- Verify user roles and permissions
- Test with different payment amounts and accounts

## Future Enhancements
- Integration with additional payment providers
- Automated payment verification
- Bulk payment processing
- Payment scheduling
- Advanced analytics and reporting
- Mobile money integration
- QR code payment support
