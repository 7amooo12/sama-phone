# 🛠️ Database Setup Guide - Warehouse Release Orders

## 🚨 **Issue Identified**

Your SmartBizTracker application is encountering a **PGRST200** error because the warehouse release orders database tables haven't been created in your Supabase database yet.

**Error Details:**
- **Code:** PGRST200
- **Message:** "Could not find a relationship between 'warehouse_release_orders' and 'warehouse_release_order_items' in the schema cache"
- **Root Cause:** The migration file was created but not applied to the database

## ✅ **Solution Steps**

### **Option 1: Using Supabase CLI (Recommended)**

If you have Supabase CLI installed:

```bash
# Navigate to your project root
cd /path/to/your/smartbiztracker_new

# Apply all pending migrations
supabase db push

# Or apply specific migration
supabase db push --include-all
```

### **Option 2: Manual SQL Execution (If CLI not available)**

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to **SQL Editor**

2. **Execute the Setup Script**
   - Copy the entire content from `database_setup_manual.sql` (created in your project root)
   - Paste it into the SQL Editor
   - Click **Run** to execute

3. **Verify Tables Creation**
   - Go to **Table Editor** in Supabase Dashboard
   - Check that these tables now exist:
     - `warehouse_release_orders`
     - `warehouse_release_order_items`
     - `warehouse_release_order_history`

### **Option 3: Step-by-Step Manual Creation**

If you prefer to create tables one by one:

#### **Step 1: Create Main Table**
```sql
CREATE TABLE warehouse_release_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_number VARCHAR(50) UNIQUE NOT NULL,
    original_order_id VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    client_email VARCHAR(255),
    client_phone VARCHAR(50),
    assigned_to VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending_warehouse_approval',
    total_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(10) NOT NULL DEFAULT 'EGP',
    notes TEXT,
    warehouse_manager_id VARCHAR(255),
    warehouse_manager_name VARCHAR(255),
    approved_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### **Step 2: Create Items Table**
```sql
CREATE TABLE warehouse_release_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_id UUID NOT NULL REFERENCES warehouse_release_orders(id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL,
    product_code VARCHAR(100),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(12,2) NOT NULL,
    unit VARCHAR(50) DEFAULT 'قطعة',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### **Step 3: Create History Table**
```sql
CREATE TABLE warehouse_release_order_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_id UUID NOT NULL REFERENCES warehouse_release_orders(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    performed_by VARCHAR(255) NOT NULL,
    performed_by_name VARCHAR(255),
    notes TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 🔍 **Verification Steps**

After applying the migration, verify the setup:

### **1. Check Tables Exist**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name LIKE 'warehouse_release%'
ORDER BY table_name;
```

**Expected Result:**
- `warehouse_release_order_history`
- `warehouse_release_order_items`
- `warehouse_release_orders`

### **2. Check Foreign Key Relationships**
```sql
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name LIKE 'warehouse_release%';
```

### **3. Test Application**
1. Restart your Flutter application
2. Navigate to the Warehouse Release Orders screen
3. The error should be resolved and you should see an empty state instead

## 🚀 **Post-Setup Actions**

### **1. Enable Row Level Security (If needed)**
```sql
ALTER TABLE warehouse_release_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_release_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_release_order_history ENABLE ROW LEVEL SECURITY;
```

### **2. Create Policies (If needed)**
```sql
-- Allow all operations for authenticated users (adjust as needed)
CREATE POLICY "warehouse_release_orders_policy" ON warehouse_release_orders
    FOR ALL USING (true);

CREATE POLICY "warehouse_release_order_items_policy" ON warehouse_release_order_items
    FOR ALL USING (true);

CREATE POLICY "warehouse_release_order_history_policy" ON warehouse_release_order_history
    FOR ALL USING (true);
```

### **3. Grant Permissions**
```sql
GRANT ALL ON warehouse_release_orders TO authenticated;
GRANT ALL ON warehouse_release_order_items TO authenticated;
GRANT ALL ON warehouse_release_order_history TO authenticated;
```

## 🔧 **Troubleshooting**

### **Issue: Permission Denied**
**Solution:** Make sure your Supabase user has the necessary permissions to create tables.

### **Issue: Tables Already Exist**
**Solution:** If you get "table already exists" errors, you can either:
- Drop existing tables first: `DROP TABLE IF EXISTS table_name CASCADE;`
- Or modify the CREATE statements to use `CREATE TABLE IF NOT EXISTS`

### **Issue: Foreign Key Constraints**
**Solution:** Make sure to create tables in the correct order:
1. `warehouse_release_orders` (parent table)
2. `warehouse_release_order_items` (references parent)
3. `warehouse_release_order_history` (references parent)

## 📱 **Application Changes Made**

I've also updated the application to handle this scenario gracefully:

1. **Service Layer:** Added table existence checking
2. **UI Layer:** Shows helpful error messages for database setup issues
3. **Error Handling:** Graceful degradation when tables don't exist

## ✅ **Success Indicators**

You'll know the setup is successful when:

1. ✅ No more PGRST200 errors in the logs
2. ✅ Warehouse Release Orders screen loads without errors
3. ✅ You can see an empty state or existing release orders
4. ✅ The application functions normally

## 🆘 **Need Help?**

If you encounter any issues:

1. **Check Supabase Logs:** Go to Supabase Dashboard > Logs
2. **Verify Permissions:** Ensure your database user has CREATE permissions
3. **Check Network:** Ensure your application can connect to Supabase
4. **Review Migration:** Double-check the SQL syntax in the migration file

## 📞 **Support**

If you continue to experience issues after following this guide, please provide:
- The exact error messages from the logs
- Screenshots of your Supabase table editor
- The result of the verification queries above

The warehouse release orders system is fully implemented and ready to work once the database schema is properly set up! 🎉
