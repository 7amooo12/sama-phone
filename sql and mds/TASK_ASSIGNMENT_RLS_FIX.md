# Task Assignment RLS Policy Fix

## Problem Analysis

The Flutter app was experiencing a critical Row Level Security (RLS) policy issue preventing task assignment functionality with the following error:

```
PostgrestException with code 42501 - "new row violates row-level security policy for table 'worker_tasks'"
```

## Root Cause

After analyzing the codebase, I discovered there are **two separate task management systems** in the app:

1. **TaskService** (used by assign_tasks_screen.dart) - Uses `TaskModel` and expects a `tasks` table
2. **WorkerTaskProvider** - Uses `WorkerTaskModel` and works with `worker_tasks` table

The error occurred because:
- The admin was trying to assign tasks using TaskService.createMultipleTasks()
- TaskService was trying to insert TaskModel data into a table (either missing `tasks` table or incompatible schema)
- The RLS policies were not properly configured for admin users to insert tasks

## Data Model Differences

### TaskModel (for manufacturing/product tasks)
```dart
// Fields include:
- title, description, status, assignedTo, dueDate, createdAt
- priority, attachments, adminName, category
- quantity, completedQuantity, productName, progress, deadline
- productImage, workerId, workerName, adminId, productId, orderId
```

### WorkerTaskModel (for general worker tasks)
```dart
// Fields include:
- title, description, assignedTo, assignedBy, priority, status
- dueDate, createdAt, updatedAt, estimatedHours
- category, location, requirements, isActive
```

## Solution Implemented

### 1. Database Schema Fix

Created `CREATE_TASKS_TABLE_SCHEMA.sql` to:
- Create the `tasks` table with proper schema for TaskModel
- Add all required fields: admin_name, quantity, completed_quantity, product_name, progress, deadline, product_image, worker_id, worker_name, admin_id, product_id, order_id, attachments
- Add proper constraints and indexes
- Set up automatic triggers for updated_at and worker_id fields

### 2. RLS Policies Fix

Updated `SUPABASE_RLS_POLICIES_FIX.sql` to create comprehensive policies for both tables:

#### For `tasks` table (TaskModel):
- **Admin full access**: Admin users can INSERT, SELECT, UPDATE, DELETE all tasks
- **Owner full access**: Owner users can INSERT, SELECT, UPDATE, DELETE all tasks  
- **Accountant view**: Accountant users can SELECT tasks
- **Worker view assigned**: Workers can SELECT only their assigned tasks
- **Worker update assigned**: Workers can UPDATE only their assigned tasks

#### For `worker_tasks` table (WorkerTaskModel):
- Similar role-based policies for the existing worker task system

### 3. User Role Verification

The policies check:
```sql
EXISTS (
  SELECT 1 FROM public.user_profiles 
  WHERE user_profiles.id = auth.uid() 
  AND user_profiles.role = 'admin'
  AND user_profiles.status = 'approved'
)
```

This ensures only approved admin users can create tasks.

## Files Modified

1. **CREATE_TASKS_TABLE_SCHEMA.sql** - Creates tasks table with correct schema
2. **SUPABASE_RLS_POLICIES_FIX.sql** - Comprehensive RLS policies for both task systems
3. **TASK_ASSIGNMENT_RLS_FIX.md** - This documentation

## Implementation Steps

### Step 1: Create the Tasks Table
Run the SQL script in Supabase SQL Editor:
```sql
-- Run CREATE_TASKS_TABLE_SCHEMA.sql
```

### Step 2: Apply RLS Policies
Run the RLS policies script:
```sql
-- Run SUPABASE_RLS_POLICIES_FIX.sql
```

### Step 3: Verify Admin User
Ensure the admin user (admin@sama.com, ID: 577acd69-4d16-4677-8ed8-1cc5058423f3) has:
- role = 'admin'
- status = 'approved'

### Step 4: Test Task Assignment
1. Launch the app
2. Login as admin user
3. Navigate to task assignment screen
4. Select products and worker
5. Assign tasks - should now work without RLS errors

## Expected Behavior After Fix

1. ✅ Admin users can successfully assign manufacturing tasks to workers
2. ✅ Tasks are inserted into the `tasks` table with proper TaskModel structure
3. ✅ Workers can view and update their assigned tasks
4. ✅ Accountants can view tasks for monitoring
5. ✅ Owners have full access to task management
6. ✅ RLS policies prevent unauthorized access

## Verification Queries

Check if tables exist:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('tasks', 'worker_tasks');
```

Check RLS policies:
```sql
SELECT schemaname, tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename IN ('tasks', 'worker_tasks')
ORDER BY tablename, policyname;
```

Check admin user role:
```sql
SELECT id, email, role, status 
FROM user_profiles 
WHERE email = 'admin@sama.com';
```

## Testing Checklist

- [ ] Tasks table exists with correct schema
- [ ] RLS policies are applied to both tables
- [ ] Admin user has approved status
- [ ] Task assignment screen loads without errors
- [ ] Admin can select products and workers
- [ ] Task creation completes successfully
- [ ] Tasks appear in database
- [ ] Workers can view assigned tasks
- [ ] No RLS policy violations in logs

## Troubleshooting

If issues persist:

1. **Check table existence**: Verify `tasks` table exists
2. **Verify RLS policies**: Ensure policies are created for authenticated role
3. **Check user status**: Confirm admin user is approved
4. **Review logs**: Look for specific RLS policy violations
5. **Test permissions**: Try manual INSERT as admin user in SQL editor

## Notes

- The app now supports both task systems: general worker tasks (worker_tasks) and manufacturing tasks (tasks)
- TaskService uses the `tasks` table for product manufacturing assignments
- WorkerTaskProvider continues to use `worker_tasks` for general worker management
- Both systems have proper RLS policies for role-based access control
