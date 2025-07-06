-- 🚨 إصلاح طارئ لنظام المحافظ
-- Emergency Wallet System Fix

-- 1. حذف الجداول الموجودة إذا كانت تسبب مشاكل
DROP TABLE IF EXISTS wallet_transactions CASCADE;
DROP TABLE IF EXISTS wallets CASCADE;

-- 2. إنشاء جدول المحافظ من جديد
CREATE TABLE wallets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    currency TEXT DEFAULT 'EGP' NOT NULL,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. إنشاء جدول معاملات المحفظة من جديد
CREATE TABLE wallet_transactions (
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

-- 4. إنشاء الفهارس
CREATE INDEX idx_wallets_user_id ON wallets(user_id);
CREATE INDEX idx_wallets_role ON wallets(role);
CREATE INDEX idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_transactions_created_at ON wallet_transactions(created_at);

-- 5. تفعيل RLS
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- 6. إنشاء سياسات الأمان
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

-- 7. إنشاء محافظ للمستخدمين الموجودين (طريقة بسيطة)
INSERT INTO wallets (user_id, role, balance)
SELECT 
    up.id,
    up.role,
    CASE 
        WHEN up.role = 'client' THEN 1000.00
        WHEN up.role = 'worker' THEN 500.00
        ELSE 0.00
    END as initial_balance
FROM user_profiles up;

-- 8. إضافة معاملات ابتدائية
INSERT INTO wallet_transactions (
    wallet_id, user_id, transaction_type, amount, 
    balance_before, balance_after, description, created_by
)
SELECT 
    w.id,
    w.user_id,
    'credit',
    w.balance,
    0.00,
    w.balance,
    'رصيد ابتدائي',
    w.user_id
FROM wallets w
WHERE w.balance > 0;

-- 9. التحقق من النتائج
SELECT 
    COUNT(*) as total_wallets,
    SUM(CASE WHEN role = 'client' THEN 1 ELSE 0 END) as client_wallets,
    SUM(CASE WHEN role = 'worker' THEN 1 ELSE 0 END) as worker_wallets,
    SUM(CASE WHEN role = 'admin' THEN 1 ELSE 0 END) as admin_wallets,
    SUM(balance) as total_balance
FROM wallets;

-- 10. عرض المحافظ المنشأة
SELECT 
    w.id,
    up.name,
    w.role,
    w.balance,
    w.status
FROM wallets w
LEFT JOIN user_profiles up ON w.user_id = up.id
ORDER BY w.role, up.name;

-- ✅ تم إعداد نظام المحافظ بنجاح!
