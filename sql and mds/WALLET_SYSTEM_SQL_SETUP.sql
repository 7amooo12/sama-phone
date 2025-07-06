-- 💰 نظام المحافظ - إعداد قاعدة البيانات
-- Wallet System Database Setup

-- 1. إنشاء جدول المحافظ (Wallets Table)
CREATE TABLE IF NOT EXISTS wallets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'accountant', 'owner', 'client', 'worker')),
    balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    currency TEXT DEFAULT 'EGP' NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- فهارس للأداء
    UNIQUE(user_id)
);

-- 2. إنشاء جدول معاملات المحفظة (Wallet Transactions Table)
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN (
        'credit', 'debit', 'reward', 'salary', 'payment',
        'refund', 'bonus', 'penalty', 'transfer'
    )),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    balance_before DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
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

-- 3. إنشاء الفهارس للأداء
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_role ON wallets(role);
CREATE INDEX IF NOT EXISTS idx_wallets_status ON wallets(status);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_status ON wallet_transactions(status);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_reference ON wallet_transactions(reference_id, reference_type);

-- 4. إنشاء دالة لتحديث الرصيد
CREATE OR REPLACE FUNCTION update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- تحديث رصيد المحفظة بناءً على نوع المعاملة
    IF NEW.transaction_type IN ('credit', 'reward', 'salary', 'bonus', 'refund') THEN
        -- زيادة الرصيد
        UPDATE wallets
        SET balance = balance + NEW.amount,
            updated_at = NOW()
        WHERE id = NEW.wallet_id;
    ELSE
        -- تقليل الرصيد
        UPDATE wallets
        SET balance = balance - NEW.amount,
            updated_at = NOW()
        WHERE id = NEW.wallet_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. إنشاء trigger لتحديث الرصيد تلقائياً
DROP TRIGGER IF EXISTS trigger_update_wallet_balance ON wallet_transactions;
CREATE TRIGGER trigger_update_wallet_balance
    AFTER INSERT ON wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_balance();

-- 6. إنشاء دالة لحساب الرصيد قبل وبعد المعاملة
CREATE OR REPLACE FUNCTION calculate_transaction_balances()
RETURNS TRIGGER AS $$
DECLARE
    current_balance DECIMAL(15,2);
BEGIN
    -- الحصول على الرصيد الحالي
    SELECT balance INTO current_balance
    FROM wallets
    WHERE id = NEW.wallet_id;

    -- تعيين الرصيد قبل المعاملة
    NEW.balance_before = current_balance;

    -- حساب الرصيد بعد المعاملة
    IF NEW.transaction_type IN ('credit', 'reward', 'salary', 'bonus', 'refund') THEN
        NEW.balance_after = current_balance + NEW.amount;
    ELSE
        NEW.balance_after = current_balance - NEW.amount;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. إنشاء trigger لحساب الأرصدة
DROP TRIGGER IF EXISTS trigger_calculate_balances ON wallet_transactions;
CREATE TRIGGER trigger_calculate_balances
    BEFORE INSERT ON wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION calculate_transaction_balances();

-- 8. إنشاء view لملخص المحافظ
CREATE OR REPLACE VIEW wallet_summary AS
SELECT
    w.id,
    w.user_id,
    w.role,
    w.balance,
    w.currency,
    w.status,
    w.created_at,
    w.updated_at,
    up.name as user_name,
    up.email as user_email,
    up.phone_number,
    COALESCE(t.transaction_count, 0) as transaction_count,
    COALESCE(t.total_credits, 0) as total_credits,
    COALESCE(t.total_debits, 0) as total_debits
FROM wallets w
LEFT JOIN user_profiles up ON w.user_id = up.id
LEFT JOIN (
    SELECT
        wallet_id,
        COUNT(*) as transaction_count,
        SUM(CASE WHEN transaction_type IN ('credit', 'reward', 'salary', 'bonus', 'refund')
            THEN amount ELSE 0 END) as total_credits,
        SUM(CASE WHEN transaction_type IN ('debit', 'payment', 'penalty')
            THEN amount ELSE 0 END) as total_debits
    FROM wallet_transactions
    WHERE status = 'completed'
    GROUP BY wallet_id
) t ON w.id = t.wallet_id;

