-- Create tasks table for Supabase
CREATE TABLE public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    worker_id UUID REFERENCES public.user_profiles(id),
    worker_name TEXT NOT NULL,
    admin_id UUID REFERENCES public.user_profiles(id) NOT NULL,
    admin_name TEXT NOT NULL,
    product_id TEXT,
    product_name TEXT NOT NULL,
    product_image TEXT,
    order_id TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, in_progress, completed
    completed_quantity INTEGER DEFAULT 0,
    progress REAL DEFAULT 0.0,
    category TEXT DEFAULT 'product', -- product or order
    metadata JSONB
);

-- Enable RLS
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Create index
CREATE INDEX tasks_worker_id_idx ON public.tasks(worker_id);
CREATE INDEX tasks_admin_id_idx ON public.tasks(admin_id);
CREATE INDEX tasks_status_idx ON public.tasks(status);

-- RLS policies

-- Workers can view their assigned tasks
CREATE POLICY "Workers can view their assigned tasks"
ON public.tasks
FOR SELECT
USING (auth.uid() = worker_id);

-- Admins can view all tasks
CREATE POLICY "Admins can view all tasks"
ON public.tasks
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Workers can update their own tasks (status, progress, etc.)
CREATE POLICY "Workers can update their assigned tasks"
ON public.tasks
FOR UPDATE
USING (auth.uid() = worker_id)
WITH CHECK (
    auth.uid() = worker_id
    AND (NEW.status = 'in_progress' OR NEW.status = 'completed')
    AND (NEW.admin_id = OLD.admin_id) -- Cannot change admin
    AND (NEW.worker_id = OLD.worker_id) -- Cannot reassign task
    AND (NEW.product_id = OLD.product_id) -- Cannot change product
    AND (NEW.order_id = OLD.order_id) -- Cannot change order
);

-- Admins can create tasks
CREATE POLICY "Admins can create tasks"
ON public.tasks
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Admins can update tasks
CREATE POLICY "Admins can update tasks"
ON public.tasks
FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Admins can delete tasks
CREATE POLICY "Admins can delete tasks"
ON public.tasks
FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Create functions to notify workers when tasks are assigned

CREATE OR REPLACE FUNCTION notify_task_assigned()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        is_read
    ) VALUES (
        NEW.worker_id,
        'تم تعيين مهمة جديدة',
        'تم تعيين مهمة جديدة لك: ' || NEW.title,
        'task_assigned',
        FALSE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_task_assigned
AFTER INSERT ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION notify_task_assigned(); 