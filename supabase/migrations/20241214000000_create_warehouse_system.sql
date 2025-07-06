-- إنشاء نظام إدارة المخازن الشامل
-- Comprehensive Warehouse Management System

-- إنشاء جدول المخازن
CREATE TABLE IF NOT EXISTS public.warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- فهارس للبحث السريع
    CONSTRAINT warehouses_name_unique UNIQUE (name)
);

-- إنشاء جدول مخزون المخازن
CREATE TABLE IF NOT EXISTS public.warehouse_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE CASCADE NOT NULL,
    product_id TEXT NOT NULL, -- يمكن أن يكون مرجع لجدول المنتجات أو معرف خارجي
    quantity INTEGER NOT NULL DEFAULT 0,
    minimum_stock INTEGER DEFAULT 0,
    maximum_stock INTEGER,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_by UUID REFERENCES auth.users(id) NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- قيود للتأكد من صحة البيانات
    CONSTRAINT warehouse_inventory_quantity_positive CHECK (quantity >= 0),
    CONSTRAINT warehouse_inventory_minimum_stock_positive CHECK (minimum_stock >= 0),
    CONSTRAINT warehouse_inventory_maximum_stock_positive CHECK (maximum_stock IS NULL OR maximum_stock >= minimum_stock),
    CONSTRAINT warehouse_inventory_unique UNIQUE (warehouse_id, product_id)
);

-- إنشاء جدول طلبات السحب من المخزن
CREATE TABLE IF NOT EXISTS public.warehouse_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_number TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL DEFAULT 'withdrawal',
    status TEXT NOT NULL DEFAULT 'pending',
    requested_by UUID REFERENCES auth.users(id) NOT NULL,
    approved_by UUID REFERENCES auth.users(id),
    executed_by UUID REFERENCES auth.users(id),
    warehouse_id UUID REFERENCES public.warehouses(id) NOT NULL,
    target_warehouse_id UUID REFERENCES public.warehouses(id), -- للنقل بين المخازن
    reason TEXT NOT NULL,
    notes TEXT,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    executed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- قيود للتأكد من صحة البيانات
    CONSTRAINT warehouse_requests_type_valid CHECK (type IN ('withdrawal', 'transfer', 'adjustment', 'return')),
    CONSTRAINT warehouse_requests_status_valid CHECK (status IN ('pending', 'approved', 'rejected', 'executed', 'cancelled')),
    CONSTRAINT warehouse_requests_approved_at_check CHECK (
        (status = 'approved' AND approved_at IS NOT NULL AND approved_by IS NOT NULL) OR
        (status != 'approved')
    ),
    CONSTRAINT warehouse_requests_executed_at_check CHECK (
        (status = 'executed' AND executed_at IS NOT NULL AND executed_by IS NOT NULL) OR
        (status != 'executed')
    )
);

-- إنشاء جدول عناصر طلبات السحب
CREATE TABLE IF NOT EXISTS public.warehouse_request_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES public.warehouse_requests(id) ON DELETE CASCADE NOT NULL,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- قيود للتأكد من صحة البيانات
    CONSTRAINT warehouse_request_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT warehouse_request_items_unique UNIQUE (request_id, product_id)
);

-- إنشاء جدول معاملات المخزن (سجل التحركات)
CREATE TABLE IF NOT EXISTS public.warehouse_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_number TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,
    warehouse_id UUID REFERENCES public.warehouses(id) NOT NULL,
    target_warehouse_id UUID REFERENCES public.warehouses(id), -- للنقل بين المخازن
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    quantity_before INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    reason TEXT NOT NULL,
    notes TEXT,
    reference_id TEXT, -- مرجع الطلب أو الفاتورة
    reference_type TEXT, -- نوع المرجع (request, order, manual)
    performed_by UUID REFERENCES auth.users(id) NOT NULL,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- قيود للتأكد من صحة البيانات
    CONSTRAINT warehouse_transactions_type_valid CHECK (type IN ('stock_in', 'stock_out', 'transfer', 'adjustment', 'return')),
    CONSTRAINT warehouse_transactions_quantity_positive CHECK (quantity > 0),
    CONSTRAINT warehouse_transactions_quantity_before_positive CHECK (quantity_before >= 0),
    CONSTRAINT warehouse_transactions_quantity_after_positive CHECK (quantity_after >= 0)
);

