-- 🔧 إصلاح مشكلة العلاقة بين جدول المحافظ وملفات المستخدمين
-- Fix Wallet-UserProfile Relationship Issue

-- 1. التحقق من وجود الجداول
SELECT 
    table_name, 
    table_schema 
FROM information_schema.tables 
WHERE table_name IN ('wallets', 'user_profiles') 
    AND table_schema = 'public';

-- 2. التحقق من بنية جدول المحافظ
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'wallets' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. التحقق من بنية جدول ملفات المستخدمين
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. التحقق من المفاتيح الخارجية الموجودة
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'wallets';

-- 5. إنشاء جدول المحافظ إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    role TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'EGP',
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- إضافة قيود
    CONSTRAINT wallets_user_id_unique UNIQUE (user_id),
    CONSTRAINT wallets_balance_check CHECK (balance >= 0),
    CONSTRAINT wallets_status_check CHECK (status IN ('active', 'suspended', 'closed')),
    CONSTRAINT wallets_role_check CHECK (role IN ('admin', 'accountant', 'owner', 'client', 'worker'))
);

-- 6. إنشاء جدول معاملات المحافظ إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    balance_before DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    balance_after DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    description TEXT NOT NULL,
    reference_id UUID,
    reference_type TEXT,
    status TEXT NOT NULL DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}',
    
    -- إضافة قيود
    CONSTRAINT wallet_transactions_amount_check CHECK (amount > 0),
    CONSTRAINT wallet_transactions_status_check CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    CONSTRAINT wallet_transactions_type_check CHECK (transaction_type IN (
        'credit', 'debit', 'reward', 'salary', 'bonus', 'penalty', 'refund', 'payment'
    ))
);

-- 7. إنشاء الفهارس للأداء
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_role ON public.wallets(role);
CREATE INDEX IF NOT EXISTS idx_wallets_status ON public.wallets(status);
CREATE INDEX IF NOT EXISTS idx_wallets_created_at ON public.wallets(created_at);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON public.wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON public.wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON public.wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_status ON public.wallet_transactions(status);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON public.wallet_transactions(created_at);

-- 8. تفعيل Row Level Security
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- 9. إنشاء سياسات الأمان للمحافظ
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all wallets" ON public.wallets;
CREATE POLICY "Admins can view all wallets" ON public.wallets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

DROP POLICY IF EXISTS "Admins can manage wallets" ON public.wallets;
CREATE POLICY "Admins can manage wallets" ON public.wallets
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

-- 10. إنشاء سياسات الأمان لمعاملات المحافظ
DROP POLICY IF EXISTS "Users can view own transactions" ON public.wallet_transactions;
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all transactions" ON public.wallet_transactions;
CREATE POLICY "Admins can view all transactions" ON public.wallet_transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

DROP POLICY IF EXISTS "Admins can manage transactions" ON public.wallet_transactions;
CREATE POLICY "Admins can manage transactions" ON public.wallet_transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

-- 11. إنشاء دالة لتحديث الرصيد
CREATE OR REPLACE FUNCTION update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- تحديث رصيد المحفظة عند إضافة معاملة جديدة
    IF TG_OP = 'INSERT' THEN
        UPDATE public.wallets 
        SET 
            balance = NEW.balance_after,
            updated_at = now()
        WHERE id = NEW.wallet_id;
        
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 12. إنشاء trigger لتحديث الرصيد تلقائياً
DROP TRIGGER IF EXISTS trigger_update_wallet_balance ON public.wallet_transactions;
CREATE TRIGGER trigger_update_wallet_balance
    AFTER INSERT ON public.wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_balance();

-- 13. إنشاء دالة لإنشاء محفظة جديدة
CREATE OR REPLACE FUNCTION create_wallet_for_user(
    p_user_id UUID,
    p_role TEXT,
    p_initial_balance DECIMAL(15,2) DEFAULT 0.00
)
RETURNS UUID AS $$
DECLARE
    wallet_id UUID;
BEGIN
    -- التحقق من عدم وجود محفظة للمستخدم
    IF EXISTS (SELECT 1 FROM public.wallets WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User already has a wallet';
    END IF;

    -- إنشاء المحفظة
    INSERT INTO public.wallets (user_id, role, balance)
    VALUES (p_user_id, p_role, p_initial_balance)
    RETURNING id INTO wallet_id;

    -- إضافة معاملة أولية إذا كان هناك رصيد ابتدائي
    IF p_initial_balance > 0 THEN
        INSERT INTO public.wallet_transactions (
            wallet_id, user_id, transaction_type, amount,
            balance_before, balance_after, description, created_by
        ) VALUES (
            wallet_id, p_user_id, 'credit', p_initial_balance,
            0.00, p_initial_balance, 'رصيد ابتدائي', p_user_id
        );
    END IF;

    RETURN wallet_id;
END;
$$ LANGUAGE plpgsql;

-- 14. إنشاء محافظ للمستخدمين الموجودين (إذا لم تكن موجودة)
INSERT INTO public.wallets (user_id, role, balance)
SELECT 
    up.id,
    up.role,
    CASE 
        WHEN up.role = 'admin' THEN 10000.00
        WHEN up.role = 'owner' THEN 5000.00
        WHEN up.role = 'accountant' THEN 1000.00
        WHEN up.role = 'worker' THEN 500.00
        WHEN up.role = 'client' THEN 100.00
        ELSE 0.00
    END as initial_balance
FROM public.user_profiles up
WHERE up.status = 'approved' 
    AND NOT EXISTS (
        SELECT 1 FROM public.wallets w 
        WHERE w.user_id = up.id
    );

-- 15. عرض النتائج
SELECT 
    'Wallets created successfully' as message,
    COUNT(*) as wallet_count
FROM public.wallets;

SELECT 
    w.id,
    up.name,
    w.role,
    w.balance,
    w.status,
    w.created_at
FROM public.wallets w
LEFT JOIN public.user_profiles up ON w.user_id = up.id
ORDER BY w.role, up.name;

-- ✅ تم إصلاح مشكلة العلاقة بنجاح!
