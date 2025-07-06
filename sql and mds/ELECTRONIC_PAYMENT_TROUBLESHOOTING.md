# Electronic Payment System Troubleshooting Guide

## 🚨 Quick Fix for Missing Tables Error

If you're getting `42P01: relation "public.electronic_payments" does not exist` errors, follow these steps:

### Step 1: Run the Clean Migration Script

1. Open your **Supabase Dashboard**
2. Go to **SQL Editor**
3. Copy and paste the contents of `ELECTRONIC_PAYMENT_MIGRATION_CLEAN.sql`
4. Click **Run** to execute the script

### Step 2: Verify the Migration

1. In the same SQL Editor, copy and paste the contents of `TEST_ELECTRONIC_PAYMENT_TABLES.sql`
2. Click **Run** to verify everything is working
3. Look for "🚀 SYSTEM READY" in the results

### Step 3: Test Your Flutter App

1. Restart your Flutter app
2. Try accessing the electronic payment features
3. The errors should be resolved

---

## 🔍 Common Issues and Solutions

### Issue 1: SQL Syntax Error at "IF NOT EXISTS"

**Error**: `42601: syntax error at or near "NOT"`

**Cause**: PostgreSQL doesn't support `IF NOT EXISTS` for `CREATE POLICY` statements.

**Solution**: Use the clean migration script which properly handles policy creation.

### Issue 2: Dart Import Statements in SQL

**Error**: `42601: syntax error at or near "'package:supabase_flutter/supabase_flutter.dart'"`

**Cause**: Dart/Flutter code was accidentally included in the SQL file.

**Solution**: Ensure you're only running pure SQL statements in the Supabase SQL Editor.

### Issue 3: Permission Denied Errors

**Error**: `permission denied for table electronic_payments`

**Possible Causes**:
- RLS policies not properly configured
- User doesn't have the required role
- User profile not properly set up

**Solutions**:
1. Check if your user has the correct role in `user_profiles` table
2. Verify RLS policies are created correctly
3. Ensure your user is authenticated

### Issue 4: Foreign Key Constraint Errors

**Error**: `violates foreign key constraint`

**Cause**: Referenced tables or records don't exist.

**Solutions**:
1. Ensure `user_profiles` table exists and has proper data
2. Check that payment accounts exist before creating payments
3. Verify user IDs are valid UUIDs

---

## 🛠️ Manual Verification Steps

### Check if Tables Exist

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('payment_accounts', 'electronic_payments');
```

Expected result: Both tables should be listed.

### Check RLS is Enabled

```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('payment_accounts', 'electronic_payments')
AND schemaname = 'public';
```

Expected result: `rowsecurity` should be `true` for both tables.

### Check Default Payment Accounts

```sql
SELECT * FROM public.payment_accounts;
```

Expected result: At least 2 records (Vodafone Cash and InstaPay accounts).

### Test Basic Permissions

```sql
-- This should work if you're authenticated
SELECT COUNT(*) FROM public.payment_accounts WHERE is_active = true;
```

---

## 🔧 Advanced Troubleshooting

### Reset Electronic Payment System

If you need to completely reset the system:

```sql
-- WARNING: This will delete all payment data
DROP TABLE IF EXISTS public.electronic_payments CASCADE;
DROP TABLE IF EXISTS public.payment_accounts CASCADE;

-- Then re-run the migration script
```

### Check User Profile Setup

```sql
-- Verify your user profile exists and has correct role
SELECT 
    user_id,
    role,
    status,
    name,
    email
FROM public.user_profiles 
WHERE user_id = auth.uid();
```

### Debug RLS Policies

```sql
-- Check all policies for electronic payment tables
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    roles
FROM pg_policies 
WHERE tablename IN ('payment_accounts', 'electronic_payments');
```

---

## 📱 Flutter App Integration

### Update Service Calls

After running the migration, ensure your Flutter app services are properly configured:

1. **ElectronicPaymentService**: Should now work without table errors
2. **ElectronicPaymentProvider**: Should be able to fetch data
3. **Payment screens**: Should load without database errors

### Test the Diagnostic Screen

Use the diagnostic screen to verify everything is working:

```dart
// Navigate to diagnostic screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ElectronicPaymentDiagnosticScreen(),
  ),
);
```

---

## 🆘 Still Having Issues?

### Check These Common Problems:

1. **Authentication**: Ensure you're logged in with a valid user
2. **User Role**: Verify your user has admin/client role in user_profiles
3. **Network**: Check your internet connection to Supabase
4. **Supabase URL**: Verify your Supabase URL and anon key are correct

### Debug Steps:

1. **Enable Verbose Logging**: Check Flutter console for detailed error messages
2. **Check Supabase Logs**: Look at Supabase dashboard logs for server-side errors
3. **Test with Different Users**: Try with admin vs client accounts
4. **Verify Database State**: Use the test script to check database state

### Get Help:

If you're still experiencing issues:

1. Run the test script and copy the results
2. Check Flutter console logs for specific error messages
3. Verify your Supabase project settings
4. Ensure all required tables and policies are in place

---

## ✅ Success Indicators

You'll know the system is working when:

- ✅ No "table does not exist" errors in Flutter logs
- ✅ Electronic payment screens load without errors
- ✅ Payment accounts can be fetched successfully
- ✅ Payment statistics load correctly
- ✅ Diagnostic screen shows all green checkmarks

---

## 📋 Migration Checklist

- [ ] Ran `ELECTRONIC_PAYMENT_MIGRATION_CLEAN.sql`
- [ ] Verified with `TEST_ELECTRONIC_PAYMENT_TABLES.sql`
- [ ] Restarted Flutter app
- [ ] Tested electronic payment features
- [ ] Confirmed no database errors in logs
- [ ] Verified user can access payment accounts
- [ ] Tested payment creation (if applicable)

---

*Last updated: January 2025*
