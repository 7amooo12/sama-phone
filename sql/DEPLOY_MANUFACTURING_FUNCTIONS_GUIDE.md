# 🏭 Manufacturing Tools Functions Deployment Guide

## 📋 Overview
This guide will help you deploy the missing PostgreSQL functions required for the Manufacturing Tools Tracking module in SmartBizTracker.

## ❌ Current Issues
The app is failing with these specific errors:
- `Could not find the function public.get_production_gap_analysis(p_batch_id, p_product_id) in the schema cache`
- `Could not find the function public.get_batch_tool_usage_analytics(p_batch_id) in the schema cache`

## 🚀 Deployment Steps

### Step 1: Access Supabase SQL Editor
1. Open your browser and go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Navigate to your project: `ivtjacsppwmjgmuskxis`
3. Click on **SQL Editor** in the left sidebar
4. Click **New Query** to create a new SQL script

### Step 2: Deploy the Functions
1. Copy the entire content from `sql/create_missing_manufacturing_functions.sql`
2. Paste it into the Supabase SQL Editor
3. Click **Run** to execute the script
4. Wait for the success message: "Functions created successfully!"

### Step 3: Verify Deployment
Run these verification queries in the SQL Editor:

```sql
-- Check if functions exist
SELECT 
    routine_name,
    routine_type,
    specific_name
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('get_batch_tool_usage_analytics', 'get_production_gap_analysis')
ORDER BY routine_name;

-- Test the functions (optional - only if you have test data)
-- SELECT * FROM get_batch_tool_usage_analytics(13) LIMIT 3;
-- SELECT * FROM get_production_gap_analysis(4, 13);
```

### Step 4: Test in Flutter App
1. Restart your Flutter app
2. Navigate to a Production Batch Details screen
3. Verify that the Manufacturing Tools sections load without errors:
   - **Used Manufacturing Tools Section** (Tool Usage Analytics)
   - **Production Gap Analysis Section**
   - **Required Tools Forecast Section**

## 📊 Expected Results

### Function 1: `get_batch_tool_usage_analytics`
**Purpose:** Provides analytics for tools used in a specific production batch
**Returns:** List of tools with usage statistics including:
- Tool ID and name
- Quantity used per unit
- Total quantity used
- Remaining stock
- Usage percentage
- Stock status (low/medium/high)
- Usage history

### Function 2: `get_production_gap_analysis`
**Purpose:** Analyzes production progress against targets
**Returns:** Single record with:
- Product information
- Current vs target production
- Completion percentage
- Remaining pieces to produce
- Estimated completion date

## 🔧 Troubleshooting

### Issue: Permission Denied
**Solution:** Make sure you're logged in as a user with database admin privileges

### Issue: Function Already Exists
**Solution:** The script uses `CREATE OR REPLACE FUNCTION` so it should overwrite existing functions

### Issue: Table Not Found
**Solution:** Ensure the manufacturing tools schema has been deployed first:
```sql
-- Check if required tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('manufacturing_tools', 'tool_usage_history', 'production_batches', 'products');
```

## ✅ Success Indicators
After successful deployment, you should see:
1. ✅ No more PostgreSQL function errors in Flutter logs
2. ✅ Manufacturing Tools sections display data correctly
3. ✅ Production Gap Analysis shows completion percentages
4. ✅ Tool Usage Analytics display usage statistics

## 📱 Next Steps
Once the functions are deployed and working:
1. Test the Manufacturing Tools Tracking features thoroughly
2. Verify data accuracy in the analytics sections
3. Check that the refresh functionality works correctly
4. Test with different production batches and products

## 🆘 Support
If you encounter any issues during deployment:
1. Check the Supabase logs for detailed error messages
2. Verify that all prerequisite tables and data exist
3. Ensure proper permissions are granted to the authenticated role
4. Contact support with specific error messages and steps to reproduce
