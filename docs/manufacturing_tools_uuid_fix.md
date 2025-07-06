# SmartBizTracker Manufacturing Tools UUID Fix

## Overview
This document outlines the fixes applied to resolve PostgreSQL foreign key constraint errors in the SmartBizTracker Manufacturing Tools database schema. The primary issue was a type mismatch between user reference columns (INTEGER) and the existing `user_profiles.id` column (UUID).

## Problem Description
The original schema had foreign key constraints that referenced `user_profiles(id)` using INTEGER columns, but the SmartBizTracker system uses UUID for user identifiers. This caused foreign key constraint violations when trying to create the tables.

### Error Example
```sql
ERROR: foreign key constraint "manufacturing_tools_created_by_fkey" cannot be implemented
DETAIL: Key columns "created_by" and "id" are of incompatible types: integer and uuid.
```

## Changes Made

### 1. Database Schema Updates (`sql/manufacturing_tools_schema.sql`)

#### Table Column Type Changes
- **manufacturing_tools.created_by**: `INTEGER` → `UUID`
- **production_recipes.created_by**: `INTEGER` → `UUID`
- **production_batches.warehouse_manager_id**: `INTEGER` → `UUID`
- **tool_usage_history.warehouse_manager_id**: `INTEGER` → `UUID`

#### SECURITY DEFINER Function Updates
Updated all functions to handle UUID parameters correctly:

1. **get_manufacturing_tools()**: Updated return type for `created_by` column
2. **add_manufacturing_tool()**: 
   - Parameter `p_created_by` changed from `INTEGER` to `UUID`
   - Variable `v_user_id` changed from `INTEGER` to `UUID`
   - Removed `::INTEGER` cast from `auth.uid()`
3. **update_tool_quantity()**: 
   - Variable `v_user_id` changed from `INTEGER` to `UUID`
   - Removed `::INTEGER` cast from `auth.uid()`
4. **create_production_recipe()**: 
   - Variable `v_user_id` changed from `INTEGER` to `UUID`
   - Removed `::INTEGER` cast from `auth.uid()`
5. **complete_production_batch()**: 
   - Variable `v_user_id` changed from `INTEGER` to `UUID`
   - Removed `::INTEGER` cast from `auth.uid()`

#### Grant Permissions Update
Updated function signature in GRANT statement:
```sql
GRANT EXECUTE ON FUNCTION add_manufacturing_tool(VARCHAR(100), DECIMAL(10,2), VARCHAR(20), VARCHAR(50), VARCHAR(50), TEXT, UUID) TO authenticated;
```

#### Sample Data Changes
Commented out sample data insertion since it requires valid user UUIDs. Added instructions for manual insertion with proper UUID values.

### 2. Dart Model Updates

#### ManufacturingTool Model (`lib/models/manufacturing/manufacturing_tool.dart`)
- Changed `createdBy` field type from `int?` to `String?`
- Updated JSON parsing to handle UUID as string
- Updated copyWith method parameter type

#### Other Models
- **ProductionBatch**: No changes needed (only stores manager name, not ID)
- **ToolUsageHistory**: No changes needed (only stores manager name, not ID)

### 3. Service Layer
No changes required in service classes as they use RPC calls which handle type conversion automatically.

## Testing

### Test Script (`sql/test_manufacturing_schema.sql`)
Created comprehensive test script that verifies:
1. Table creation and existence
2. Column data types (UUID verification)
3. Foreign key constraints
4. SECURITY DEFINER function existence
5. Function execution with mock data
6. Index creation

### Running Tests
Execute the test script in your Supabase SQL Editor:
```sql
\i sql/test_manufacturing_schema.sql
```

## Deployment Instructions

### 1. Database Schema Deployment
1. **Backup existing data** (if any manufacturing tools data exists)
2. **Drop existing tables** (if they exist with wrong types):
   ```sql
   DROP TABLE IF EXISTS tool_usage_history CASCADE;
   DROP TABLE IF EXISTS production_batches CASCADE;
   DROP TABLE IF EXISTS production_recipes CASCADE;
   DROP TABLE IF EXISTS manufacturing_tools CASCADE;
   ```
3. **Execute the updated schema**:
   ```sql
   \i sql/manufacturing_tools_schema.sql
   ```
4. **Run the test script** to verify everything works:
   ```sql
   \i sql/test_manufacturing_schema.sql
   ```

### 2. Application Deployment
1. **Update Dart dependencies** (if needed)
2. **Deploy updated models** to your Flutter application
3. **Test the manufacturing tools functionality** in the app

### 3. Data Migration (if needed)
If you have existing manufacturing tools data with integer user IDs:
```sql
-- Example migration script (adjust as needed)
-- This assumes you have a mapping between old integer IDs and new UUIDs
UPDATE manufacturing_tools 
SET created_by = (
    SELECT id FROM user_profiles 
    WHERE old_integer_id = manufacturing_tools.created_by
);
```

## Verification Checklist

- [ ] All tables created without foreign key constraint errors
- [ ] All SECURITY DEFINER functions execute successfully
- [ ] UUID foreign key constraints properly reference user_profiles(id)
- [ ] Dart models handle UUID strings correctly
- [ ] Manufacturing tools can be created through the Flutter app
- [ ] Production workflows function correctly
- [ ] User authentication and authorization work with UUID references

## Benefits of This Fix

1. **Data Integrity**: Proper foreign key constraints ensure referential integrity
2. **Compatibility**: Full compatibility with existing SmartBizTracker user management
3. **Security**: SECURITY DEFINER functions maintain proper authorization
4. **Performance**: Proper indexing on UUID columns for optimal query performance
5. **Scalability**: UUID-based references support distributed systems better

## Future Considerations

1. **UUID Generation**: Ensure proper UUID generation in the application layer
2. **Performance Monitoring**: Monitor query performance with UUID joins
3. **Backup Strategy**: Include UUID mappings in backup/restore procedures
4. **Documentation**: Keep this documentation updated with any future schema changes

## Support

For issues related to this fix:
1. Check the test script output for specific error messages
2. Verify user_profiles table exists and contains valid UUID data
3. Ensure proper permissions are granted to the application user
4. Review Supabase logs for detailed error information
