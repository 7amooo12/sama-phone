# Electronic Payment Constraint Fix Guide

## Problem Summary

The electronic payment system was failing with a PostgreSQL check constraint violation:

```
PostgrestException: Dual wallet transaction failed: Transaction failed during wallet updates: new row for relation "wallet_transactions" violates check constraint "wallet_transactions_reference_type_valid"
```

## Root Cause Analysis

The issue was caused by a **database constraint mismatch**:

1. **Database Function**: The `process_dual_wallet_transaction` function correctly uses `'electronic_payment'` as the `reference_type` when creating wallet transactions.

2. **Database Constraint**: The `wallet_transactions_reference_type_valid` constraint was not updated to include `'electronic_payment'` as a valid value.

3. **Migration Gap**: While the electronic payment system migration intended to add `'electronic_payment'` to the constraint, there was a mismatch between different schema definitions.

## Files Modified

### 1. Database Migration
- **File**: `supabase/migrations/20241221000000_fix_wallet_transactions_constraint.sql`
- **Purpose**: Fixes the database constraint to include `'electronic_payment'` as a valid reference_type

### 2. Service Layer Enhancement
- **File**: `lib/services/electronic_payment_service.dart`
- **Changes**:
  - Enhanced error handling for constraint violations
  - Added specific error messages for reference_type constraint issues
  - Improved logging for debugging constraint violations
  - Added parameter validation before calling database functions

### 3. Test Script
- **File**: `TEST_ELECTRONIC_PAYMENT_CONSTRAINT_FIX.sql`
- **Purpose**: Comprehensive testing to verify the constraint fix works correctly

## Technical Details

### Valid Reference Types
After the fix, the `wallet_transactions_reference_type_valid` constraint allows these values:
- `'order'` - Order-related transactions
- `'task'` - Task-related transactions  
- `'reward'` - Reward transactions
- `'salary'` - Salary payments
- `'manual'` - Manual adjustments
- `'transfer'` - Transfer transactions
- `'electronic_payment'` - Electronic payment transactions ✅ **ADDED**

### Database Function Behavior
The `process_dual_wallet_transaction` function creates two wallet transactions:
1. **Client Transaction**: `transaction_type='debit'`, `reference_type='electronic_payment'`
2. **Business Transaction**: `transaction_type='credit'`, `reference_type='electronic_payment'`

## Implementation Steps

### Step 1: Run Database Migration
```sql
-- Execute the migration script
\i supabase/migrations/20241221000000_fix_wallet_transactions_constraint.sql
```

### Step 2: Verify Fix
```sql
-- Run the test script to verify everything works
\i TEST_ELECTRONIC_PAYMENT_CONSTRAINT_FIX.sql
```

### Step 3: Test Electronic Payment Approval
1. Open the Flutter app
2. Navigate to electronic payments
3. Try to approve payment ID: `c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca`
4. Verify it completes without constraint violations

## Error Handling Improvements

### Before Fix
```
Generic error: "حدث خطأ غير متوقع"
```

### After Fix
```
Specific error: "خطأ في قاعدة البيانات: نوع المرجع غير صالح. يرجى الاتصال بالدعم الفني لتحديث قاعدة البيانات."
```

## Migration Safety Features

The migration script includes several safety features:

1. **Data Backup**: Creates backup table for any invalid reference_type values
2. **Intelligent Cleanup**: Maps invalid values to appropriate valid ones
3. **Validation**: Ensures no invalid data remains before applying constraint
4. **Rollback Safety**: Can be safely rolled back if needed
5. **Comprehensive Testing**: Built-in tests verify the fix works

## Monitoring and Debugging

### Log Messages to Watch For
- ✅ `"Dual wallet transaction completed successfully"`
- ❌ `"Database constraint violation detected"`
- ⚠️ `"wallet_transactions_reference_type_valid"`

### Database Queries for Monitoring
```sql
-- Check constraint status
SELECT pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'public.wallet_transactions'::regclass 
AND conname = 'wallet_transactions_reference_type_valid';

-- Count electronic payment transactions
SELECT COUNT(*) 
FROM wallet_transactions 
WHERE reference_type = 'electronic_payment';

-- Check for any invalid reference types
SELECT reference_type, COUNT(*) 
FROM wallet_transactions 
WHERE reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
AND reference_type IS NOT NULL
GROUP BY reference_type;
```

## Success Criteria

✅ **Payment approvals complete without constraint violations**
✅ **Wallet transactions created with valid reference types**
✅ **Error messages are user-friendly and informative**
✅ **No regression in existing payment functionality**
✅ **Database constraints respected at application level**

## Rollback Plan

If issues occur, the fix can be rolled back:

```sql
-- Rollback: Remove electronic_payment from constraint
ALTER TABLE public.wallet_transactions
DROP CONSTRAINT wallet_transactions_reference_type_valid;

ALTER TABLE public.wallet_transactions
ADD CONSTRAINT wallet_transactions_reference_type_valid CHECK (
    reference_type IS NULL OR reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer')
);
```

## Future Considerations

1. **Schema Versioning**: Ensure all schema files are kept in sync
2. **Migration Testing**: Test migrations on staging before production
3. **Constraint Documentation**: Document all constraint changes
4. **Automated Testing**: Add automated tests for constraint compliance

## Contact

For questions or issues related to this fix, contact the development team with:
- Payment ID that failed
- Full error message
- Timestamp of the error
- User ID attempting the approval
