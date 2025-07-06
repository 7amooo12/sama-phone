-- Treasury Fund Transfer System
-- This migration adds comprehensive fund transfer functionality between treasuries
-- with proper validation, exchange rate conversion, and audit trail

-- Step 1: Create comprehensive treasury transfer function
CREATE OR REPLACE FUNCTION public.transfer_between_treasuries(
    source_treasury_uuid UUID,
    target_treasury_uuid UUID,
    transfer_amount DECIMAL(15,2),
    transfer_description TEXT DEFAULT 'تحويل بين الخزائن',
    user_uuid UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    source_balance DECIMAL(15,2);
    target_balance DECIMAL(15,2);
    source_rate DECIMAL(10,4);
    target_rate DECIMAL(10,4);
    equivalent_amount DECIMAL(15,2);
    transfer_id UUID;
    source_transaction_id UUID;
    target_transaction_id UUID;
BEGIN
    -- Validate transfer amount
    IF transfer_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ التحويل يجب أن يكون أكبر من صفر';
    END IF;
    
    -- Validate that source and target are different
    IF source_treasury_uuid = target_treasury_uuid THEN
        RAISE EXCEPTION 'لا يمكن التحويل إلى نفس الخزنة';
    END IF;
    
    -- Get source treasury info
    SELECT balance, exchange_rate_to_egp INTO source_balance, source_rate
    FROM treasury_vaults WHERE id = source_treasury_uuid;
    
    -- Get target treasury info
    SELECT balance, exchange_rate_to_egp INTO target_balance, target_rate
    FROM treasury_vaults WHERE id = target_treasury_uuid;
    
    -- Check if both treasuries exist
    IF source_balance IS NULL OR target_balance IS NULL THEN
        RAISE EXCEPTION 'إحدى الخزائن أو كلاهما غير موجود';
    END IF;
    
    -- Check if source has sufficient balance
    IF source_balance < transfer_amount THEN
        RAISE EXCEPTION 'الرصيد غير كافي في الخزنة المصدر. الرصيد المتاح: %', source_balance;
    END IF;
    
    -- Calculate equivalent amount in target currency
    equivalent_amount := transfer_amount * source_rate / target_rate;
    
    -- Generate transfer ID
    transfer_id := gen_random_uuid();
    
    -- Create source transaction (debit)
    INSERT INTO treasury_transactions (
        treasury_id, transaction_type, amount, 
        balance_before, balance_after, description,
        reference_id, created_by
    ) VALUES (
        source_treasury_uuid, 'transfer_out', transfer_amount,
        source_balance, source_balance - transfer_amount,
        transfer_description || ' (صادر إلى ' || (SELECT name FROM treasury_vaults WHERE id = target_treasury_uuid) || ')',
        transfer_id, user_uuid
    ) RETURNING id INTO source_transaction_id;
    
    -- Create target transaction (credit)
    INSERT INTO treasury_transactions (
        treasury_id, transaction_type, amount,
        balance_before, balance_after, description,
        reference_id, created_by
    ) VALUES (
        target_treasury_uuid, 'transfer_in', equivalent_amount,
        target_balance, target_balance + equivalent_amount,
        transfer_description || ' (وارد من ' || (SELECT name FROM treasury_vaults WHERE id = source_treasury_uuid) || ')',
        transfer_id, user_uuid
    ) RETURNING id INTO target_transaction_id;
    
    -- Update source treasury balance
    UPDATE treasury_vaults 
    SET balance = source_balance - transfer_amount,
        updated_at = NOW()
    WHERE id = source_treasury_uuid;
    
    -- Update target treasury balance
    UPDATE treasury_vaults 
    SET balance = target_balance + equivalent_amount,
        updated_at = NOW()
    WHERE id = target_treasury_uuid;
    
    RETURN transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Create function to get transfer details
CREATE OR REPLACE FUNCTION public.get_transfer_details(
    transfer_reference_id UUID
) RETURNS TABLE (
    transfer_id UUID,
    source_treasury_id UUID,
    source_treasury_name TEXT,
    target_treasury_id UUID,
    target_treasury_name TEXT,
    source_amount DECIMAL(15,2),
    target_amount DECIMAL(15,2),
    exchange_rate_used DECIMAL(10,4),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    created_by UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        transfer_reference_id as transfer_id,
        st.treasury_id as source_treasury_id,
        sv.name as source_treasury_name,
        tt.treasury_id as target_treasury_id,
        tv.name as target_treasury_name,
        st.amount as source_amount,
        tt.amount as target_amount,
        (st.amount / tt.amount) as exchange_rate_used,
        REPLACE(REPLACE(st.description, ' (صادر إلى ' || tv.name || ')', ''), ' (وارد من ' || sv.name || ')', '') as description,
        st.created_at,
        st.created_by
    FROM treasury_transactions st
    JOIN treasury_transactions tt ON st.reference_id = tt.reference_id
    JOIN treasury_vaults sv ON st.treasury_id = sv.id
    JOIN treasury_vaults tv ON tt.treasury_id = tv.id
    WHERE st.reference_id = transfer_reference_id
    AND st.transaction_type = 'transfer_out'
    AND tt.transaction_type = 'transfer_in'
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create function to validate transfer before execution
CREATE OR REPLACE FUNCTION public.validate_treasury_transfer(
    source_treasury_uuid UUID,
    target_treasury_uuid UUID,
    transfer_amount DECIMAL(15,2)
) RETURNS JSONB AS $$
DECLARE
    source_balance DECIMAL(15,2);
    target_balance DECIMAL(15,2);
    source_rate DECIMAL(10,4);
    target_rate DECIMAL(10,4);
    equivalent_amount DECIMAL(15,2);
    validation_result JSONB;
BEGIN
    -- Initialize result
    validation_result := jsonb_build_object(
        'is_valid', false,
        'errors', jsonb_build_array(),
        'warnings', jsonb_build_array(),
        'transfer_details', jsonb_build_object()
    );
    
    -- Validate transfer amount
    IF transfer_amount <= 0 THEN
        validation_result := jsonb_set(
            validation_result, 
            '{errors}', 
            validation_result->'errors' || jsonb_build_array('مبلغ التحويل يجب أن يكون أكبر من صفر')
        );
        RETURN validation_result;
    END IF;
    
    -- Validate that source and target are different
    IF source_treasury_uuid = target_treasury_uuid THEN
        validation_result := jsonb_set(
            validation_result, 
            '{errors}', 
            validation_result->'errors' || jsonb_build_array('لا يمكن التحويل إلى نفس الخزنة')
        );
        RETURN validation_result;
    END IF;
    
    -- Get treasury information
    SELECT balance, exchange_rate_to_egp INTO source_balance, source_rate
    FROM treasury_vaults WHERE id = source_treasury_uuid;
    
    SELECT balance, exchange_rate_to_egp INTO target_balance, target_rate
    FROM treasury_vaults WHERE id = target_treasury_uuid;
    
    -- Check if both treasuries exist
    IF source_balance IS NULL THEN
        validation_result := jsonb_set(
            validation_result, 
            '{errors}', 
            validation_result->'errors' || jsonb_build_array('الخزنة المصدر غير موجودة')
        );
        RETURN validation_result;
    END IF;
    
    IF target_balance IS NULL THEN
        validation_result := jsonb_set(
            validation_result, 
            '{errors}', 
            validation_result->'errors' || jsonb_build_array('الخزنة المستهدفة غير موجودة')
        );
        RETURN validation_result;
    END IF;
    
    -- Check if source has sufficient balance
    IF source_balance < transfer_amount THEN
        validation_result := jsonb_set(
            validation_result, 
            '{errors}', 
            validation_result->'errors' || jsonb_build_array('الرصيد غير كافي في الخزنة المصدر')
        );
        RETURN validation_result;
    END IF;
    
    -- Calculate equivalent amount
    equivalent_amount := transfer_amount * source_rate / target_rate;
    
    -- Add warnings for large transfers (more than 50% of balance)
    IF transfer_amount > (source_balance * 0.5) THEN
        validation_result := jsonb_set(
            validation_result, 
            '{warnings}', 
            validation_result->'warnings' || jsonb_build_array('تحذير: المبلغ المحول يتجاوز 50% من رصيد الخزنة المصدر')
        );
    END IF;
    
    -- Build transfer details
    validation_result := jsonb_set(
        validation_result,
        '{transfer_details}',
        jsonb_build_object(
            'source_amount', transfer_amount,
            'target_amount', equivalent_amount,
            'exchange_rate', source_rate / target_rate,
            'source_balance_after', source_balance - transfer_amount,
            'target_balance_after', target_balance + equivalent_amount
        )
    );
    
    -- Mark as valid if no errors
    IF jsonb_array_length(validation_result->'errors') = 0 THEN
        validation_result := jsonb_set(validation_result, '{is_valid}', 'true'::jsonb);
    END IF;
    
    RETURN validation_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Grant necessary permissions
GRANT EXECUTE ON FUNCTION transfer_between_treasuries(UUID, UUID, DECIMAL, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_transfer_details(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_treasury_transfer(UUID, UUID, DECIMAL) TO authenticated;

-- Step 5: Add helpful indexes for transfer operations
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_transfer_type ON treasury_transactions(transaction_type) WHERE transaction_type IN ('transfer_in', 'transfer_out');
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_reference_transfer ON treasury_transactions(reference_id, transaction_type);
