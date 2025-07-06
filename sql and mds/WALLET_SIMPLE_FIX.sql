-- 🔧 إصلاح بسيط لنظام المحافظ
-- Simple Wallet System Fix

-- 1. إنشاء جدول المحافظ
CREATE TABLE IF NOT EXISTS wallets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    currency TEXT DEFAULT 'EGP' NOT NULL,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. إنشاء جدول معاملات المحفظة
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_before DECIMAL(15,2) NOT NULL DEFAULT 0,
    balance_after DECIMAL(15,2) NOT NULL DEFAULT 0,
    description TEXT NOT NULL,
    reference_id TEXT,
    reference_type TEXT,
    status TEXT DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB
);

-- 3. إضافة unique constraint على user_id في wallets
ALTER TABLE wallets ADD CONSTRAINT wallets_user_id_unique UNIQUE (user_id);

-- 4. إنشاء الفهارس
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_role ON wallets(role);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);

-- 5. تفعيل RLS
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- 6. حذف السياسات الموجودة
DROP POLICY IF EXISTS "Users can view own wallet" ON wallets;
DROP POLICY IF EXISTS "Admins can view all wallets" ON wallets;
DROP POLICY IF EXISTS "Users can view own transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Admins can view all transactions" ON wallet_transactions;

-- 7. إنشاء سياسات جديدة
CREATE POLICY "Users can view own wallet" ON wallets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all wallets" ON wallets
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

CREATE POLICY "Users can view own transactions" ON wallet_transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all transactions" ON wallet_transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

-- 8. إنشاء محافظ للمستخدمين (بدون ON CONFLICT)
DO $$
DECLARE
    user_record RECORD;
    initial_balance DECIMAL(15,2);
    wallet_id UUID;
BEGIN
    FOR user_record IN 
        SELECT up.id, up.role 
        FROM user_profiles up 
        WHERE NOT EXISTS (
            SELECT 1 FROM wallets w WHERE w.user_id = up.id
        )
    LOOP
        -- تحديد الرصيد الابتدائي
        CASE user_record.role
            WHEN 'client' THEN initial_balance := 1000.00;
            WHEN 'worker' THEN initial_balance := 500.00;
            ELSE initial_balance := 0.00;
        END CASE;
        
        -- إنشاء المحفظة
        INSERT INTO wallets (user_id, role, balance)
        VALUES (user_record.id, user_record.role, initial_balance)
        RETURNING id INTO wallet_id;
        
        -- إضافة معاملة ابتدائية إذا كان هناك رصيد
        IF initial_balance > 0 THEN
            INSERT INTO wallet_transactions (
                wallet_id, user_id, transaction_type, amount, 
                balance_before, balance_after, description, created_by
            ) VALUES (
                wallet_id, user_record.id, 'credit', initial_balance,
                0.00, initial_balance, 'رصيد ابتدائي', user_record.id
            );
        END IF;
        
        RAISE NOTICE 'Created wallet for user % with balance %', user_record.id, initial_balance;
    END LOOP;
END $$;

-- 9. التحقق من النتائج
SELECT 
    w.id,
    w.user_id,
    up.name,
    w.role,
    w.balance,
    w.status,
    w.created_at
FROM wallets w
LEFT JOIN user_profiles up ON w.user_id = up.id
ORDER BY w.created_at DESC;

-- ✅ تم إعداد نظام المحافظ بنجاح!
