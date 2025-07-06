-- =====================================================
-- إصلاح مشاكل نظام المدفوعات الإلكترونية
-- Fix Electronic Payment System Issues
-- =====================================================

-- 1. إصلاح مشكلة null role في جدول wallets
-- Fix null role issue in wallets table

-- أولاً: تحديث جميع المحافظ التي لديها role = null
UPDATE public.wallets 
SET role = 'client' 
WHERE role IS NULL;

-- ثانياً: إضافة قيد NOT NULL لعمود role (إذا لم يكن موجوداً)
ALTER TABLE public.wallets 
ALTER COLUMN role SET NOT NULL;

-- ثالثاً: إضافة قيد افتراضي لعمود role
ALTER TABLE public.wallets 
ALTER COLUMN role SET DEFAULT 'client';

-- =====================================================
-- 2. تحسين دالة process_dual_wallet_transaction
-- Improve process_dual_wallet_transaction function
-- =====================================================

CREATE OR REPLACE FUNCTION public.process_dual_wallet_transaction(
    p_payment_id UUID,
    p_client_wallet_id UUID,
    p_amount DECIMAL(10,2),
    p_approved_by UUID,
    p_admin_notes TEXT DEFAULT NULL,
    p_business_wallet_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_business_wallet_id UUID;
    v_client_balance DECIMAL(10,2);
    v_business_balance DECIMAL(10,2);
    v_result JSON;
BEGIN
    -- التحقق من صحة المعاملات
    IF p_payment_id IS NULL OR p_client_wallet_id IS NULL OR p_amount <= 0 OR p_approved_by IS NULL THEN
        RAISE EXCEPTION 'Invalid parameters provided';
    END IF;

    -- التحقق من وجود الدفعة وحالتها
    IF NOT EXISTS (
        SELECT 1 FROM public.electronic_payments 
        WHERE id = p_payment_id AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Payment not found or not in pending status';
    END IF;

    -- الحصول على محفظة الشركة أو إنشاؤها
    IF p_business_wallet_id IS NULL THEN
        -- البحث عن محفظة الشركة الافتراضية
        SELECT id INTO v_business_wallet_id
        FROM public.wallets
        WHERE wallet_type = 'business' 
        AND status = 'active' 
        AND is_active = true
        LIMIT 1;

        -- إنشاء محفظة الشركة إذا لم تكن موجودة
        IF v_business_wallet_id IS NULL THEN
            INSERT INTO public.wallets (
                user_id, role, wallet_type, balance, currency, status, is_active,
                created_at, updated_at, metadata
            ) VALUES (
                p_approved_by, 'admin', 'business', 0.0, 'EGP', 'active', true,
                NOW(), NOW(), 
                '{"type": "business_main_wallet", "description": "محفظة الشركة الرئيسية", "auto_created": true}'::jsonb
            ) RETURNING id INTO v_business_wallet_id;
        END IF;
    ELSE
        v_business_wallet_id := p_business_wallet_id;
    END IF;

    -- التحقق من رصيد العميل
    SELECT balance INTO v_client_balance
    FROM public.wallets
    WHERE id = p_client_wallet_id AND is_active = true;

    IF v_client_balance IS NULL THEN
        RAISE EXCEPTION 'Client wallet not found or inactive';
    END IF;

    IF v_client_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient client wallet balance. Current: %, Required: %', v_client_balance, p_amount;
    END IF;

    -- بدء المعاملة
    BEGIN
        -- خصم المبلغ من محفظة العميل
        UPDATE public.wallets
        SET balance = balance - p_amount,
            updated_at = NOW()
        WHERE id = p_client_wallet_id;

        -- إضافة المبلغ إلى محفظة الشركة
        UPDATE public.wallets
        SET balance = balance + p_amount,
            updated_at = NOW()
        WHERE id = v_business_wallet_id;

        -- تسجيل معاملة الخصم من محفظة العميل
        INSERT INTO public.wallet_transactions (
            wallet_id, transaction_type, amount, balance_after,
            description, reference_type, reference_id, created_by, created_at
        ) VALUES (
            p_client_wallet_id, 'debit', p_amount, v_client_balance - p_amount,
            'خصم مقابل دفعة إلكترونية مقبولة', 'electronic_payment', p_payment_id,
            p_approved_by, NOW()
        );

        -- تسجيل معاملة الإضافة إلى محفظة الشركة
        SELECT balance INTO v_business_balance FROM public.wallets WHERE id = v_business_wallet_id;
        
        INSERT INTO public.wallet_transactions (
            wallet_id, transaction_type, amount, balance_after,
            description, reference_type, reference_id, created_by, created_at
        ) VALUES (
            v_business_wallet_id, 'credit', p_amount, v_business_balance,
            'إضافة من دفعة إلكترونية مقبولة', 'electronic_payment', p_payment_id,
            p_approved_by, NOW()
        );

        -- تحديث حالة الدفعة
        UPDATE public.electronic_payments
        SET status = 'approved',
            approved_by = p_approved_by,
            approved_at = NOW(),
            admin_notes = p_admin_notes,
            updated_at = NOW()
        WHERE id = p_payment_id;

        -- إنشاء النتيجة
        v_result := json_build_object(
            'success', true,
            'payment_id', p_payment_id,
            'client_wallet_id', p_client_wallet_id,
            'business_wallet_id', v_business_wallet_id,
            'amount', p_amount,
            'client_balance_after', v_client_balance - p_amount,
            'business_balance_after', v_business_balance,
            'approved_by', p_approved_by,
            'approved_at', NOW()
        );

        RETURN v_result;

    EXCEPTION WHEN OTHERS THEN
        -- في حالة حدوث خطأ، إلغاء جميع التغييرات
        RAISE EXCEPTION 'Dual wallet transaction failed: %', SQLERRM;
    END;
END;
$$;

-- =====================================================
-- 3. إضافة دالة للحصول على محفظة العميل أو إنشاؤها
-- Add function to get or create client wallet
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_client_wallet(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wallet_id UUID;
    v_user_role TEXT;
BEGIN
    -- البحث عن محفظة موجودة
    SELECT id INTO v_wallet_id
    FROM public.wallets
    WHERE user_id = p_user_id 
    AND wallet_type = 'personal' 
    AND is_active = true
    LIMIT 1;

    -- إذا وجدت المحفظة، إرجاع معرفها
    IF v_wallet_id IS NOT NULL THEN
        RETURN v_wallet_id;
    END IF;

    -- الحصول على دور المستخدم
    SELECT role INTO v_user_role
    FROM public.user_profiles
    WHERE id = p_user_id;

    -- إذا لم يوجد دور، استخدام 'client' كافتراضي
    IF v_user_role IS NULL THEN
        v_user_role := 'client';
    END IF;

    -- إنشاء محفظة جديدة
    INSERT INTO public.wallets (
        user_id, role, wallet_type, balance, currency, status, is_active,
        created_at, updated_at, metadata
    ) VALUES (
        p_user_id, v_user_role, 'personal', 0.0, 'EGP', 'active', true,
        NOW(), NOW(),
        '{"type": "client_personal_wallet", "description": "محفظة العميل الشخصية", "auto_created": true}'::jsonb
    ) RETURNING id INTO v_wallet_id;

    RETURN v_wallet_id;
END;
$$;

-- =====================================================
-- 4. تحديث قيد reference_type في جدول wallet_transactions
-- Update reference_type constraint in wallet_transactions table
-- =====================================================

-- أولاً: فحص جميع القيم الموجودة في reference_type
-- First: Check all existing values in reference_type
DO $$
DECLARE
    existing_types TEXT[];
    type_record RECORD;
BEGIN
    -- جمع جميع القيم الفريدة الموجودة
    SELECT ARRAY_AGG(DISTINCT reference_type) INTO existing_types
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL;

    -- طباعة القيم الموجودة للمراجعة
    RAISE NOTICE 'Existing reference_type values: %', existing_types;

    -- تحديث أي قيم غير صالحة إلى 'adjustment'
    UPDATE public.wallet_transactions
    SET reference_type = 'adjustment'
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN (
        'order', 'refund', 'adjustment', 'transfer',
        'electronic_payment', 'wallet_topup', 'wallet_withdrawal',
        'payment', 'deposit', 'withdrawal', 'top_up'
    );

    -- تحديث القيم المشابهة لتوحيد التسمية
    UPDATE public.wallet_transactions
    SET reference_type = 'wallet_topup'
    WHERE reference_type IN ('top_up', 'topup');

    UPDATE public.wallet_transactions
    SET reference_type = 'wallet_withdrawal'
    WHERE reference_type IN ('withdrawal');

    UPDATE public.wallet_transactions
    SET reference_type = 'electronic_payment'
    WHERE reference_type IN ('payment');

    UPDATE public.wallet_transactions
    SET reference_type = 'wallet_topup'
    WHERE reference_type IN ('deposit');

    RAISE NOTICE 'Updated wallet_transactions reference_type values for consistency';
END $$;

-- إزالة القيد القديم إذا كان موجوداً
ALTER TABLE public.wallet_transactions
DROP CONSTRAINT IF EXISTS wallet_transactions_reference_type_valid;

-- إضافة القيد الجديد مع تضمين جميع القيم المحتملة
ALTER TABLE public.wallet_transactions
ADD CONSTRAINT wallet_transactions_reference_type_valid
CHECK (reference_type IN (
    'order', 'refund', 'adjustment', 'transfer',
    'electronic_payment', 'wallet_topup', 'wallet_withdrawal'
));

-- =====================================================
-- 5. إنشاء فهارس لتحسين الأداء
-- Create indexes for performance improvement
-- =====================================================

-- فهرس على client_id في جدول electronic_payments
CREATE INDEX IF NOT EXISTS idx_electronic_payments_client_id 
ON public.electronic_payments(client_id);

-- فهرس على status في جدول electronic_payments
CREATE INDEX IF NOT EXISTS idx_electronic_payments_status 
ON public.electronic_payments(status);

-- فهرس على user_id و wallet_type في جدول wallets
CREATE INDEX IF NOT EXISTS idx_wallets_user_id_wallet_type 
ON public.wallets(user_id, wallet_type);

-- فهرس على reference_type و reference_id في جدول wallet_transactions
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_reference 
ON public.wallet_transactions(reference_type, reference_id);

-- =====================================================
-- 6. إنشاء view محسن للمدفوعات مع معلومات العملاء
-- Create enhanced view for payments with client information
-- =====================================================

CREATE OR REPLACE VIEW public.enhanced_payments_view AS
SELECT 
    ep.*,
    up.name as client_name,
    up.email as client_email,
    up.phone_number as client_phone,
    pa.account_number as recipient_account_number,
    pa.account_holder_name as recipient_account_holder_name,
    approver.name as approved_by_name,
    w.balance as client_current_balance
FROM public.electronic_payments ep
LEFT JOIN public.user_profiles up ON ep.client_id = up.id
LEFT JOIN public.payment_accounts pa ON ep.recipient_account_id = pa.id
LEFT JOIN public.user_profiles approver ON ep.approved_by = approver.id
LEFT JOIN public.wallets w ON ep.client_id = w.user_id AND w.wallet_type = 'personal' AND w.is_active = true;

-- =====================================================
-- 7. منح الصلاحيات المناسبة
-- Grant appropriate permissions
-- =====================================================

-- منح صلاحيات للدوال
GRANT EXECUTE ON FUNCTION public.process_dual_wallet_transaction TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_client_wallet TO authenticated;

-- منح صلاحيات للـ view
GRANT SELECT ON public.enhanced_payments_view TO authenticated;

-- =====================================================
-- تم الانتهاء من إصلاح مشاكل نظام المدفوعات الإلكترونية
-- Electronic Payment System Issues Fixed Successfully
-- =====================================================

-- للتحقق من نجاح الإصلاحات، يمكن تشغيل الاستعلامات التالية:

-- 1. التحقق من عدم وجود محافظ بـ role = null
-- SELECT COUNT(*) as null_role_wallets FROM public.wallets WHERE role IS NULL;

-- 2. التحقق من وجود القيد الجديد
-- SELECT conname FROM pg_constraint WHERE conname = 'wallet_transactions_reference_type_valid';

-- 3. اختبار دالة إنشاء المحفظة
-- SELECT public.get_or_create_client_wallet('your-user-id-here');

-- 4. عرض المدفوعات مع معلومات العملاء
-- SELECT * FROM public.enhanced_payments_view LIMIT 5;
