# 🔧 Wallet-UserProfile Relationship Fix Instructions

## Problem Summary
The SmartBizTracker application was encountering a PostgreSQL relationship error:
- **Error Code:** PGRST200
- **Message:** "Could not find a relationship between 'wallets' and 'user_profiles' in the schema cache"

## Root Cause
The `wallets` table had a foreign key to `auth.users(id)` but no direct relationship to `user_profiles` table. PostgREST requires direct foreign key relationships for automatic joins.

## Solution Implemented

### 1. Database Migration
**File:** `supabase/migrations/20250625000000_fix_wallet_user_profile_relationship.sql`

**Key Changes:**
- Added `user_profile_id` column to `wallets` table
- Created direct foreign key relationship: `wallets.user_profile_id → user_profiles.id`
- Added consistency constraint: `user_id = user_profile_id`
- Updated wallet creation trigger
- Added validation and fix functions

### 2. Service Layer Updates
**File:** `lib/services/wallet_service.dart`

**Changes:**
- Updated `getWalletsByRole()` to use new relationship: `user_profiles!user_profile_id(...)`
- Added fallback method `_getWalletsByRoleFallback()` using separate queries
- Enhanced error handling with automatic fallback

### 3. Provider Layer Updates
**File:** `lib/providers/wallet_provider.dart`

**Changes:**
- Improved error handling for relationship issues
- Added specific error messages for PGRST200 errors

## How to Apply the Fix

### Step 1: Run the Database Migration
```bash
# Navigate to your Supabase project
cd supabase

# Apply the migration
supabase db push

# Or if using Supabase CLI with remote database
supabase db push --db-url "your-database-url"
```

### Step 2: Verify Migration Success
Run this SQL query in your Supabase dashboard:
```sql
-- Check if the relationship was created successfully
SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'wallets'
    AND kcu.column_name = 'user_profile_id';
```

### Step 3: Validate Wallet Relationships
```sql
-- Run the validation function
SELECT * FROM validate_wallet_relationships();

-- If issues found, run the fix function
SELECT * FROM fix_wallet_relationships();
```

### Step 4: Test the Application
1. Restart your Flutter application
2. Navigate to wallet-related screens
3. Check that wallets load correctly by role
4. Verify no PGRST200 errors in logs

## Fallback Mechanism
If the direct relationship approach still fails, the service automatically falls back to:
1. Separate queries for user_profiles and wallets
2. Manual data joining in the application layer
3. Same functionality with slightly different performance characteristics

## Verification Checklist
- [ ] Migration applied successfully
- [ ] `user_profile_id` column exists in `wallets` table
- [ ] Foreign key constraint created
- [ ] Wallet relationships validated
- [ ] Application loads wallets without errors
- [ ] Role-based filtering works correctly

## Troubleshooting

### If Migration Fails
1. Check if `user_profiles` table exists
2. Ensure all existing wallets have corresponding user_profiles
3. Run the validation function to identify issues

### If Relationship Still Doesn't Work
The fallback mechanism will automatically activate, providing the same functionality through separate queries.

### Common Issues
1. **Missing user_profiles:** Some wallets may reference users without profiles
2. **Inconsistent data:** user_id and user_profile_id don't match
3. **Permission issues:** RLS policies may need adjustment

## Performance Impact
- **Positive:** Direct relationships improve query performance
- **Minimal:** Fallback approach has slightly more overhead but maintains functionality
- **Indexes:** Added indexes on `user_profile_id` for optimal performance

## Future Maintenance
- The migration includes validation functions for ongoing maintenance
- Run `validate_wallet_relationships()` periodically to ensure data integrity
- Use `fix_wallet_relationships()` to automatically resolve issues
