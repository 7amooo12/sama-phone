# Voucher/Discount Management System Implementation Plan

## Overview
This document outlines the comprehensive implementation plan for adding a voucher/discount management system to the SmartBizTracker application.

## Database Schema

### 1. Vouchers Table
```sql
CREATE TABLE IF NOT EXISTS public.vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL, -- Auto-generated voucher code
    type TEXT NOT NULL CHECK (type IN ('category', 'product')),
    target_id TEXT NOT NULL, -- Category name or product ID
    discount_percentage INTEGER NOT NULL CHECK (discount_percentage >= 1 AND discount_percentage <= 100),
    expiration_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Constraints
    CONSTRAINT vouchers_expiration_future CHECK (expiration_date > now())
);
```

### 2. Client Vouchers Table
```sql
CREATE TABLE IF NOT EXISTS public.client_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id UUID REFERENCES public.vouchers(id) ON DELETE CASCADE NOT NULL,
    client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired')),
    used_at TIMESTAMP WITH TIME ZONE,
    order_id UUID REFERENCES public.client_orders(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    
    -- Constraints
    UNIQUE(voucher_id, client_id)
);
```

## Implementation Steps

### Phase 1: Database Setup
1. Create voucher-related tables in Supabase
2. Set up RLS policies for voucher access control
3. Add voucher table references to existing schema

### Phase 2: Models and Services
1. Create VoucherModel and ClientVoucherModel
2. Create VoucherService for database operations
3. Update SupabaseProvider with voucher methods

### Phase 3: Admin/Owner Dashboard Integration
1. Add "Vouchers Management" tab to admin dashboard
2. Add "Vouchers Management" tab to owner dashboard
3. Create voucher creation interface
4. Create client assignment workflow
5. Create voucher management dashboard

### Phase 4: Client Interface
1. Add "My Vouchers" tab to client dashboard
2. Create voucher display interface
3. Implement voucher usage tracking

### Phase 5: Checkout Integration
1. Modify checkout process to detect applicable vouchers
2. Implement voucher application logic
3. Update order creation to include voucher discounts
4. Update invoice generation to show voucher discounts

### Phase 6: Testing and Optimization
1. Test voucher creation and assignment
2. Test voucher usage in checkout
3. Test expiration and status management
4. Performance optimization and error handling

## File Structure

### New Files to Create:
- `lib/models/voucher_model.dart`
- `lib/models/client_voucher_model.dart`
- `lib/services/voucher_service.dart`
- `lib/providers/voucher_provider.dart`
- `lib/screens/admin/voucher_management_screen.dart`
- `lib/screens/owner/voucher_management_screen.dart`
- `lib/screens/client/my_vouchers_screen.dart`
- `lib/widgets/voucher/voucher_card.dart`
- `lib/widgets/voucher/voucher_creation_form.dart`
- `lib/widgets/voucher/client_selection_modal.dart`
- `supabase/migrations/20241225000000_create_voucher_system.sql`

### Files to Modify:
- `lib/screens/admin/admin_dashboard.dart` (add voucher tab)
- `lib/screens/owner/owner_dashboard.dart` (add voucher tab)
- `lib/screens/client/client_dashboard.dart` (add voucher tab)
- `lib/screens/client/checkout_screen.dart` (voucher integration)
- `lib/providers/client_orders_provider.dart` (voucher application)
- `lib/config/supabase_schema.dart` (add voucher tables)
- `lib/models/models.dart` (export voucher models)
- `lib/providers/supabase_provider.dart` (add voucher methods)

## Technical Specifications

### Voucher Code Generation
- Format: `VOUCHER-{YYYYMMDD}-{RANDOM6}`
- Example: `VOUCHER-20241225-ABC123`

### Discount Application Logic
1. During checkout, scan cart items for applicable vouchers
2. Match vouchers by product ID or category
3. Apply highest applicable discount per item
4. Calculate per-unit discount, then subtotal, then final total
5. Mark voucher as used after successful order completion

### UI/UX Requirements
- Dark theme with green accents
- Arabic RTL design
- Professional, modern interface
- Real-time updates using Provider pattern
- Proper error handling and validation
- Loading states and feedback

### Security Considerations
- RLS policies ensure clients only see assigned vouchers
- Admin/owner access to all voucher management
- Voucher usage tracking and audit trail
- Expiration date validation
- Single-use voucher enforcement

## Integration Points

### With Existing Systems:
1. **User Management**: Voucher assignment to clients
2. **Product System**: Category and product-based vouchers
3. **Order System**: Voucher application during checkout
4. **Invoice System**: Voucher discount display
5. **Notification System**: Voucher assignment notifications

### Provider Pattern Integration:
- VoucherProvider for state management
- Integration with existing SupabaseProvider
- Real-time updates for voucher status changes

## Testing Strategy

### Unit Tests:
- Voucher model validation
- Discount calculation logic
- Expiration date handling

### Integration Tests:
- Voucher creation workflow
- Client assignment process
- Checkout integration
- Order completion with vouchers

### User Acceptance Tests:
- Admin voucher management workflow
- Client voucher usage workflow
- Edge cases (expired, used vouchers)

## Performance Considerations

### Database Optimization:
- Indexes on frequently queried fields
- Efficient RLS policies
- Proper foreign key relationships

### Frontend Optimization:
- Lazy loading of voucher data
- Efficient state management
- Optimized UI rendering

## Rollout Plan

### Phase 1: Core Infrastructure (Week 1)
- Database schema creation
- Basic models and services
- RLS policies setup

### Phase 2: Admin Interface (Week 2)
- Voucher management screens
- Creation and assignment workflows
- Management dashboard

### Phase 3: Client Interface (Week 3)
- Client voucher display
- Voucher usage interface
- Integration with existing client screens

### Phase 4: Checkout Integration (Week 4)
- Voucher detection and application
- Order processing updates
- Invoice integration

### Phase 5: Testing and Refinement (Week 5)
- Comprehensive testing
- Bug fixes and optimizations
- Documentation updates

## Success Metrics

### Functional Metrics:
- Voucher creation success rate
- Client assignment accuracy
- Checkout integration reliability
- Order completion with vouchers

### Performance Metrics:
- Voucher query response times
- Checkout process performance
- UI responsiveness
- Database query efficiency

### User Experience Metrics:
- Admin workflow efficiency
- Client voucher usage rates
- Error rates and user feedback
- System adoption rates
