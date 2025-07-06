-- 🔧 إصلاح سريع لنظام المحافظ
-- Quick Fix for Wallet System

-- 1. إنشاء جدول المحافظ إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS wallets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'accountant', 'owner', 'client', 'worker')),
    balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    currency TEXT DEFAULT 'EGP' NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id)
);

-- 2. إنشاء جدول معاملات المحفظة إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN (
        'credit', 'debit', 'reward', 'salary', 'payment',
        'refund', 'bonus', 'penalty', 'transfer'
    )),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    balance_before DECIMAL(15,2) NOT NULL DEFAULT 0,
    balance_after DECIMAL(15,2) NOT NULL DEFAULT 0,
    description TEXT NOT NULL,
    reference_id TEXT,
    reference_type TEXT CHECK (reference_type IN (
        'order', 'task', 'reward', 'salary', 'manual', 'transfer'
    )),
    status TEXT DEFAULT 'completed' CHECK (status IN (
        'pending', 'completed', 'failed', 'cancelled'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB
);

-- 3. إنشاء الفهارس الأساسية
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);

-- 4. تفعيل RLS
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- 5. حذف السياسات الموجودة وإنشاء سياسات جديدة
DROP POLICY IF EXISTS "Users can view own wallet" ON wallets;
DROP POLICY IF EXISTS "Admins can view all wallets" ON wallets;
DROP POLICY IF EXISTS "Users can view own transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Admins can view all transactions" ON wallet_transactions;

-- سياسات المحافظ
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

-- سياسات المعاملات
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

-- 6. إنشاء محافظ للمستخدمين الموجودين
INSERT INTO wallets (user_id, role, balance)
SELECT
    up.id,
    up.role,
    CASE
        WHEN up.role = 'client' THEN 1000.00
        WHEN up.role = 'worker' THEN 500.00
        ELSE 0.00
    END as initial_balance
FROM user_profiles up
WHERE NOT EXISTS (
    SELECT 1 FROM wallets w WHERE w.user_id = up.id
);

-- 7. إضافة معاملات ابتدائية للمحافظ الجديدة
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
WHERE w.balance > 0
AND NOT EXISTS (
    SELECT 1 FROM wallet_transactions wt
    WHERE wt.wallet_id = w.id
);

-- ✅ تم إصلاح نظام المحافظ!