-- إنشاء فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_warehouses_active ON public.warehouses(is_active);
CREATE INDEX IF NOT EXISTS idx_warehouses_created_by ON public.warehouses(created_by);

CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_warehouse ON public.warehouse_inventory(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product ON public.warehouse_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_low_stock ON public.warehouse_inventory(warehouse_id, product_id) WHERE quantity <= minimum_stock;

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_status ON public.warehouse_requests(status);
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_requested_by ON public.warehouse_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_warehouse ON public.warehouse_requests(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_date ON public.warehouse_requests(requested_at);

CREATE INDEX IF NOT EXISTS idx_warehouse_request_items_request ON public.warehouse_request_items(request_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_request_items_product ON public.warehouse_request_items(product_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_warehouse ON public.warehouse_transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_product ON public.warehouse_transactions(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_type ON public.warehouse_transactions(type);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_date ON public.warehouse_transactions(performed_at);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_reference ON public.warehouse_transactions(reference_id, reference_type);

-- إنشاء دوال مساعدة

-- دالة لتوليد رقم طلب فريد
CREATE OR REPLACE FUNCTION generate_warehouse_request_number()
RETURNS TEXT AS $$
DECLARE
    new_number TEXT;
    counter INTEGER;
BEGIN
    -- الحصول على العداد التالي لليوم الحالي
    SELECT COALESCE(MAX(CAST(SUBSTRING(request_number FROM 'WR-\d{8}-(\d+)') AS INTEGER)), 0) + 1
    INTO counter
    FROM public.warehouse_requests
    WHERE request_number LIKE 'WR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-%';
    
    -- تكوين الرقم الجديد
    new_number := 'WR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(counter::TEXT, 4, '0');
    
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- دالة لتوليد رقم معاملة فريد
CREATE OR REPLACE FUNCTION generate_warehouse_transaction_number()
RETURNS TEXT AS $$
DECLARE
    new_number TEXT;
    counter INTEGER;
BEGIN
    -- الحصول على العداد التالي لليوم الحالي
    SELECT COALESCE(MAX(CAST(SUBSTRING(transaction_number FROM 'WT-\d{8}-(\d+)') AS INTEGER)), 0) + 1
    INTO counter
    FROM public.warehouse_transactions
    WHERE transaction_number LIKE 'WT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-%';
    
    -- تكوين الرقم الجديد
    new_number := 'WT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(counter::TEXT, 6, '0');
    
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- دالة لتحديث مخزون المخزن
CREATE OR REPLACE FUNCTION update_warehouse_inventory(
    p_warehouse_id UUID,
    p_product_id TEXT,
    p_quantity_change INTEGER,
    p_performed_by UUID,
    p_reason TEXT,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    current_quantity INTEGER;
    new_quantity INTEGER;
    transaction_number TEXT;
    transaction_type TEXT;
BEGIN
    -- الحصول على الكمية الحالية
    SELECT quantity INTO current_quantity
    FROM public.warehouse_inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    -- إذا لم يوجد سجل، إنشاء سجل جديد
    IF current_quantity IS NULL THEN
        current_quantity := 0;
        INSERT INTO public.warehouse_inventory (warehouse_id, product_id, quantity, updated_by)
        VALUES (p_warehouse_id, p_product_id, 0, p_performed_by);
    END IF;
    
    -- حساب الكمية الجديدة
    new_quantity := current_quantity + p_quantity_change;
    
    -- التأكد من أن الكمية الجديدة ليست سالبة
    IF new_quantity < 0 THEN
        RAISE EXCEPTION 'الكمية الجديدة لا يمكن أن تكون سالبة. الكمية الحالية: %, التغيير المطلوب: %', current_quantity, p_quantity_change;
    END IF;
    
    -- تحديث المخزون
    UPDATE public.warehouse_inventory
    SET quantity = new_quantity,
        last_updated = NOW(),
        updated_by = p_performed_by
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    -- تحديد نوع المعاملة
    IF p_quantity_change > 0 THEN
        transaction_type := 'stock_in';
    ELSIF p_quantity_change < 0 THEN
        transaction_type := 'stock_out';
    ELSE
        transaction_type := 'adjustment';
    END IF;
    
    -- توليد رقم المعاملة
    transaction_number := generate_warehouse_transaction_number();
    
    -- إنشاء سجل المعاملة
    INSERT INTO public.warehouse_transactions (
        transaction_number,
        type,
        warehouse_id,
        product_id,
        quantity,
        quantity_before,
        quantity_after,
        reason,
        reference_id,
        reference_type,
        performed_by
    ) VALUES (
        transaction_number,
        transaction_type,
        p_warehouse_id,
        p_product_id,
        ABS(p_quantity_change),
        current_quantity,
        new_quantity,
        p_reason,
        p_reference_id,
        p_reference_type,
        p_performed_by
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- إنشاء المشغلات (Triggers)

-- مشغل لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- تطبيق المشغل على الجداول
-- حذف المشغل إذا كان موجوداً ثم إنشاؤه من جديد
DROP TRIGGER IF EXISTS update_warehouses_updated_at ON public.warehouses;
CREATE TRIGGER update_warehouses_updated_at
    BEFORE UPDATE ON public.warehouses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- مشغل لتوليد رقم الطلب تلقائياً
CREATE OR REPLACE FUNCTION set_warehouse_request_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.request_number IS NULL OR NEW.request_number = '' THEN
        NEW.request_number := generate_warehouse_request_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- حذف المشغل إذا كان موجوداً ثم إنشاؤه من جديد
DROP TRIGGER IF EXISTS set_warehouse_request_number_trigger ON public.warehouse_requests;
CREATE TRIGGER set_warehouse_request_number_trigger
    BEFORE INSERT ON public.warehouse_requests
    FOR EACH ROW
    EXECUTE FUNCTION set_warehouse_request_number();

-- مشغل لتوليد رقم المعاملة تلقائياً
CREATE OR REPLACE FUNCTION set_warehouse_transaction_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.transaction_number IS NULL OR NEW.transaction_number = '' THEN
        NEW.transaction_number := generate_warehouse_transaction_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- حذف المشغل إذا كان موجوداً ثم إنشاؤه من جديد
DROP TRIGGER IF EXISTS set_warehouse_transaction_number_trigger ON public.warehouse_transactions;
CREATE TRIGGER set_warehouse_transaction_number_trigger
    BEFORE INSERT ON public.warehouse_transactions
    FOR EACH ROW
    EXECUTE FUNCTION set_warehouse_transaction_number();

-- تفعيل Row Level Security (RLS)
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_transactions ENABLE ROW LEVEL SECURITY;

-- إنشاء سياسات RLS

-- سياسات جدول المخازن
-- حذف السياسات الموجودة إذا كانت موجودة ثم إنشاؤها من جديد
DROP POLICY IF EXISTS "المخازن قابلة للقراءة من قبل المستخدمين المصرح لهم" ON public.warehouses;
CREATE POLICY "المخازن قابلة للقراءة من قبل المستخدمين المصرح لهم"
    ON public.warehouses FOR SELECT
    USING (
        auth.role() = 'authenticated' AND (
            -- مدير النظام يمكنه رؤية كل شيء
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager', 'accountant')
            )
        )
    );

DROP POLICY IF EXISTS "المخازن قابلة للإنشاء من قبل المديرين ومديري المخازن" ON public.warehouses;
CREATE POLICY "المخازن قابلة للإنشاء من قبل المديرين ومديري المخازن"
    ON public.warehouses FOR INSERT
    WITH CHECK (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager')
            )
        )
    );

DROP POLICY IF EXISTS "المخازن قابلة للتحديث من قبل المديرين ومديري المخازن" ON public.warehouses;
CREATE POLICY "المخازن قابلة للتحديث من قبل المديرين ومديري المخازن"
    ON public.warehouses FOR UPDATE
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager')
            )
        )
    );

DROP POLICY IF EXISTS "المخازن قابلة للحذف من قبل المديرين فقط" ON public.warehouses;
CREATE POLICY "المخازن قابلة للحذف من قبل المديرين فقط"
    ON public.warehouses FOR DELETE
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner')
            )
        )
    );