-- 9. إنشاء دالة لإنشاء محفظة جديدة للمستخدم
CREATE OR REPLACE FUNCTION create_user_wallet(
    p_user_id UUID,
    p_role TEXT,
    p_initial_balance DECIMAL(15,2) DEFAULT 0.00
)
RETURNS UUID AS $$
DECLARE
    wallet_id UUID;
BEGIN
    -- التحقق من عدم وجود محفظة للمستخدم
    IF EXISTS (SELECT 1 FROM wallets WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User already has a wallet';
    END IF;

    -- إنشاء المحفظة
    INSERT INTO wallets (user_id, role, balance)
    VALUES (p_user_id, p_role, p_initial_balance)
    RETURNING id INTO wallet_id;

    -- إضافة معاملة أولية إذا كان هناك رصيد ابتدائي
    IF p_initial_balance > 0 THEN
        INSERT INTO wallet_transactions (
            wallet_id, user_id, transaction_type, amount,
            description, created_by
        ) VALUES (
            wallet_id, p_user_id, 'credit', p_initial_balance,
            'رصيد ابتدائي', p_user_id
        );
    END IF;

    RETURN wallet_id;
END;
$$ LANGUAGE plpgsql;

-- 10. إنشاء دالة لتحويل الأموال بين المحافظ
CREATE OR REPLACE FUNCTION transfer_funds(
    p_from_wallet_id UUID,
    p_to_wallet_id UUID,
    p_amount DECIMAL(15,2),
    p_description TEXT,
    p_created_by UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    from_balance DECIMAL(15,2);
    from_user_id UUID;
    to_user_id UUID;
BEGIN
    -- التحقق من وجود المحافظ
    SELECT balance, user_id INTO from_balance, from_user_id
    FROM wallets WHERE id = p_from_wallet_id AND status = 'active';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source wallet not found or inactive';
    END IF;

    SELECT user_id INTO to_user_id
    FROM wallets WHERE id = p_to_wallet_id AND status = 'active';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination wallet not found or inactive';
    END IF;

    -- التحقق من كفاية الرصيد
    IF from_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance';
    END IF;

    -- إضافة معاملة السحب
    INSERT INTO wallet_transactions (
        wallet_id, user_id, transaction_type, amount,
        description, created_by, reference_type
    ) VALUES (
        p_from_wallet_id, from_user_id, 'transfer', p_amount,
        p_description || ' (تحويل صادر)', p_created_by, 'transfer'
    );

    -- إضافة معاملة الإيداع
    INSERT INTO wallet_transactions (
        wallet_id, user_id, transaction_type, amount,
        description, created_by, reference_type
    ) VALUES (
        p_to_wallet_id, to_user_id, 'credit', p_amount,
        p_description || ' (تحويل وارد)', p_created_by, 'transfer'
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 11. تفعيل RLS (Row Level Security)
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- 12. إنشاء سياسات الأمان
-- سياسة المحافظ - المستخدمون يمكنهم رؤية محافظهم فقط
CREATE POLICY "Users can view own wallet" ON wallets
    FOR SELECT USING (auth.uid() = user_id);

-- سياسة المحافظ - الإدارة يمكنها رؤية جميع المحافظ
CREATE POLICY "Admins can view all wallets" ON wallets
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

-- سياسة المعاملات - المستخدمون يمكنهم رؤية معاملاتهم فقط
CREATE POLICY "Users can view own transactions" ON wallet_transactions
    FOR SELECT USING (auth.uid() = user_id);

-- سياسة المعاملات - الإدارة يمكنها رؤية جميع المعاملات
CREATE POLICY "Admins can view all transactions" ON wallet_transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

-- 13. إنشاء محافظ للمستخدمين الموجودين
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
)
ON CONFLICT (user_id) DO NOTHING;

-- 14. إضافة معاملات ابتدائية للمحافظ الجديدة
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

-- ✅ تم إعداد نظام المحافظ بنجاح!
-- 🎯 الجداول والدوال والسياسات جاهزة للاستخدام
