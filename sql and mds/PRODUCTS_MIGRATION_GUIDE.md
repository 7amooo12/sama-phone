# Products Table Migration Guide

## Overview
This guide provides step-by-step instructions for migrating the products table from UUID to TEXT to support external API products while maintaining all foreign key relationships.

## Problem Description
The original issue was a PostgreSQL foreign key constraint error when trying to convert the products table ID from UUID to TEXT. The error occurred because the migration script didn't account for ALL foreign key constraints that reference `products.id`, specifically missing the `favorites_product_id_fkey` constraint.

## Files Included

### 1. `COMPREHENSIVE_PRODUCT_IMAGE_INVOICE_FIX.sql`
**Enhanced migration script** that:
- Dynamically discovers ALL foreign key constraints referencing `products.id`
- Safely drops all constraints before migration
- Converts products.id and all referencing columns from UUID to TEXT
- Recreates all foreign key constraints properly
- Includes comprehensive error handling and logging

### 2. `VERIFY_PRODUCTS_MIGRATION.sql`
**Verification script** that:
- Analyzes current database schema before migration
- Identifies all foreign key relationships
- Checks for orphaned records that could cause issues
- Verifies migration success after execution
- Tests external API product functionality

### 3. `ROLLBACK_PRODUCTS_MIGRATION.sql`
**Rollback script** that:
- Restores the products table from backup if migration fails
- Converts all columns back to UUID
- Recreates original foreign key constraints
- Provides safety net for failed migrations

## Migration Process

### Phase 1: Pre-Migration Analysis
```sql
-- Run verification script to analyze current state
\i VERIFY_PRODUCTS_MIGRATION.sql
```

**Expected Output:**
- Current products table structure
- List of ALL foreign key constraints referencing products.id
- Data types of all product_id columns
- Record counts in related tables
- Migration readiness assessment

### Phase 2: Execute Migration
```sql
-- Run the comprehensive migration script
\i COMPREHENSIVE_PRODUCT_IMAGE_INVOICE_FIX.sql
```

**What This Does:**
1. **Schema Analysis**: Identifies all foreign key constraints dynamically
2. **Backup Creation**: Creates `products_backup` table for safety
3. **Constraint Removal**: Drops ALL foreign key constraints referencing products.id
4. **Type Conversion**: Converts products.id from UUID to TEXT
5. **Column Updates**: Updates ALL referencing columns to TEXT
6. **Constraint Recreation**: Recreates ALL foreign key constraints
7. **Function Creation**: Adds helper functions for external API integration
8. **Testing**: Validates the migration with test queries

### Phase 3: Post-Migration Verification
```sql
-- Run verification script again to confirm success
\i VERIFY_PRODUCTS_MIGRATION.sql
```

**Expected Changes:**
- products.id should now be TEXT type
- All product_id columns should be TEXT type
- All foreign key constraints should be recreated
- External API product insertion should work
- Text ID queries should work without UUID errors

## Identified Foreign Key Relationships

Based on the codebase analysis, the following tables have foreign key relationships with products.id:

1. **favorites.product_id** → products.id
2. **order_items.product_id** → products.id  
3. **client_order_items.product_id** → products.id (may already be TEXT)

## Error Handling

### If Migration Fails
1. Check the error message in the PostgreSQL logs
2. Verify the backup table `products_backup` exists
3. Use the rollback script if necessary:
```sql
-- Uncomment the DO block in ROLLBACK_PRODUCTS_MIGRATION.sql
\i ROLLBACK_PRODUCTS_MIGRATION.sql
```

### Common Issues and Solutions

#### Issue: "constraint does not exist"
**Solution**: The constraint may have already been dropped or renamed. The script handles this with `IF EXISTS` clauses.

#### Issue: "cannot cast type uuid to text"
**Solution**: Some UUIDs may have invalid formats. The script handles this by using proper casting.

#### Issue: "foreign key constraint fails"
**Solution**: There may be orphaned records. Run the verification script first to identify and clean up orphaned data.

## Testing the Migration

### Test External API Product Creation
```sql
-- This should work after migration
INSERT INTO public.products (
    id, name, description, price, image_url, main_image_url, 
    source, external_id, created_at
) VALUES (
    'external-product-123',
    'Test External Product',
    'Product from external API',
    99.99,
    'https://example.com/product.jpg',
    'https://example.com/product.jpg',
    'external_api',
    '123',
    NOW()
);
```

### Test Text ID Queries
```sql
-- This was the original failing query
SELECT main_image_url, image_urls 
FROM public.products 
WHERE id = 'external-product-123';
```

### Test Foreign Key Relationships
```sql
-- Test favorites relationship
INSERT INTO public.favorites (user_id, product_id)
VALUES (
    (SELECT id FROM auth.users LIMIT 1),
    'external-product-123'
);
```

## Rollback Instructions

If you need to rollback the migration:

1. **Verify backup exists**:
```sql
SELECT COUNT(*) FROM public.products_backup;
```

2. **Execute rollback**:
   - Edit `ROLLBACK_PRODUCTS_MIGRATION.sql`
   - Uncomment the DO block
   - Run the script

3. **Verify rollback**:
```sql
-- Check products.id is back to UUID
SELECT data_type FROM information_schema.columns 
WHERE table_name = 'products' AND column_name = 'id';
```

## Post-Migration Flutter Code Updates

After successful migration, update your Flutter code to:

1. Use the new `sync_external_product()` function for API integration
2. Use `get_product_image_url()` for image retrieval
3. Update product ID handling to support both UUID and text formats
4. Test invoice PDF generation with product images

## Cleanup

After confirming the migration is successful and stable:

```sql
-- Optional: Remove backup table
DROP TABLE IF EXISTS public.products_backup;
```

## Support

If you encounter issues:
1. Check PostgreSQL logs for detailed error messages
2. Verify all prerequisites are met
3. Use the verification script to diagnose problems
4. Keep the backup table until migration is confirmed stable
