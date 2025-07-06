-- Add missing fields to tasks table to match TaskModel
-- This migration adds fields that might be missing if the table was created with an older schema

-- Add assigned_to field if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tasks' AND column_name = 'assigned_to') THEN
        ALTER TABLE public.tasks ADD COLUMN assigned_to TEXT;
        -- Populate assigned_to with worker_id for existing records
        UPDATE public.tasks SET assigned_to = worker_id::text WHERE assigned_to IS NULL;
        -- Make it NOT NULL after populating
        ALTER TABLE public.tasks ALTER COLUMN assigned_to SET NOT NULL;
    END IF;
END $$;

-- Add due_date field if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tasks' AND column_name = 'due_date') THEN
        ALTER TABLE public.tasks ADD COLUMN due_date TIMESTAMP WITH TIME ZONE;
        -- Populate due_date with deadline for existing records
        UPDATE public.tasks SET due_date = deadline WHERE due_date IS NULL;
    END IF;
END $$;

-- Add updated_at field if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tasks' AND column_name = 'updated_at') THEN
        ALTER TABLE public.tasks ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();
        -- Populate updated_at with created_at for existing records
        UPDATE public.tasks SET updated_at = created_at WHERE updated_at IS NULL;
    END IF;
END $$;

-- Add priority field if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tasks' AND column_name = 'priority') THEN
        ALTER TABLE public.tasks ADD COLUMN priority TEXT DEFAULT 'medium';
    END IF;
END $$;

-- Add attachments field if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'tasks' AND column_name = 'attachments') THEN
        ALTER TABLE public.tasks ADD COLUMN attachments JSONB DEFAULT '[]'::jsonb;
    END IF;
END $$;

-- Create trigger to automatically update updated_at field
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists and recreate
DROP TRIGGER IF EXISTS update_tasks_updated_at ON public.tasks;
CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON public.tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
