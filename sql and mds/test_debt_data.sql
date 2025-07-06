-- 💰 إنشاء بيانات تجريبية لاختبار عرض الديون
-- Test Debt Data Creation for Debt Display Testing

-- 1. إنشاء معاملات سحب لإنشاء ديون (Create debit transactions to create debts)
INSERT INTO wallet_transactions (
    wallet_id, 
    user_id, 
    transaction_type, 
    amount, 
    balance_before, 
    balance_after, 
    description, 
    created_by,
    status,
    created_at
)
SELECT 
    w.id as wallet_id,
    w.user_id,
    'debit' as transaction_type,
    CASE 
        WHEN w.role = 'client' AND w.balance > 0 THEN w.balance + 500.00  -- Create debt of 500
        ELSE 0
    END as amount,
    w.balance as balance_before,
    CASE 
        WHEN w.role = 'client' AND w.balance > 0 THEN w.balance - (w.balance + 500.00)  -- Resulting negative balance
        ELSE w.balance
    END as balance_after,
    'معاملة تجريبية لإنشاء مديونية للاختبار' as description,
    w.user_id as created_by,
    'completed' as status,
    NOW() as created_at
FROM wallets w
WHERE w.role = 'client' 
AND w.balance > 0
LIMIT 2;  -- Only create debt for 2 clients for testing

-- 2. تحديث أرصدة المحافظ لتعكس الديون (Update wallet balances to reflect debts)
UPDATE wallets 
SET balance = balance - (balance + 500.00),
    updated_at = NOW()
WHERE role = 'client' 
AND balance > 0
AND id IN (
    SELECT wallet_id 
    FROM wallet_transactions 
    WHERE description = 'معاملة تجريبية لإنشاء مديونية للاختبار'
    LIMIT 2
);

-- 3. إنشاء مديونية أخرى بمبلغ مختلف (Create another debt with different amount)
INSERT INTO wallet_transactions (
    wallet_id, 
    user_id, 
    transaction_type, 
    amount, 
    balance_before, 
    balance_after, 
    description, 
    created_by,
    status,
    created_at
)
SELECT 
    w.id as wallet_id,
    w.user_id,
    'debit' as transaction_type,
    w.balance + 1200.00 as amount,  -- Create debt of 1200
    w.balance as balance_before,
    w.balance - (w.balance + 1200.00) as balance_after,  -- Resulting negative balance
    'مديونية تجريبية كبيرة للاختبار' as description,
    w.user_id as created_by,
    'completed' as status,
    NOW() as created_at
FROM wallets w
WHERE w.role = 'client' 
AND w.balance > 0
AND w.id NOT IN (
    SELECT wallet_id 
    FROM wallet_transactions 
    WHERE description = 'معاملة تجريبية لإنشاء مديونية للاختبار'
)
LIMIT 1;  -- Create one more debt

-- 4. تحديث الرصيد للمديونية الثانية (Update balance for second debt)
UPDATE wallets 
SET balance = balance - (balance + 1200.00),
    updated_at = NOW()
WHERE role = 'client' 
AND balance > 0
AND id IN (
    SELECT wallet_id 
    FROM wallet_transactions 
    WHERE description = 'مديونية تجريبية كبيرة للاختبار'
    LIMIT 1
);

-- 5. التحقق من النتائج (Verify results)
SELECT 
    w.id,
    up.full_name as client_name,
    w.balance,
    CASE 
        WHEN w.balance < 0 THEN 'مديون'
        WHEN w.balance > 0 THEN 'دائن'
        ELSE 'صفر'
    END as status,
    ABS(w.balance) as debt_amount,
    w.updated_at
FROM wallets w
JOIN user_profiles up ON w.user_id = up.id
WHERE w.role = 'client'
ORDER BY w.balance ASC;

-- 6. عرض إجمالي الديون (Show total debts)
SELECT 
    COUNT(*) as clients_with_debt,
    SUM(ABS(balance)) as total_debt_amount,
    AVG(ABS(balance)) as average_debt
FROM wallets 
WHERE role = 'client' 
AND balance < 0;

-- ملاحظة: لحذف البيانات التجريبية، استخدم:
-- Note: To delete test data, use:
/*
DELETE FROM wallet_transactions 
WHERE description IN (
    'معاملة تجريبية لإنشاء مديونية للاختبار',
    'مديونية تجريبية كبيرة للاختبار'
);

-- إعادة تعيين الأرصدة للقيم الأصلية
UPDATE wallets 
SET balance = 1000.00, 
    updated_at = NOW()
WHERE role = 'client';
*/