-- سياسات جدول مخزون المخازن
DROP POLICY IF EXISTS "مخزون المخازن قابل للقراءة من قبل المستخدمين المصرح لهم" ON public.warehouse_inventory;
CREATE POLICY "مخزون المخازن قابل للقراءة من قبل المستخدمين المصرح لهم"
    ON public.warehouse_inventory FOR SELECT
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager', 'accountant', 'worker')
            )
        )
    );

DROP POLICY IF EXISTS "مخزون المخازن قابل للتحديث من قبل مديري المخازن" ON public.warehouse_inventory;
CREATE POLICY "مخزون المخازن قابل للتحديث من قبل مديري المخازن"
    ON public.warehouse_inventory FOR ALL
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager')
            )
        )
    );

-- سياسات جدول طلبات السحب
DROP POLICY IF EXISTS "طلبات السحب قابلة للقراءة من قبل المستخدمين المصرح لهم" ON public.warehouse_requests;
CREATE POLICY "طلبات السحب قابلة للقراءة من قبل المستخدمين المصرح لهم"
    ON public.warehouse_requests FOR SELECT
    USING (
        auth.role() = 'authenticated' AND (
            -- المستخدم يمكنه رؤية طلباته الخاصة
            requested_by = auth.uid() OR
            -- أو إذا كان مدير مخزن أو مدير نظام
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager', 'accountant')
            )
        )
    );

