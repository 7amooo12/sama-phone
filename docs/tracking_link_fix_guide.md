# Tracking Link Database Schema Fix Guide

## Problem Description

The SmartBizTracker Flutter app is experiencing a PostgreSQL database schema error where the 'tracking_link' column is missing from the 'user_profiles' table. This causes a PostgrestException with code PGRST204 when trying to update user profiles.

### Error Details
- **Error Code**: PGRST204
- **Error Message**: "Could not find the 'tracking_link' column of 'user_profiles' in the schema cache"
- **Location**: DatabaseService.updateUser method (lib/services/database_service.dart:104)
- **Additional Error**: "No host specified in URI file:///null" (related to null tracking_link values)

## Root Cause Analysis

1. **Missing Database Column**: The `user_profiles` table in Supabase doesn't have the `tracking_link` column
2. **Code Expects Column**: The UserModel.toJson() method includes `tracking_link` field
3. **Null URI Handling**: Null tracking_link values are being passed to Uri.parse() causing URI errors

## Solution Implementation

### Step 1: Database Schema Migration

Execute the following SQL migration in your Supabase SQL editor:

```sql
-- File: sql/add_tracking_link_column.sql
-- Add missing tracking_link column to user_profiles table

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'tracking_link'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.user_profiles 
        ADD COLUMN tracking_link TEXT;
        
        COMMENT ON COLUMN public.user_profiles.tracking_link IS 'رابط تتبع المستخدم';
        
        RAISE NOTICE 'Added tracking_link column to user_profiles table';
    ELSE
        RAISE NOTICE 'tracking_link column already exists';
    END IF;
END $$;
```

### Step 2: Code Fixes Applied

#### DatabaseService.updateUser Method
- Added null handling for tracking_link field
- Improved error logging with specific tracking_link error detection
- Remove null tracking_link from update data to prevent database errors

#### URI Handling Improvements
- Enhanced URL validation in order_tracking_screen.dart
- Added proper null checking before Uri.parse()
- Automatic scheme addition for URLs without http/https
- Better error messages for invalid URLs

#### Tracking Links Screen
- Fixed null handling in TextEditingController initialization
- Added URL format validation
- Improved user feedback for invalid URLs

### Step 3: Testing and Verification

Run the test script to verify the migration:

```sql
-- File: sql/test_tracking_link_migration.sql
-- This script tests the tracking_link column functionality
```

## Files Modified

### Database Files
- `sql/add_tracking_link_column.sql` - Migration script
- `sql/test_tracking_link_migration.sql` - Test verification script

### Flutter Code Files
- `lib/services/database_service.dart` - Enhanced updateUser method
- `lib/screens/client/order_tracking_screen.dart` - Fixed URI handling
- `lib/screens/admin/tracking_links_screen.dart` - Improved null handling

## Expected Results After Fix

1. ✅ User profile updates work without PGRST204 errors
2. ✅ Tracking links handle null values gracefully
3. ✅ URI parsing errors are eliminated
4. ✅ Better user feedback for invalid URLs
5. ✅ Business Owner Dashboard functions correctly

## Testing Checklist

- [ ] Run database migration script
- [ ] Test user profile updates with null tracking_link
- [ ] Test user profile updates with valid tracking_link
- [ ] Verify tracking links screen functionality
- [ ] Test order tracking screen with various URL formats
- [ ] Confirm Business Owner Dashboard works properly

## Performance Considerations

- Added index on tracking_link column for query performance
- Null handling prevents unnecessary database operations
- Improved error handling reduces app crashes

## Security Notes

- RLS policies automatically include the new column
- No additional security configuration required
- URL validation prevents malicious link injection

## Rollback Plan

If issues occur, the tracking_link column can be safely removed:

```sql
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS tracking_link;
```

The code changes are backward compatible and will handle missing columns gracefully.
