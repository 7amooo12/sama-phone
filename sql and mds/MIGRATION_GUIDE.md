# Electronic Payment System Migration Guide

## Overview
This guide provides step-by-step instructions for safely migrating your SmartBizTracker database to include the electronic payment system while handling existing data conflicts.

## Pre-Migration Steps

### 1. Backup Your Database
**CRITICAL**: Always backup your database before running migrations.

```sql
-- Create a full backup of your database
-- Run this in your Supabase SQL Editor or via pg_dump
```

### 2. Diagnose Existing Data
Run the diagnostic script to identify any problematic data:

```sql
-- Run this file first to see what data needs to be cleaned up
-- File: 20241220000000_diagnose_wallet_data.sql
```

This will show you:
- Current constraint status
- All reference_type values in your wallet_transactions table
- Which values are invalid and will be cleaned up
- Sample rows that will be affected

## Migration Process

### Step 1: Run the Main Migration
Execute the electronic payment system migration:

```sql
-- File: 20241220000000_create_electronic_payment_system.sql
```

**What this migration does:**
1. **Pre-Migration Validation**: Checks that wallet system exists
2. **Creates Tables**: payment_accounts and electronic_payments tables
3. **Data Cleanup**: Intelligently maps invalid reference_type values:
   - Values containing "order" or "purchase" → "order"
   - Values containing "task" or "work" → "task"
   - Values containing "reward" or "bonus" → "reward"
   - Values containing "salary", "wage", or "pay" → "salary"
   - Values containing "transfer" or "move" → "transfer"
   - All other values → "manual"
4. **Creates Backup**: Saves original values in `wallet_transactions_reference_type_backup` table
5. **Updates Constraint**: Adds "electronic_payment" to allowed reference_type values
6. **Creates RLS Policies**: Secure access control for new tables
7. **Creates Functions/Triggers**: Integration with existing wallet system
8. **Verification**: Ensures everything was created successfully

### Step 2: Create Storage Bucket
Run the storage bucket creation script:

```sql
-- File: 20241220000001_create_payment_proofs_bucket.sql
```

### Step 3: Run Verification Tests
Execute the verification script to ensure everything works:

```sql
-- File: 20241220000002_verify_electronic_payment_integration.sql
```

## Expected Migration Output

### Successful Migration Messages
You should see messages like:
```
✅ Wallet system prerequisites verified.
🔍 Analyzing existing wallet_transactions data...
⚠️  Found X rows with invalid reference_type values that need cleanup
📋 Invalid reference_type values found: [list of values]
💾 Created backup table with X rows for audit trail
🔄 Mapped "invalid_value" to "appropriate_type"
✅ Successfully cleaned up X rows with invalid reference_type values
🎉 Data cleanup completed successfully - all reference_type values are now valid
🗑️  Dropped existing reference_type constraint
✅ Successfully created reference_type constraint with electronic_payment support
✅ Electronic Payment System Migration Completed Successfully!
```

### Error Handling
If you encounter errors:

1. **Constraint Violation Error**: The migration includes comprehensive data cleanup that should prevent this
2. **Policy Already Exists Error**: The migration handles this by dropping existing policies first
3. **Function Creation Error**: Check the error message and ensure wallet system is properly installed

## Post-Migration Verification

### 1. Check Tables Were Created
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_name IN ('payment_accounts', 'electronic_payments') 
AND table_schema = 'public';
```

### 2. Verify Constraint Update
```sql
SELECT pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conname = 'wallet_transactions_reference_type_valid';
```

Should include 'electronic_payment' in the allowed values.

### 3. Check Data Cleanup
```sql
-- View the backup of original data
SELECT * FROM public.wallet_transactions_reference_type_backup LIMIT 10;

-- Verify no invalid reference_type values remain
SELECT DISTINCT reference_type FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL;
```

### 4. Test Electronic Payment Flow
```sql
-- File: 20241220000003_test_electronic_payment_migration.sql
```

## Rollback Procedure

If you need to rollback the migration:

```sql
-- File: 20241220000001_rollback_electronic_payment_system.sql
```

**WARNING**: This will:
- Remove all electronic payment data
- Restore original reference_type values from backup
- Remove electronic payment tables, functions, and triggers
- Restore original constraint without 'electronic_payment'

## Troubleshooting

### Common Issues

1. **"wallet_transactions table does not exist"**
   - Solution: Run wallet system migration first (20241215000000_create_wallet_system.sql)

2. **"Still found X rows with invalid reference_type"**
   - Solution: Check the diagnostic output and manually fix any unexpected reference_type values

3. **"Policy already exists"**
   - Solution: The migration handles this automatically, but you can manually drop policies if needed

4. **"Function was not created successfully"**
   - Solution: Check for syntax errors or missing dependencies

### Manual Data Cleanup (if needed)
If the automatic cleanup doesn't handle your specific data:

```sql
-- Find problematic values
SELECT DISTINCT reference_type, COUNT(*) 
FROM public.wallet_transactions 
WHERE reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
AND reference_type IS NOT NULL
GROUP BY reference_type;

-- Manually update specific values
UPDATE public.wallet_transactions 
SET reference_type = 'manual' 
WHERE reference_type = 'your_specific_invalid_value';
```

## Support

If you encounter issues not covered in this guide:

1. Check the diagnostic script output for specific data issues
2. Review the migration logs for detailed error messages
3. Use the rollback script if you need to revert changes
4. Ensure all prerequisites (wallet system) are properly installed

## Next Steps

After successful migration:

1. Update your Flutter application to use the new electronic payment features
2. Configure real payment account details in the payment_accounts table
3. Test the complete payment flow from Flutter app to database
4. Train users on the new electronic payment functionality
