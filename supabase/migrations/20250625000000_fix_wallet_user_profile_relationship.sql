-- Fix wallet-user_profiles relationship for SmartBizTracker
-- Migration: 20250625000000_fix_wallet_user_profile_relationship.sql
-- Purpose: Add direct foreign key relationship between wallets and user_profiles tables

-- Step 1: Ensure user_profiles table exists with proper structure
DO $$
BEGIN
    -- Check if user_profiles table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles'
    ) THEN
        -- Create user_profiles table if it doesn't exist
        CREATE TABLE public.user_profiles (
            id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            phone_number TEXT,
            role TEXT NOT NULL DEFAULT 'client',
            status TEXT NOT NULL DEFAULT 'pending',
            profile_image TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            metadata JSONB DEFAULT '{}'::jsonb
        );
        
        -- Enable RLS on user_profiles
        ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
        
        RAISE NOTICE 'Created user_profiles table';
    ELSE
        RAISE NOTICE 'user_profiles table already exists';
    END IF;
END $$;

-- Step 2: Add user_profile_id column to wallets table if it doesn't exist
DO $$
BEGIN
    -- Check if user_profile_id column exists in wallets table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'user_profile_id'
    ) THEN
        -- Add the column
        ALTER TABLE public.wallets 
        ADD COLUMN user_profile_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Added user_profile_id column to wallets table';
    ELSE
        RAISE NOTICE 'user_profile_id column already exists in wallets table';
    END IF;
END $$;

-- Step 3: Populate user_profile_id for existing wallets
DO $$
DECLARE
    wallet_record RECORD;
    updated_count INTEGER := 0;
BEGIN
    -- Update existing wallets to set user_profile_id = user_id
    -- This works because both user_id and user_profiles.id reference auth.users(id)
    FOR wallet_record IN 
        SELECT id, user_id 
        FROM public.wallets 
        WHERE user_profile_id IS NULL
    LOOP
        -- Check if corresponding user_profile exists
        IF EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = wallet_record.user_id
        ) THEN
            UPDATE public.wallets 
            SET user_profile_id = wallet_record.user_id 
            WHERE id = wallet_record.id;
            
            updated_count := updated_count + 1;
        ELSE
            RAISE WARNING 'No user_profile found for wallet % with user_id %', 
                wallet_record.id, wallet_record.user_id;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Updated % wallets with user_profile_id', updated_count;
END $$;

-- Step 4: Add constraint to ensure user_id and user_profile_id consistency
DO $$
BEGIN
    -- Add constraint if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND constraint_name = 'wallets_user_consistency'
    ) THEN
        ALTER TABLE public.wallets 
        ADD CONSTRAINT wallets_user_consistency 
        CHECK (user_id = user_profile_id);
        
        RAISE NOTICE 'Added user consistency constraint to wallets table';
    ELSE
        RAISE NOTICE 'User consistency constraint already exists';
    END IF;
END $$;

-- Step 5: Create index for better performance on the new relationship
CREATE INDEX IF NOT EXISTS idx_wallets_user_profile_id 
ON public.wallets(user_profile_id);

-- Step 6: Update the wallet creation trigger to set both user_id and user_profile_id
CREATE OR REPLACE FUNCTION create_user_wallet()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create wallet when user status changes to 'approved'
    IF OLD.status != 'approved' AND NEW.status = 'approved' THEN
        INSERT INTO public.wallets (user_id, user_profile_id, role, balance)
        VALUES (NEW.id, NEW.id, NEW.role, 0.00)
        ON CONFLICT (user_id, role) DO UPDATE SET
            user_profile_id = NEW.id,
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create a function to validate and fix wallet relationships
CREATE OR REPLACE FUNCTION validate_wallet_relationships()
RETURNS TABLE(
    wallet_id UUID,
    user_id UUID,
    user_profile_id UUID,
    status TEXT,
    message TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id as wallet_id,
        w.user_id,
        w.user_profile_id,
        CASE 
            WHEN w.user_profile_id IS NULL THEN 'missing_profile_id'
            WHEN w.user_id != w.user_profile_id THEN 'inconsistent_ids'
            WHEN up.id IS NULL THEN 'missing_user_profile'
            ELSE 'valid'
        END as status,
        CASE 
            WHEN w.user_profile_id IS NULL THEN 'Wallet missing user_profile_id'
            WHEN w.user_id != w.user_profile_id THEN 'user_id and user_profile_id do not match'
            WHEN up.id IS NULL THEN 'Referenced user_profile does not exist'
            ELSE 'Wallet relationship is valid'
        END as message
    FROM public.wallets w
    LEFT JOIN public.user_profiles up ON w.user_profile_id = up.id;
END;
$$ LANGUAGE plpgsql;

-- Step 8: Create a function to fix wallet relationships
CREATE OR REPLACE FUNCTION fix_wallet_relationships()
RETURNS TABLE(
    wallet_id UUID,
    action_taken TEXT,
    success BOOLEAN
) AS $$
DECLARE
    wallet_record RECORD;
BEGIN
    FOR wallet_record IN 
        SELECT w.id, w.user_id, w.user_profile_id
        FROM public.wallets w
        WHERE w.user_profile_id IS NULL 
           OR w.user_id != w.user_profile_id
    LOOP
        BEGIN
            -- Try to fix by setting user_profile_id = user_id
            UPDATE public.wallets 
            SET user_profile_id = wallet_record.user_id,
                updated_at = NOW()
            WHERE id = wallet_record.id;
            
            RETURN QUERY SELECT 
                wallet_record.id,
                'Updated user_profile_id to match user_id'::TEXT,
                TRUE;
                
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY SELECT 
                wallet_record.id,
                'Failed to update: ' || SQLERRM,
                FALSE;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Step 9: Run validation and display results
DO $$
DECLARE
    validation_result RECORD;
    invalid_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Validating wallet relationships...';
    
    FOR validation_result IN 
        SELECT * FROM validate_wallet_relationships()
    LOOP
        IF validation_result.status != 'valid' THEN
            invalid_count := invalid_count + 1;
            RAISE WARNING 'Wallet %: % - %', 
                validation_result.wallet_id, 
                validation_result.status, 
                validation_result.message;
        END IF;
    END LOOP;
    
    IF invalid_count = 0 THEN
        RAISE NOTICE 'All wallet relationships are valid!';
    ELSE
        RAISE NOTICE 'Found % invalid wallet relationships. Run fix_wallet_relationships() to fix them.', invalid_count;
    END IF;
END $$;

-- Step 10: Grant necessary permissions
GRANT SELECT ON public.wallets TO authenticated;
GRANT SELECT ON public.user_profiles TO authenticated;

-- Migration completed successfully
SELECT 'Wallet-UserProfile relationship migration completed successfully' as result;
