-- =====================================================
-- اختبار نجاح تنظيف المحافظ المكررة
-- Test Wallet Cleanup Success
-- =====================================================

-- هذا السكريپت للتحقق من نجاح عملية تنظيف المحافظ المكررة
-- This script verifies the success of the wallet cleanup operation

DO $$
DECLARE
    duplicate_count INTEGER;
    total_wallets INTEGER;
    total_users INTEGER;
    total_balance NUMERIC;
    backup_exists BOOLEAN;
    rec RECORD;
BEGIN
    RAISE NOTICE '🔍 === بدء اختبار نجاح تنظيف المحافظ ===';
    RAISE NOTICE '🔍 === Starting wallet cleanup success test ===';
    RAISE NOTICE '';

    -- 1. التحقق من وجود النسخة الاحتياطية
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets_backup'
    ) INTO backup_exists;
    
    IF backup_exists THEN
        RAISE NOTICE '✅ النسخة الاحتياطية موجودة';
        RAISE NOTICE '✅ Backup table exists';
    ELSE
        RAISE WARNING '⚠️ النسخة الاحتياطية غير موجودة';
        RAISE WARNING '⚠️ Backup table does not exist';
    END IF;

    -- 2. فحص المحافظ المكررة
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT user_id, wallet_type
        FROM public.wallets 
        WHERE is_active = true
        GROUP BY user_id, wallet_type
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '';
    IF duplicate_count = 0 THEN
        RAISE NOTICE '✅ لا توجد محافظ مكررة - التنظيف نجح';
        RAISE NOTICE '✅ No duplicate wallets found - cleanup successful';
    ELSE
        RAISE WARNING '❌ لا تزال هناك % محافظ مكررة', duplicate_count;
        RAISE WARNING '❌ Still % duplicate wallets remaining', duplicate_count;
        
        -- عرض المحافظ المكررة المتبقية
        RAISE NOTICE 'المحافظ المكررة المتبقية:';
        FOR rec IN 
            SELECT user_id, wallet_type, COUNT(*) as count
            FROM public.wallets 
            WHERE is_active = true
            GROUP BY user_id, wallet_type
            HAVING COUNT(*) > 1
            LIMIT 5
        LOOP
            RAISE NOTICE 'User: %, Type: %, Count: %', rec.user_id, rec.wallet_type, rec.count;
        END LOOP;
    END IF;

    -- 3. إحصائيات عامة
    SELECT COUNT(*), COUNT(DISTINCT user_id), COALESCE(SUM(balance), 0)
    INTO total_wallets, total_users, total_balance
    FROM public.wallets 
    WHERE is_active = true;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 === الإحصائيات الحالية ===';
    RAISE NOTICE '📊 === Current Statistics ===';
    RAISE NOTICE 'إجمالي المحافظ النشطة: %', total_wallets;
    RAISE NOTICE 'إجمالي المستخدمين: %', total_users;
    RAISE NOTICE 'إجمالي الرصيد: % ج.م', total_balance;
    RAISE NOTICE 'Total active wallets: %', total_wallets;
    RAISE NOTICE 'Total users: %', total_users;
    RAISE NOTICE 'Total balance: % EGP', total_balance;

    -- 4. التحقق من القيد الفريد
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'unique_user_wallet_type'
        AND table_name = 'wallets'
    ) THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ القيد الفريد موجود لمنع التكرار';
        RAISE NOTICE '✅ Unique constraint exists to prevent duplicates';
    ELSE
        RAISE WARNING '⚠️ القيد الفريد غير موجود';
        RAISE WARNING '⚠️ Unique constraint not found';
    END IF;

    -- 4.1 التحقق من نوع بيانات العمود id (يجب أن يكون UUID)
    DECLARE
        id_data_type TEXT;
    BEGIN
        SELECT data_type INTO id_data_type
        FROM information_schema.columns
        WHERE table_name = 'wallets'
        AND column_name = 'id'
        AND table_schema = 'public';

        RAISE NOTICE '';
        RAISE NOTICE 'نوع بيانات العمود id: %', id_data_type;
        RAISE NOTICE 'Column id data type: %', id_data_type;

        IF id_data_type = 'uuid' THEN
            RAISE NOTICE '✅ نوع البيانات UUID صحيح - لا مشاكل مع MIN()';
            RAISE NOTICE '✅ UUID data type correct - no MIN() issues';
        ELSE
            RAISE WARNING '⚠️ نوع البيانات غير متوقع: %', id_data_type;
        END IF;
    END;

    -- 5. اختبار وظيفة getClientWalletBalance
    RAISE NOTICE '';
    RAISE NOTICE '🧪 === اختبار وظائف النظام ===';
    RAISE NOTICE '🧪 === Testing System Functions ===';
    
    -- اختبار عينة من المستخدمين
    FOR rec IN 
        SELECT DISTINCT user_id 
        FROM public.wallets 
        WHERE is_active = true 
        LIMIT 3
    LOOP
        DECLARE
            wallet_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO wallet_count
            FROM public.wallets 
            WHERE user_id = rec.user_id AND is_active = true;
            
            IF wallet_count = 1 THEN
                RAISE NOTICE '✅ المستخدم % لديه محفظة واحدة فقط', rec.user_id;
            ELSE
                RAISE WARNING '⚠️ المستخدم % لديه % محافظ', rec.user_id, wallet_count;
            END IF;
        END;
    END LOOP;

    -- 6. النتيجة النهائية
    RAISE NOTICE '';
    IF duplicate_count = 0 AND backup_exists THEN
        RAISE NOTICE '🎉 === اختبار النجاح مكتمل ===';
        RAISE NOTICE '✅ تم تنظيف المحافظ المكررة بنجاح';
        RAISE NOTICE '✅ النظام جاهز لاختبار المدفوعات الإلكترونية';
        RAISE NOTICE '';
        RAISE NOTICE '🎉 === Success test completed ===';
        RAISE NOTICE '✅ Duplicate wallets cleaned successfully';
        RAISE NOTICE '✅ System ready for electronic payments testing';
    ELSE
        RAISE WARNING '❌ === الاختبار فشل ===';
        RAISE WARNING 'يرجى مراجعة السكريپت وإعادة التشغيل';
        RAISE WARNING '❌ === Test failed ===';
        RAISE WARNING 'Please review the script and re-run';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- اختبار سريع لاستعلام getClientWalletBalance
