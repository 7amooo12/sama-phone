-- إنشاء نظام أذون صرف المخزون
-- Warehouse Release Orders System Migration

-- إنشاء جدول أذون صرف المخزون الرئيسي
CREATE TABLE IF NOT EXISTS public.warehouse_release_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_number TEXT UNIQUE NOT NULL,
    original_order_id UUID REFERENCES public.client_orders(id) NOT NULL,
    
    -- معلومات العميل
    client_id UUID REFERENCES auth.users(id) NOT NULL,
    client_name TEXT NOT NULL,
    client_email TEXT NOT NULL,
    client_phone TEXT NOT NULL,
    
    -- معلومات مالية
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    discount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    final_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    
    -- حالة أذن الصرف
    status TEXT NOT NULL DEFAULT 'pendingWarehouseApproval',
    
    -- التواريخ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- معلومات إضافية
    notes TEXT,
    shipping_address TEXT,
    rejection_reason TEXT,
    
    -- تعيين الموظفين
    assigned_to UUID REFERENCES auth.users(id), -- المحاسب الذي أنشأ أذن الصرف
    warehouse_manager_id UUID REFERENCES auth.users(id), -- مدير المخزن المسؤول
    warehouse_manager_name TEXT,
    
    -- بيانات إضافية
    metadata JSONB DEFAULT '{}',
    
    -- قيود التحقق
    CONSTRAINT valid_release_order_status CHECK (status IN (
        'pendingWarehouseApproval',
        'approvedByWarehouse',
        'readyForDelivery',
        'completed',
        'rejected',
        'cancelled'
    )),
    CONSTRAINT valid_amounts CHECK (
        total_amount >= 0 AND 
        discount >= 0 AND 
        final_amount >= 0 AND
        final_amount = total_amount - discount
    ),
    CONSTRAINT valid_approval_data CHECK (
        (status = 'approvedByWarehouse' AND approved_at IS NOT NULL) OR
        (status != 'approvedByWarehouse')
    ),
    CONSTRAINT valid_completion_data CHECK (
        (status = 'completed' AND completed_at IS NOT NULL) OR
        (status != 'completed')
    )
);

-- إنشاء جدول عناصر أذون الصرف
CREATE TABLE IF NOT EXISTS public.warehouse_release_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_id UUID REFERENCES public.warehouse_release_orders(id) ON DELETE CASCADE NOT NULL,
    
    -- معلومات المنتج
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    product_image TEXT,
    product_category TEXT,
    
    -- معلومات الكمية والسعر
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0),
    
    -- معلومات إضافية
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- التوقيت
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- قيود التحقق
    CONSTRAINT valid_subtotal CHECK (subtotal = quantity * unit_price),
    CONSTRAINT unique_product_per_release_order UNIQUE (release_order_id, product_id)
);

-- إنشاء جدول تاريخ أذون الصرف (Release Order History)
CREATE TABLE IF NOT EXISTS public.warehouse_release_order_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_id UUID REFERENCES public.warehouse_release_orders(id) ON DELETE CASCADE NOT NULL,
    
    -- معلومات التغيير
    action TEXT NOT NULL,
    old_status TEXT,
    new_status TEXT,
    description TEXT,
    
    -- معلومات المستخدم
    changed_by UUID REFERENCES auth.users(id),
    changed_by_name TEXT,
    changed_by_role TEXT,
    
    -- التوقيت
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- معلومات إضافية
    metadata JSONB DEFAULT '{}',
    
    CONSTRAINT valid_history_action CHECK (action IN (
        'created',
        'status_changed',
        'approved',
        'rejected',
        'completed',
        'cancelled',
        'delivered',
        'updated'
    ))
);

-- إنشاء الفهارس للأداء
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_status ON public.warehouse_release_orders(status);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_created_at ON public.warehouse_release_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_original_order ON public.warehouse_release_orders(original_order_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_client_id ON public.warehouse_release_orders(client_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_assigned_to ON public.warehouse_release_orders(assigned_to);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_warehouse_manager ON public.warehouse_release_orders(warehouse_manager_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_release_number ON public.warehouse_release_orders(release_order_number);

CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_items_release_order ON public.warehouse_release_order_items(release_order_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_items_product ON public.warehouse_release_order_items(product_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_history_release_order ON public.warehouse_release_order_history(release_order_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_history_created_at ON public.warehouse_release_order_history(created_at DESC);

-- تمكين Row Level Security
ALTER TABLE public.warehouse_release_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_release_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_release_order_history ENABLE ROW LEVEL SECURITY;

-- إنشاء سياسات الأمان

-- سياسة القراءة لأذون الصرف - يمكن للمحاسبين ومديري المخازن والإدارة قراءة أذون الصرف
CREATE POLICY "warehouse_release_orders_read_policy" ON public.warehouse_release_orders
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant', 'warehouseManager')
        )
    );

-- سياسة الإدراج لأذون الصرف - يمكن للمحاسبين والإدارة إنشاء أذون صرف
CREATE POLICY "warehouse_release_orders_insert_policy" ON public.warehouse_release_orders
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant')
        )
    );

-- سياسة التحديث لأذون الصرف - يمكن للمحاسبين ومديري المخازن والإدارة تحديث أذون الصرف
CREATE POLICY "warehouse_release_orders_update_policy" ON public.warehouse_release_orders
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant', 'warehouseManager')
        )
    );

