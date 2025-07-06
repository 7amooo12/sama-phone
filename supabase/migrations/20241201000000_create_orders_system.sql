-- إنشاء نظام الطلبات المتكامل في Supabase
-- Migration: Create comprehensive orders system

-- إنشاء جدول الطلبات الرئيسي
CREATE TABLE IF NOT EXISTS public.client_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES auth.users(id) NOT NULL,
    client_name TEXT NOT NULL,
    client_email TEXT NOT NULL,
    client_phone TEXT NOT NULL,
    
    -- معلومات الطلب
    order_number TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    payment_status TEXT NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    
    -- معلومات الشحن
    shipping_address JSONB,
    shipping_method TEXT,
    tracking_number TEXT,
    
    -- معلومات إضافية
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    -- تعيين الموظفين
    assigned_to UUID REFERENCES auth.users(id),
    assigned_by UUID REFERENCES auth.users(id),
    assigned_at TIMESTAMP WITH TIME ZONE,
    
    -- التواريخ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    
    -- فهرسة للبحث السريع
    CONSTRAINT valid_status CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')),
    CONSTRAINT valid_payment_status CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded'))
);

-- إنشاء جدول عناصر الطلب
CREATE TABLE IF NOT EXISTS public.client_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.client_orders(id) ON DELETE CASCADE NOT NULL,

    -- معلومات المنتج
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    product_image TEXT,
    product_category TEXT,

    -- معلومات السعر والكمية
    unit_price DECIMAL(10, 2) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    subtotal DECIMAL(10, 2) NOT NULL,

    -- معلومات التسعير المعتمد
    approved_unit_price DECIMAL(10, 2), -- السعر المعتمد من المحاسب
    approved_subtotal DECIMAL(10, 2), -- المجموع الفرعي المعتمد
    original_unit_price DECIMAL(10, 2), -- السعر الأصلي للمرجعية
    pricing_approved BOOLEAN DEFAULT FALSE, -- هل تم اعتماد التسعير
    pricing_approved_by UUID REFERENCES auth.users(id), -- من اعتمد التسعير
    pricing_approved_at TIMESTAMP WITH TIME ZONE, -- متى تم اعتماد التسعير

    -- معلومات إضافية
    notes TEXT,
    metadata JSONB DEFAULT '{}',

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- إنشاء جدول روابط التتبع
CREATE TABLE IF NOT EXISTS public.order_tracking_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.client_orders(id) ON DELETE CASCADE NOT NULL,
    
    -- معلومات الرابط
    title TEXT NOT NULL,
    description TEXT,
    url TEXT NOT NULL,
    link_type TEXT DEFAULT 'tracking',
    
    -- معلومات الإنشاء
    created_by UUID REFERENCES auth.users(id) NOT NULL,
    created_by_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- حالة الرابط
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- معلومات إضافية
    metadata JSONB DEFAULT '{}',
    
    CONSTRAINT valid_link_type CHECK (link_type IN ('tracking', 'payment', 'support', 'delivery', 'other'))
);

-- إنشاء جدول تاريخ الطلبات (Order History)
CREATE TABLE IF NOT EXISTS public.order_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.client_orders(id) ON DELETE CASCADE NOT NULL,
    
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
    
    CONSTRAINT valid_action CHECK (action IN ('created', 'status_changed', 'assigned', 'payment_updated', 'tracking_added', 'cancelled', 'completed', 'pricing_approved'))
);

-- إنشاء جدول تاريخ اعتماد التسعير
CREATE TABLE IF NOT EXISTS public.order_pricing_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.client_orders(id) ON DELETE CASCADE NOT NULL,

    -- معلومات التسعير
    item_id UUID REFERENCES public.client_order_items(id) ON DELETE CASCADE NOT NULL,
    original_price DECIMAL(10, 2) NOT NULL,
    approved_price DECIMAL(10, 2) NOT NULL,
    price_difference DECIMAL(10, 2) NOT NULL, -- الفرق في السعر

    -- معلومات المحاسب
    approved_by UUID REFERENCES auth.users(id) NOT NULL,
    approved_by_name TEXT NOT NULL,
    approved_by_role TEXT DEFAULT 'accountant',

    -- ملاحظات التسعير
    pricing_notes TEXT,
    approval_reason TEXT,

    -- التوقيت
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,

    -- معلومات إضافية
    metadata JSONB DEFAULT '{}'
);

