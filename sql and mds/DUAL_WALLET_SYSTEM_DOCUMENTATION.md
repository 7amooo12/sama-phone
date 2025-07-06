# Dual Wallet System for Electronic Payments

## Overview

The Dual Wallet System ensures proper money transfer between client personal wallets and company electronic wallets when electronic payments are approved. This system prevents money creation and maintains proper accounting principles.

## System Architecture

### Two Wallet Types

1. **Client Personal Wallets** (`wallets` table)
   - Individual user account balances
   - Managed by accountants
   - Used for client spending

2. **Company Electronic Wallets** (`electronic_wallets` table)
   - Company payment accounts (Vodafone Cash, InstaPay)
   - Created by accountants
   - Receive electronic payments from clients

## Dual Transaction Process

### When Electronic Payment is Approved:

1. **Client Wallet Debit**:
   - Deduct payment amount from client's personal wallet
   - Create transaction record in `wallet_transactions`
   - Transaction type: `payment`

2. **Electronic Wallet Credit**:
   - Add payment amount to company electronic wallet
   - Create transaction record in `electronic_wallet_transactions`
   - Transaction type: `deposit`

3. **Atomic Operation**:
   - Both operations succeed or both fail
   - No partial updates possible
   - Maintains data consistency

## Database Functions

### Core Functions

#### `process_dual_wallet_transaction()`
```sql
-- Performs atomic dual wallet transaction
-- Parameters:
--   client_user_id: UUID of the client
--   electronic_wallet_id: UUID of the electronic wallet
--   transaction_amount: Amount to transfer
--   payment_id_param: Reference payment ID
--   description_param: Transaction description
--   processed_by_param: UUID of approver
-- Returns: JSON with transaction details
```

#### `update_client_wallet_balance()`
```sql
-- Updates client wallet balance and creates transaction record
-- Validates sufficient balance before deduction
-- Creates linked transaction in wallet_transactions table
```

#### `update_electronic_wallet_balance()`
```sql
-- Updates electronic wallet balance and creates transaction record
-- Supports both deposit and withdrawal operations
-- Creates linked transaction in electronic_wallet_transactions table
```

#### `handle_electronic_payment_approval_v3()`
```sql
-- Trigger function for payment approval
-- Validates balances before processing
-- Calls process_dual_wallet_transaction() for atomic operation
-- Provides Arabic error messages
```

## Balance Validation

### Pre-Approval Checks

1. **Client Wallet Validation**:
   - Verify client wallet exists
   - Check sufficient balance (balance >= payment amount)
   - Display current balance to accountant

2. **Electronic Wallet Validation**:
   - Verify electronic wallet exists
   - Confirm wallet is active
   - Validate payment account synchronization

### Error Handling

- **Insufficient Balance**: `رصيد العميل غير كافي لإتمام العملية`
- **Missing Wallet**: `محفظة العميل غير موجودة للمستخدم`
- **Inactive Wallet**: `المحفظة الإلكترونية غير نشطة`

## UI Integration

### Approval Dialog Enhancements

1. **Balance Display**:
   - Shows current client balance
   - Displays remaining balance after payment
   - Color-coded validation status

2. **Approval Button State**:
   - Enabled only when balance is sufficient
   - Disabled for insufficient balance
   - Real-time validation feedback

3. **Error Messages**:
   - Arabic language support
   - Clear balance information
   - Professional error handling

## Transaction Linking

### Reference System

- **Payment ID**: Links both transactions
- **Reference Type**: `electronic_payment`
- **Audit Trail**: Complete transaction history

### Transaction Records

#### Client Wallet Transaction
```json
{
  "wallet_id": "client_wallet_uuid",
  "transaction_type": "payment",
  "amount": 100.00,
  "balance_before": 1000.00,
  "balance_after": 900.00,
  "reference_id": "payment_uuid",
  "reference_type": "electronic_payment",
  "description": "دفعة إلكترونية - فودافون كاش - خصم من محفظة العميل"
}
```

#### Electronic Wallet Transaction
```json
{
  "wallet_id": "electronic_wallet_uuid",
  "transaction_type": "deposit",
  "amount": 100.00,
  "balance_before": 500.00,
  "balance_after": 600.00,
  "payment_id": "payment_uuid",
  "description": "دفعة إلكترونية - فودافون كاش - إيداع في المحفظة الإلكترونية"
}
```