DO $$
DECLARE
    test_user_id UUID;
    wallet_count INTEGER;
BEGIN
    -- اختيار مستخدم عشوائي للاختبار
    SELECT user_id INTO test_user_id
    FROM public.wallets 
    WHERE is_active = true 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- محاكاة استعلام getClientWalletBalance
        SELECT COUNT(*) INTO wallet_count
        FROM public.wallets
        WHERE user_id = test_user_id
        AND wallet_type = 'personal'
        AND is_active = true;
        
        RAISE NOTICE '🧪 اختبار استعلام getClientWalletBalance:';
        RAISE NOTICE 'المستخدم: %', test_user_id;
        RAISE NOTICE 'عدد المحافظ الشخصية: %', wallet_count;
        
        IF wallet_count <= 1 THEN
            RAISE NOTICE '✅ الاستعلام سيعمل بدون أخطاء';
        ELSE
            RAISE WARNING '❌ الاستعلام قد يفشل مع multiple rows';
        END IF;
    END IF;
END $$;

-- رسالة ختامية
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== انتهى اختبار نجاح التنظيف ===';
    RAISE NOTICE '=== Cleanup success test completed ===';
    RAISE NOTICE '';
    RAISE NOTICE 'الخطوة التالية: اختبار المدفوعات الإلكترونية في التطبيق';
    RAISE NOTICE 'Next step: Test electronic payments in the application';
    RAISE NOTICE '';
END $$;
