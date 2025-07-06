# 🔧 **SQL Setup Guide - Warehouse Manager**

## **🚨 Multiple Errors Fixed**

The SQL scripts had several issues that have been resolved:

1. ✅ **Column Mismatch**: Fixed `phone` vs `phone_number` column name
2. ✅ **Foreign Key Constraint**: Fixed missing auth.users references
3. ✅ **Unique Constraint**: Fixed ON CONFLICT clause requirements

## **🎯 RECOMMENDED SOLUTION: Simple Setup Script**

**Use this script:** `sql/warehouse_manager_simple_setup.sql`

This is the **easiest and most reliable** approach that handles all the constraints properly.

---

## **📋 Two Setup Options Available**

### **Option A: Fixed Original Script (Recommended)**
**File:** `sql/warehouse_manager_setup.sql`

**What it does:**
- ✅ Automatically adds unique constraint on email column if needed
- ✅ Uses `ON CONFLICT` for safe upsert operations
- ✅ Prevents duplicate email entries
- ✅ Updates existing users if they already exist

**Advantages:**
- More robust and prevents duplicate emails
- Safer for production environments
- Handles edge cases better

### **Option B: Alternative Script (No Constraints)**
**File:** `sql/warehouse_manager_setup_alternative.sql`

**What it does:**
- ✅ Uses conditional INSERT statements instead of ON CONFLICT
- ✅ Checks if records exist before inserting
- ✅ No unique constraints required
- ✅ Works with any existing table structure

**Advantages:**
- Doesn't modify existing table structure
- Simpler approach for testing
- No constraint dependencies

---

## **🚀 Quick Setup Instructions (UPDATED)**

### **Step 1: Create Auth Users First**

**IMPORTANT:** You must create auth users in Supabase Auth UI before running any SQL script.

1. **Go to Supabase Dashboard**
   - Navigate to **Authentication** → **Users**
   - Click **"Create User"**

2. **Create These Users:**
   ```
   Email: warehouse@samastore.com
   Password: temp123
   Email Confirmed: ✅ Yes

   Email: warehouse1@samastore.com
   Password: temp123
   Email Confirmed: ✅ Yes

   Email: warehouse2@samastore.com
   Password: temp123
   Email Confirmed: ✅ Yes
   ```

### **Step 2: Run the Simple Setup Script**

1. **Use the Simple Script (Recommended):**
   ```sql
   -- Use: sql/warehouse_manager_simple_setup.sql
   -- This handles all constraints properly
   ```

2. **Execute in Supabase SQL Editor**
   - Copy the entire content of `warehouse_manager_simple_setup.sql`
   - Paste into Supabase SQL Editor
   - Click **Run**

### **Step 3: Verify Success**

**Check Users Created:**
```sql
SELECT email, name, role, status 
FROM user_profiles 
WHERE role = 'warehouseManager';
```

**Expected Output:**
```
email                    | name                      | role             | status
warehouse@samastore.com  | مدير المخزن الرئيسي        | warehouseManager | approved
warehouse1@samastore.com | مدير المخزن الفرعي الأول   | warehouseManager | approved
warehouse2@samastore.com | مدير مخزن الطوارئ          | warehouseManager | approved
```

**Check Warehouses Created:**
```sql
SELECT w.name, w.location, up.name as manager_name, w.status 
FROM warehouses w
LEFT JOIN user_profiles up ON w.manager_id = up.id;
```

---

## **🔍 Troubleshooting**

### **Error: "relation user_profiles does not exist"**
**Solution:** The user_profiles table doesn't exist. Create it first or check your table name.

### **Error: "column email does not exist"**
**Solution:** Check your user_profiles table structure. The email column might have a different name.

### **Error: "permission denied for table user_profiles"**
**Solution:** Ensure you have proper permissions in Supabase. Try running as the postgres user.

### **Error: "duplicate key value violates unique constraint"**
**Solution:** Users already exist. The script will handle this automatically with the fixed version.

---

## **✅ Success Indicators**

When the script runs successfully, you should see:

```
NOTICE: Added unique constraint on email column (Option A only)
NOTICE: Created warehouse manager: warehouse@samastore.com
NOTICE: Created warehouse manager: warehouse1@samastore.com
NOTICE: Created warehouse manager: warehouse2@samastore.com
NOTICE: Created main warehouse
NOTICE: Created secondary warehouse
NOTICE: === WAREHOUSE MANAGER SETUP COMPLETED ===
NOTICE: Created 3 warehouse manager users
NOTICE: Created 2 warehouses
```

---

## **🎯 Next Steps After SQL Setup**

1. **Create Auth Users in Supabase:**
   - Go to **Authentication** → **Users**
   - Create users with emails:
     - `warehouse@samastore.com`
     - `warehouse1@samastore.com`
     - `warehouse2@samastore.com`
   - Set password: `temp123` for all
   - Confirm emails

2. **Test in Flutter App:**
   - Launch your Flutter app
   - Try logging in with: `warehouse@samastore.com` / `temp123`
   - Should redirect to warehouse manager dashboard

3. **Verify Dashboard:**
   - Check Arabic interface loads
   - Verify luxury black-blue gradient styling
   - Test navigation tabs work
   - Confirm warehouse data displays

---

## **📞 Support**

If you encounter any issues:

1. **Check the SQL output** for error messages
2. **Verify table structure** matches expectations
3. **Try the alternative script** if the main one fails
4. **Check Supabase permissions** for your user account

Both scripts achieve the same result - choose the one that works best for your environment!
