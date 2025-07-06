# Biometric Attendance System Migration Guide

## Overview
This guide provides step-by-step instructions for applying the biometric location attendance migration to your SmartBizTracker Supabase database.

## Pre-Migration Steps

### 1. Backup Your Database
**CRITICAL**: Always backup your database before running migrations.

### 2. Verify Prerequisites
Ensure the following tables exist (from previous QR attendance migration):
- `worker_attendance_profiles`
- `worker_attendance_records` 
- `qr_nonce_history`
- `attendance_type_enum` type

## Migration Execution

### Option 1: Supabase Dashboard (Recommended)

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to **SQL Editor**

2. **Execute the Migration**
   - Copy the entire content from `database/migrations/add_biometric_location_attendance.sql`
   - Paste it into the SQL Editor
   - Click **Run** to execute

3. **Verify Migration Success**
   - Check that `warehouse_location_settings` table was created
   - Verify new columns were added to `worker_attendance_records`:
     - `latitude`, `longitude`
     - `location_validated`, `distance_from_warehouse`
     - `location_accuracy`, `attendance_method`
     - `biometric_verified`

### Option 2: Supabase CLI (If Available)

```bash
# Navigate to project root
cd /path/to/smartbiztracker_new

# Apply the migration
supabase db push
```

## Post-Migration Verification

### 1. Test Database Functions
Run this SQL to verify functions were created:

```sql
-- Check if functions exist
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN (
    'process_biometric_attendance',
    'get_location_attendance_stats',
    'validate_warehouse_location'
);
```

### 2. Test Table Structure
```sql
-- Verify warehouse_location_settings table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'warehouse_location_settings';

-- Verify new columns in worker_attendance_records
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'worker_attendance_records' 
AND column_name IN ('latitude', 'longitude', 'location_validated', 'attendance_method', 'biometric_verified');
```

### 3. Test Default Warehouse Location
```sql
-- Check if default warehouse location was created
SELECT warehouse_name, latitude, longitude, geofence_radius, is_active 
FROM warehouse_location_settings;
```

## Configuration Steps

### 1. Configure Warehouse Location
Update the default warehouse location with your actual coordinates:

```sql
UPDATE warehouse_location_settings 
SET 
    latitude = YOUR_WAREHOUSE_LATITUDE,
    longitude = YOUR_WAREHOUSE_LONGITUDE,
    geofence_radius = 500.0,  -- Adjust as needed (10-5000 meters)
    is_active = true,
    warehouse_name = 'اسم مخزنك الفعلي',
    description = 'الموقع الفعلي للمخزن'
WHERE warehouse_name = 'المخزن الرئيسي';
```

### 2. Grant Permissions (If Needed)
```sql
-- Ensure proper permissions
GRANT SELECT, INSERT, UPDATE ON warehouse_location_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON worker_attendance_records TO authenticated;
GRANT EXECUTE ON FUNCTION process_biometric_attendance TO authenticated;
GRANT EXECUTE ON FUNCTION get_location_attendance_stats TO authenticated;
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Ensure RLS policies are properly configured
   - Check user authentication status

2. **Function Not Found Errors**
   - Verify all functions were created successfully
   - Check function signatures match expected parameters

3. **Column Already Exists Errors**
   - This is normal if migration was partially run before
   - The migration uses `ADD COLUMN IF NOT EXISTS` to handle this

### Rollback (If Needed)
```sql
-- Remove added columns (CAUTION: This will delete data)
ALTER TABLE worker_attendance_records 
DROP COLUMN IF EXISTS latitude,
DROP COLUMN IF EXISTS longitude,
DROP COLUMN IF EXISTS location_validated,
DROP COLUMN IF EXISTS distance_from_warehouse,
DROP COLUMN IF EXISTS location_accuracy,
DROP COLUMN IF EXISTS attendance_method,
DROP COLUMN IF EXISTS biometric_verified;

-- Drop warehouse location table
DROP TABLE IF EXISTS warehouse_location_settings CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS process_biometric_attendance CASCADE;
DROP FUNCTION IF EXISTS get_location_attendance_stats CASCADE;
DROP FUNCTION IF EXISTS validate_warehouse_location CASCADE;
```

## Next Steps

After successful migration:
1. Configure warehouse location coordinates
2. Test biometric attendance functionality
3. Set up location management in admin panel
4. Train users on new biometric features

## Support

If you encounter issues:
1. Check Supabase logs for detailed error messages
2. Verify all prerequisites are met
3. Ensure proper database permissions
4. Contact support with specific error messages