DROP POLICY IF EXISTS "طلبات السحب قابلة للإنشاء من قبل المحاسبين والمديرين" ON public.warehouse_requests;
CREATE POLICY "طلبات السحب قابلة للإنشاء من قبل المحاسبين والمديرين"
    ON public.warehouse_requests FOR INSERT
    WITH CHECK (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'accountant', 'warehouse_manager')
            )
        )
    );

DROP POLICY IF EXISTS "طلبات السحب قابلة للتحديث من قبل مديري المخازن والمديرين" ON public.warehouse_requests;
CREATE POLICY "طلبات السحب قابلة للتحديث من قبل مديري المخازن والمديرين"
    ON public.warehouse_requests FOR UPDATE
    USING (
        auth.role() = 'authenticated' AND (
            -- المستخدم يمكنه تحديث طلباته الخاصة (إذا كانت قيد الانتظار)
            (requested_by = auth.uid() AND status = 'pending') OR
            -- أو إذا كان مدير مخزن أو مدير نظام
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager')
            )
        )
    );

-- سياسات جدول عناصر طلبات السحب
DROP POLICY IF EXISTS "عناصر طلبات السحب تتبع نفس سياسات الطلبات" ON public.warehouse_request_items;
CREATE POLICY "عناصر طلبات السحب تتبع نفس سياسات الطلبات"
    ON public.warehouse_request_items FOR ALL
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.warehouse_requests wr
                JOIN public.user_profiles up ON up.id = auth.uid()
                WHERE wr.id = request_id AND (
                    wr.requested_by = auth.uid() OR
                    up.role IN ('admin', 'owner', 'warehouse_manager', 'accountant')
                )
            )
        )
    );

-- سياسات جدول معاملات المخزن
DROP POLICY IF EXISTS "معاملات المخزن قابلة للقراءة من قبل المستخدمين المصرح لهم" ON public.warehouse_transactions;
CREATE POLICY "معاملات المخزن قابلة للقراءة من قبل المستخدمين المصرح لهم"
    ON public.warehouse_transactions FOR SELECT
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager', 'accountant')
            )
        )
    );

DROP POLICY IF EXISTS "معاملات المخزن قابلة للإنشاء من قبل مديري المخازن" ON public.warehouse_transactions;
CREATE POLICY "معاملات المخزن قابلة للإنشاء من قبل مديري المخازن"
    ON public.warehouse_transactions FOR INSERT
    WITH CHECK (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'warehouse_manager')
            )
        )
    );
