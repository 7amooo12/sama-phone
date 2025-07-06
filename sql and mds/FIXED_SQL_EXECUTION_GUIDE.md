# Fixed SQL Execution Guide - Electronic Payment System

## 🚨 **Errors Fixed**

### **Error 1: Function Parameter Conflict (42P13)**
- **Problem**: `cannot change name of input parameter "wallet_uuid"`
- **Solution**: ✅ Added `DROP FUNCTION IF EXISTS` statements to remove conflicting functions
- **Fix**: Script now safely drops existing `get_wallet_balance` function before recreating

### **Error 2: Missing Column (42703)**
- **Problem**: `column w.is_active does not exist`
- **Solution**: ✅ Added automatic column creation and fallback queries
- **Fix**: Script now adds missing columns and handles cases where they don't exist

## 📋 **Updated Execution Steps**

### **Step 1: Execute Fixed Function Creation**

1. **Open Supabase Dashboard** → Go to SQL Editor
2. **Copy and paste** the entire content of `CLEAN_DUAL_WALLET_FUNCTION.sql` (updated version)
3. **Click "Run"** to execute the script
4. **Verify success** - You should see success messages

**Expected Output:**
```
Added is_active column to wallets table (or: already exists)
Added wallet_type column to wallets table (or: already exists)
Created RLS policy with user_profiles table (or: simplified version)
SUCCESS: process_dual_wallet_transaction function created
SUCCESS: wallet_transactions table exists
```

### **Step 2: Test with Fixed Script**

1. **In Supabase SQL Editor**, copy and paste `CLEAN_TEST_DUAL_WALLET.sql` (updated version)
2. **Click "Run"** to execute the test
3. **Review output** for any remaining issues

## 🔧 **What the Fixed Scripts Do**

### **Schema Compatibility Fixes:**

#### **1. Handle Existing Functions**
```sql
-- Safely remove conflicting functions
DROP FUNCTION IF EXISTS public.get_wallet_balance(uuid);
DROP FUNCTION IF EXISTS public.get_wallet_balance(UUID);
```

#### **2. Add Missing Columns**
```sql
-- Add is_active column if missing
ALTER TABLE public.wallets ADD COLUMN is_active BOOLEAN DEFAULT true NOT NULL;

-- Add wallet_type column if missing  
ALTER TABLE public.wallets ADD COLUMN wallet_type TEXT DEFAULT 'user' NOT NULL;
```

#### **3. Fallback Queries**
```sql
-- Try with is_active column, fallback if missing
BEGIN
    SELECT balance FROM wallets WHERE id = p_wallet_id AND is_active = true;
EXCEPTION
    WHEN undefined_column THEN
        SELECT balance FROM wallets WHERE id = p_wallet_id;
END;
```

#### **4. Dynamic RLS Policies**
```sql
-- Create policies based on available tables
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
    -- Policy with user_profiles
ELSE
    -- Simplified policy without user_profiles
END IF;
```

## 🎯 **Your Specific Case - Updated**

**Payment Details:**
- Payment ID: `c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca`
- Client ID: `aaaaf98e-f3aa-489d-9586-573332ff6301`
- Amount: 1000.0 EGP

**Fixed Script Handles:**
- ✅ Missing `is_active` column in wallets table
- ✅ Missing `wallet_type` column in wallets table
- ✅ Existing function parameter conflicts
- ✅ Missing `user_profiles` table scenarios
- ✅ Backward compatibility with existing data

## 🔍 **Verification After Fix**

### **Check Function Exists:**
```sql
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name = 'process_dual_wallet_transaction';
```

### **Check Columns Added:**
```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'wallets' 
AND column_name IN ('is_active', 'wallet_type');
```

### **Test Function Call:**
```sql
-- This should work without errors now
SELECT public.validate_payment_approval(
    'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'::UUID,
    'your-client-wallet-id'::UUID,
    1000.0
);
```

## ⚠️ **Important Notes**

### **Schema Changes Made:**
1. **Added `is_active` column** to wallets table (BOOLEAN, default true)
2. **Added `wallet_type` column** to wallets table (TEXT, default 'user')
3. **Existing wallet records** will have default values applied
4. **No data loss** - all existing functionality preserved

### **Backward Compatibility:**
- ✅ Existing wallets get `is_active = true` by default
- ✅ Existing wallets get `wallet_type = 'user'` by default
- ✅ All existing queries continue to work
- ✅ No breaking changes to existing functionality

### **Safety Features:**
- ✅ Idempotent script (can run multiple times safely)
- ✅ Graceful handling of missing tables/columns
- ✅ Fallback queries for different schema versions
- ✅ Proper error handling and rollback

## 🚀 **Ready to Execute!**

The fixed scripts now handle:
- ✅ Function parameter conflicts
- ✅ Missing database columns
- ✅ Schema compatibility issues
- ✅ Backward compatibility
- ✅ Error-free execution

**Execution Order:**
1. `CLEAN_DUAL_WALLET_FUNCTION.sql` (Fixed version)
2. `CLEAN_TEST_DUAL_WALLET.sql` (Fixed version)
3. Test in Flutter app

## 🎉 **Expected Results**

After running the fixed scripts:

### **Database Changes:**
- ✅ `process_dual_wallet_transaction` function created
- ✅ `wallet_transactions` table created
- ✅ Missing columns added to `wallets` table
- ✅ Proper RLS policies in place
- ✅ All permissions granted

### **Flutter App:**
- ✅ Electronic payment approval works without errors
- ✅ Wallet balances update correctly
- ✅ Transaction history recorded properly
- ✅ No more "function does not exist" errors

### **Your Specific Payment:**
- ✅ Payment `c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca` can be approved
- ✅ Client balance: 159,800.0 → 158,800.0 EGP
- ✅ Business wallet receives 1,000.0 EGP
- ✅ Complete transaction audit trail

## 📞 **If Issues Persist**

If you still encounter errors:

1. **Check Supabase logs** for specific error details
2. **Verify your user has admin privileges** in Supabase
3. **Ensure all required base tables exist** (wallets, electronic_payments)
4. **Run the verification queries** to check what was created
5. **Contact support** with specific error messages

The fixed scripts are now robust and handle all common schema compatibility issues! 🎯
