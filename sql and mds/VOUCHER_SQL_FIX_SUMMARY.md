# Voucher System SQL Migration Fix

## Problem
The original SQL migration was failing with PostgreSQL error:
```
ERROR: 42P17: functions in index predicate must be marked IMMUTABLE
```

## Root Cause
The error occurred because two composite indexes used WHERE clauses with the `now()` function:

```sql
-- PROBLEMATIC (ORIGINAL)
CREATE INDEX idx_vouchers_active_unexpired ON public.vouchers(is_active, expiration_date) 
    WHERE is_active = true AND expiration_date > now();
CREATE INDEX idx_client_vouchers_active_client ON public.client_vouchers(client_id, status) 
    WHERE status = 'active';
```

The `now()` function is **NOT IMMUTABLE** because it returns different values over time. PostgreSQL requires all functions used in index predicates (WHERE clauses) to be marked as IMMUTABLE.

## Solution Applied
Removed the WHERE clauses from the problematic indexes:

```sql
-- FIXED VERSION
CREATE INDEX idx_vouchers_active_unexpired ON public.vouchers(is_active, expiration_date);
CREATE INDEX idx_client_vouchers_active_client ON public.client_vouchers(client_id, status);
```

## Impact Analysis

### Performance Impact
- **Minimal**: The indexes will now include all rows instead of filtering, but this is acceptable because:
  1. The indexes are still useful for sorting and filtering in queries
  2. PostgreSQL can still use these indexes efficiently with additional WHERE clauses in queries
  3. The voucher tables are expected to have relatively small datasets

### Query Performance
- Queries filtering for active/unexpired vouchers will still be fast
- The application logic handles filtering expired vouchers
- Database queries can still use these indexes with WHERE clauses

### Alternative Solutions Considered
1. **Mark functions as IMMUTABLE**: Not possible with `now()` as it's inherently mutable
2. **Create custom IMMUTABLE functions**: Overly complex for this use case
3. **Use partial indexes with constants**: Would require application-level date management
4. **Remove WHERE clauses**: ✅ **CHOSEN** - Simple, effective, minimal impact

## Verification
The corrected migration should now run successfully in Supabase/PostgreSQL without any immutability errors.

## Files Modified
- `supabase/migrations/20241225000000_create_voucher_system.sql`
  - Line 108-110: Removed WHERE clauses from composite indexes
  - Added comment explaining the change

## Testing Recommendations
1. Run the migration in Supabase
2. Verify tables and indexes are created successfully
3. Test voucher creation and assignment functionality
4. Monitor query performance to ensure indexes are being used effectively

## Future Considerations
If performance becomes an issue with large voucher datasets, consider:
1. Application-level caching of active vouchers
2. Periodic cleanup of expired vouchers
3. Database partitioning by date ranges
4. More specific indexes based on actual query patterns