-- سياسة الحذف لأذون الصرف - يمكن للإدارة والمحاسبين حذف أذون الصرف
CREATE POLICY "warehouse_release_orders_delete_policy" ON public.warehouse_release_orders
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant')
        )
    );

-- سياسات مماثلة لعناصر أذون الصرف
CREATE POLICY "warehouse_release_order_items_read_policy" ON public.warehouse_release_order_items
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant', 'warehouseManager')
        )
    );

CREATE POLICY "warehouse_release_order_items_insert_policy" ON public.warehouse_release_order_items
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant')
        )
    );

CREATE POLICY "warehouse_release_order_items_update_policy" ON public.warehouse_release_order_items
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant', 'warehouseManager')
        )
    );

CREATE POLICY "warehouse_release_order_items_delete_policy" ON public.warehouse_release_order_items
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant')
        )
    );

-- سياسات تاريخ أذون الصرف
CREATE POLICY "warehouse_release_order_history_read_policy" ON public.warehouse_release_order_history
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant', 'warehouseManager')
        )
    );

CREATE POLICY "warehouse_release_order_history_insert_policy" ON public.warehouse_release_order_history
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'businessOwner', 'accountant', 'warehouseManager')
        )
    );

-- إنشاء دالة لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_warehouse_release_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء trigger لتحديث updated_at
CREATE TRIGGER warehouse_release_orders_updated_at_trigger
    BEFORE UPDATE ON public.warehouse_release_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_warehouse_release_orders_updated_at();

-- إنشاء دالة لتسجيل تاريخ التغييرات
CREATE OR REPLACE FUNCTION log_warehouse_release_order_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- تسجيل تغيير الحالة
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
        INSERT INTO public.warehouse_release_order_history (
            release_order_id,
            action,
            old_status,
            new_status,
            description,
            changed_by,
            metadata
        ) VALUES (
            NEW.id,
            'status_changed',
            OLD.status,
            NEW.status,
            'تم تغيير حالة أذن الصرف من ' || OLD.status || ' إلى ' || NEW.status,
            auth.uid(),
            jsonb_build_object('trigger', 'auto_log')
        );
    END IF;
    
    -- تسجيل الإنشاء
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.warehouse_release_order_history (
            release_order_id,
            action,
            new_status,
            description,
            changed_by,
            metadata
        ) VALUES (
            NEW.id,
            'created',
            NEW.status,
            'تم إنشاء أذن صرف جديد',
            auth.uid(),
            jsonb_build_object('trigger', 'auto_log')
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- إنشاء trigger لتسجيل التغييرات
CREATE TRIGGER warehouse_release_order_changes_trigger
    AFTER INSERT OR UPDATE ON public.warehouse_release_orders
    FOR EACH ROW
    EXECUTE FUNCTION log_warehouse_release_order_changes();

-- إضافة تعليقات للتوثيق
COMMENT ON TABLE public.warehouse_release_orders IS 'جدول أذون صرف المخزون - يحتوي على أذون الصرف المنشأة من الطلبات المعتمدة';
COMMENT ON TABLE public.warehouse_release_order_items IS 'جدول عناصر أذون الصرف - يحتوي على تفاصيل المنتجات في كل أذن صرف';
COMMENT ON TABLE public.warehouse_release_order_history IS 'جدول تاريخ أذون الصرف - يسجل جميع التغييرات التي تحدث على أذون الصرف';

COMMENT ON COLUMN public.warehouse_release_orders.status IS 'حالة أذن الصرف: pendingWarehouseApproval, approvedByWarehouse, completed, rejected, cancelled';
COMMENT ON COLUMN public.warehouse_release_orders.release_order_number IS 'رقم أذن الصرف الفريد';
COMMENT ON COLUMN public.warehouse_release_orders.original_order_id IS 'معرف الطلب الأصلي الذي تم إنشاء أذن الصرف منه';
