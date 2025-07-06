# SmartBizTracker Invoice System - Database Schema Documentation

## 📋 Overview

This document describes the complete production-ready database schema for the SmartBizTracker invoice system. The schema is designed for Supabase (PostgreSQL) and includes all necessary tables, indexes, constraints, triggers, and Row Level Security (RLS) policies.

## 🗄️ Database Schema

### Main Table: `public.invoices`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PRIMARY KEY | Invoice ID (e.g., 'INV-1234567890') |
| `user_id` | UUID | NOT NULL, FK to auth.users | User who created the invoice |
| `customer_name` | TEXT | NOT NULL | Customer's full name |
| `customer_phone` | TEXT | NULLABLE | Customer's phone number |
| `customer_email` | TEXT | NULLABLE | Customer's email address |
| `customer_address` | TEXT | NULLABLE | Customer's physical address |
| `items` | JSONB | NOT NULL | Array of invoice items |
| `subtotal` | NUMERIC(12,2) | NOT NULL, >= 0 | Sum of all item subtotals |
| `discount` | NUMERIC(12,2) | DEFAULT 0, >= 0 | Discount amount applied |
| `total_amount` | NUMERIC(12,2) | NOT NULL, >= 0 | Calculated as subtotal - discount |
| `notes` | TEXT | NULLABLE | Additional invoice notes |
| `status` | TEXT | DEFAULT 'pending' | Invoice status |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() | Last update timestamp |

### JSONB Items Structure

The `items` field stores an array of invoice items with the following structure:

```json
[
  {
    "product_id": "string",
    "product_name": "string", 
    "quantity": number,
    "unit_price": number,
    "subtotal": number,
    "notes": "string (optional)"
  }
]
```

### Status Values

- `pending`: Invoice created but not yet processed
- `completed`: Invoice has been completed/paid
- `cancelled`: Invoice has been cancelled

## 🚀 Performance Indexes

| Index Name | Columns | Purpose |
|------------|---------|---------|
| `idx_invoices_user_id` | user_id | Fast user-specific queries |
| `idx_invoices_status` | status | Fast status filtering |
| `idx_invoices_created_at` | created_at DESC | Chronological sorting |
| `idx_invoices_user_status` | user_id, status | User-specific status filtering |
| `idx_invoices_user_created` | user_id, created_at DESC | User-specific chronological queries |
| `idx_invoices_status_created` | status, created_at DESC | Status and date filtering |
| `idx_invoices_customer_name` | LOWER(customer_name) | Case-insensitive customer search |
| `idx_invoices_items_gin` | items (GIN) | JSONB item searches |

## 🔒 Row Level Security (RLS) Policies

### Admin Role
- **Access**: Full CRUD access to all invoices
- **Condition**: User has role 'admin' and status 'approved'

### Owner Role  
- **Access**: Full CRUD access to all invoices
- **Condition**: User has role 'owner' and status 'approved'

### Accountant Role
- **Access**: Full CRUD access to all invoices
- **Condition**: User has role 'accountant' and status 'approved'

### Client Role
- **Access**: Read-only access to own invoices
- **Condition**: Customer name, email, or phone matches user profile

### Worker Role
- **Access**: No access to invoices
- **Condition**: Explicitly denied access

## ⚡ Automatic Triggers

### 1. Calculate Invoice Total
- **Trigger**: `trigger_calculate_invoice_total`
- **Function**: `calculate_invoice_total()`
- **Purpose**: Automatically calculates `total_amount = subtotal - discount`
- **When**: Before INSERT or UPDATE

### 2. Validate Invoice Items
- **Trigger**: `trigger_validate_invoice_items`
- **Function**: `validate_invoice_items()`
- **Purpose**: Validates JSONB items structure and data types
- **When**: Before INSERT or UPDATE

## 📊 Database Views

### 1. `invoice_statistics`
Provides aggregated statistics by month:
- Total invoices count
- Count by status (pending, completed, cancelled)
- Revenue totals by status
- Average invoice amount

### 2. `recent_invoices`
Shows invoices from the last 30 days, ordered by creation date.

## 🛠️ Utility Functions

### 1. `get_user_invoice_stats(user_uuid UUID)`
Returns invoice statistics for a specific user:
- Total count
- Count by status
- Total and pending amounts

### 2. `search_invoices_by_customer(search_term TEXT)`
Searches invoices by customer name (case-insensitive).

## 🔧 Installation Instructions

### Step 1: Execute Main Schema
1. Open Supabase SQL Editor
2. Copy and paste the entire `PRODUCTION_INVOICE_SCHEMA.sql` file
3. Execute the script

### Step 2: Verify Installation
1. Execute the `INVOICE_SCHEMA_VERIFICATION.sql` script
2. Review the output to ensure all components are created correctly

### Step 3: Test the System
The verification script includes automatic tests for:
- Constraint validations
- Trigger functionality
- Index usage
- RLS policy enforcement

## 📝 Usage Examples

### Insert a New Invoice
```sql
INSERT INTO public.invoices (
    id, user_id, customer_name, customer_phone, items, subtotal, discount
) VALUES (
    'INV-1234567890',
    auth.uid(),
    'John Doe',
    '+1234567890',
    '[
        {
            "product_id": "PROD-001",
            "product_name": "Widget A",
            "quantity": 2,
            "unit_price": 50.00,
            "subtotal": 100.00
        }
    ]'::jsonb,
    100.00,
    10.00
);
-- total_amount will be automatically calculated as 90.00
```

### Query User's Invoices
```sql
SELECT * FROM public.invoices 
WHERE user_id = auth.uid() 
ORDER BY created_at DESC;
```

### Search by Customer
```sql
SELECT * FROM search_invoices_by_customer('John');
```

### Get Invoice Statistics
```sql
SELECT * FROM invoice_statistics 
ORDER BY month DESC 
LIMIT 12;
```

## 🔍 Monitoring and Maintenance

### Performance Monitoring
- Monitor index usage with `pg_stat_user_indexes`
- Check query performance with `EXPLAIN ANALYZE`
- Monitor table size with `pg_total_relation_size()`

### Regular Maintenance
- Update table statistics: `ANALYZE public.invoices;`
- Monitor RLS policy performance
- Review and optimize slow queries

## 🚨 Important Notes

1. **No VAT/Tax**: The system explicitly excludes VAT/tax calculations as per requirements
2. **Record-Only**: Invoices don't automatically deduct product inventory
3. **User Profiles Dependency**: RLS policies depend on the `user_profiles` table
4. **UUID Requirements**: All user references use UUID format
5. **JSONB Validation**: Strict validation ensures data integrity for invoice items

## 🎯 Production Readiness

This schema is production-ready and includes:
- ✅ Complete data validation
- ✅ Performance optimization
- ✅ Security through RLS
- ✅ Automatic calculations
- ✅ Error handling
- ✅ Comprehensive indexing
- ✅ Audit trails with timestamps
- ✅ Scalable design patterns

The system is ready for immediate deployment to production environments.