-- إنشاء جدول الإشعارات للطلبات
CREATE TABLE IF NOT EXISTS public.order_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.client_orders(id) ON DELETE CASCADE NOT NULL,
    
    -- معلومات الإشعار
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    
    -- المستلمين
    recipient_id UUID REFERENCES auth.users(id) NOT NULL,
    recipient_role TEXT,
    
    -- حالة الإشعار
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    
    -- التوقيت
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- معلومات إضافية
    metadata JSONB DEFAULT '{}',
    
    CONSTRAINT valid_notification_type CHECK (notification_type IN ('order_created', 'status_changed', 'payment_received', 'tracking_added', 'order_completed'))
);

-- إنشاء الفهارس للأداء
CREATE INDEX IF NOT EXISTS idx_client_orders_client_id ON public.client_orders(client_id);
CREATE INDEX IF NOT EXISTS idx_client_orders_status ON public.client_orders(status);
CREATE INDEX IF NOT EXISTS idx_client_orders_created_at ON public.client_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_orders_order_number ON public.client_orders(order_number);
CREATE INDEX IF NOT EXISTS idx_client_orders_assigned_to ON public.client_orders(assigned_to);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.client_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.client_order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_order_items_pricing_approved ON public.client_order_items(pricing_approved);
CREATE INDEX IF NOT EXISTS idx_order_items_pricing_approved_by ON public.client_order_items(pricing_approved_by);

CREATE INDEX IF NOT EXISTS idx_pricing_history_order_id ON public.order_pricing_history(order_id);
CREATE INDEX IF NOT EXISTS idx_pricing_history_item_id ON public.order_pricing_history(item_id);
CREATE INDEX IF NOT EXISTS idx_pricing_history_approved_by ON public.order_pricing_history(approved_by);
CREATE INDEX IF NOT EXISTS idx_pricing_history_created_at ON public.order_pricing_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tracking_links_order_id ON public.order_tracking_links(order_id);
CREATE INDEX IF NOT EXISTS idx_tracking_links_active ON public.order_tracking_links(is_active);

CREATE INDEX IF NOT EXISTS idx_order_history_order_id ON public.order_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_history_created_at ON public.order_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_notifications_recipient ON public.order_notifications(recipient_id, is_read);
CREATE INDEX IF NOT EXISTS idx_order_notifications_order_id ON public.order_notifications(order_id);

-- تفعيل Row Level Security
ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_tracking_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_pricing_history ENABLE ROW LEVEL SECURITY;

-- إنشاء دالة لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- إضافة trigger لتحديث updated_at
CREATE TRIGGER update_client_orders_updated_at 
    BEFORE UPDATE ON public.client_orders 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- إنشاء دالة لتوليد رقم الطلب
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
    order_num TEXT;
    counter INTEGER;
BEGIN
    -- توليد رقم الطلب بناءً على التاريخ والوقت
    order_num := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-';
    
    -- الحصول على العداد اليومي
    SELECT COALESCE(MAX(CAST(SUBSTRING(order_number FROM 'ORD-[0-9]{8}-([0-9]+)') AS INTEGER)), 0) + 1
    INTO counter
    FROM public.client_orders
    WHERE order_number LIKE order_num || '%';
    
    -- إرجاع رقم الطلب الكامل
    RETURN order_num || LPAD(counter::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- إنشاء دالة لإضافة سجل في تاريخ الطلب
CREATE OR REPLACE FUNCTION add_order_history(
    p_order_id UUID,
    p_action TEXT,
    p_old_status TEXT DEFAULT NULL,
    p_new_status TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_changed_by UUID DEFAULT NULL,
    p_changed_by_name TEXT DEFAULT NULL,
    p_changed_by_role TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    history_id UUID;
BEGIN
    INSERT INTO public.order_history (
        order_id, action, old_status, new_status, description,
        changed_by, changed_by_name, changed_by_role
    ) VALUES (
        p_order_id, p_action, p_old_status, p_new_status, p_description,
        p_changed_by, p_changed_by_name, p_changed_by_role
    ) RETURNING id INTO history_id;
    
    RETURN history_id;
END;
$$ LANGUAGE plpgsql;