## Money Conservation

### Accounting Principles

1. **No Money Creation**: Total system money remains constant
2. **Proper Transfer**: Money moves from client to company
3. **Audit Trail**: Complete transaction history
4. **Balance Verification**: Before = After (total system balance)

### Example Transaction

```
Before Approval:
- Client Wallet: 1000 EGP
- Electronic Wallet: 500 EGP
- Total System: 1500 EGP

Payment: 100 EGP

After Approval:
- Client Wallet: 900 EGP (-100)
- Electronic Wallet: 600 EGP (+100)
- Total System: 1500 EGP (unchanged)
```

## API Integration

### Service Methods

#### ElectronicPaymentService
```dart
// Get client wallet balance
Future<double> getClientWalletBalance(String clientId)

// Validate balance before approval
Future<Map<String, dynamic>> validateClientWalletBalance(
  String clientId, 
  double paymentAmount
)
```

#### ElectronicPaymentProvider
```dart
// UI-friendly balance validation
Future<Map<String, dynamic>> validateClientWalletBalance(
  String clientId, 
  double paymentAmount
)

// Get current client balance
Future<double> getClientWalletBalance(String clientId)
```

## Testing

### Automated Tests

Run `TEST_DUAL_WALLET_SYSTEM.sql` to verify:

1. **Balance Validation**: Sufficient/insufficient balance scenarios
2. **Atomic Transactions**: Both wallets updated or neither
3. **Money Conservation**: Total system balance unchanged
4. **Transaction Linking**: Proper reference relationships
5. **Error Handling**: Appropriate error messages

### Manual Testing Steps

1. **Create Electronic Wallet** (Accountant)
2. **Create Client Payment** (Client)
3. **Validate Balance Display** (Accountant approval dialog)
4. **Approve Payment** (Accountant)
5. **Verify Balance Updates** (Both wallets)
6. **Check Transaction History** (Both transaction lists)

## Security Features

### Database Security

- **SECURITY DEFINER**: Functions run with elevated privileges
- **Input Validation**: All parameters validated
- **SQL Injection Protection**: Parameterized queries
- **Transaction Atomicity**: ACID compliance

### Business Logic Security

- **Balance Validation**: Prevents overdrafts
- **Wallet Validation**: Ensures wallet existence and status
- **Authorization**: Only approved users can process payments
- **Audit Trail**: Complete transaction logging

## Troubleshooting

### Common Issues

1. **Foreign Key Errors**: Run wallet synchronization
2. **Balance Mismatches**: Check transaction history
3. **Missing Transactions**: Verify trigger functionality
4. **UI Validation Errors**: Check service connectivity

### Diagnostic Queries

```sql
-- Check wallet synchronization
SELECT ew.id, ew.wallet_name, pa.account_holder_name
FROM electronic_wallets ew
LEFT JOIN payment_accounts pa ON ew.id = pa.id;

-- Verify transaction linking
SELECT ep.id, wt.id, ewt.id
FROM electronic_payments ep
LEFT JOIN wallet_transactions wt ON ep.id::TEXT = wt.reference_id
LEFT JOIN electronic_wallet_transactions ewt ON ep.id::TEXT = ewt.payment_id
WHERE ep.status = 'approved';
```

## Future Enhancements

### Planned Features

1. **Multi-Currency Support**: Handle different currencies
2. **Transaction Fees**: Automatic fee calculation
3. **Batch Processing**: Multiple payment approvals
4. **Advanced Reporting**: Detailed financial reports
5. **Real-time Notifications**: Balance alerts and updates

### Performance Optimizations

1. **Database Indexing**: Optimize query performance
2. **Caching**: Cache balance information
3. **Async Processing**: Background transaction processing
4. **Connection Pooling**: Optimize database connections

## Conclusion

The Dual Wallet System provides a robust, secure, and auditable solution for electronic payment processing. It ensures proper money transfer, maintains accounting integrity, and provides comprehensive transaction tracking while delivering an excellent user experience with real-time balance validation and Arabic language support.
