-- =====================================================
-- ADDITIONAL SUPABASE STORAGE BUCKETS FOR WORKER SYSTEM
-- =====================================================

-- 1. Task Attachments Bucket
-- For workers to upload files with their task submissions
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'task-attachments',
    'task-attachments',
    false, -- Private bucket for security
    52428800, -- 50MB limit
    ARRAY[
        'image/jpeg',
        'image/png', 
        'image/gif',
        'image/webp',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/plain',
        'video/mp4',
        'video/quicktime',
        'audio/mpeg',
        'audio/wav'
    ]
);

-- 2. Task Evidence Bucket  
-- For workers to upload photos/videos as proof of work completion
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'task-evidence',
    'task-evidence', 
    false, -- Private bucket
    104857600, -- 100MB limit for videos
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/gif', 
        'image/webp',
        'video/mp4',
        'video/quicktime',
        'video/webm'
    ]
);

-- 3. Worker Documents Bucket
-- For worker-related documents (contracts, certifications, etc.)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'worker-documents',
    'worker-documents',
    false, -- Private bucket
    20971520, -- 20MB limit
    ARRAY[
        'application/pdf',
        'image/jpeg',
        'image/png',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ]
);

-- 4. Reward Certificates Bucket (Optional)
-- For generating and storing reward certificates/badges
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'reward-certificates',
    'reward-certificates',
    true, -- Public for easy sharing
    5242880, -- 5MB limit
    ARRAY[
        'image/jpeg',
        'image/png',
        'application/pdf'
    ]
);

-- =====================================================
-- STORAGE POLICIES FOR WORKER SYSTEM BUCKETS
-- =====================================================

-- Task Attachments Policies
-- Workers can upload attachments for their own task submissions
CREATE POLICY "Workers can upload task attachments" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'task-attachments' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Workers can view their own task attachments
CREATE POLICY "Workers can view own task attachments" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'task-attachments' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Admins can view all task attachments
CREATE POLICY "Admins can view all task attachments" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'task-attachments' AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Workers can delete their own task attachments
CREATE POLICY "Workers can delete own task attachments" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'task-attachments' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Task Evidence Policies
-- Workers can upload evidence for their tasks
CREATE POLICY "Workers can upload task evidence" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'task-evidence' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Workers can view their own task evidence
CREATE POLICY "Workers can view own task evidence" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'task-evidence' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Admins can view all task evidence
CREATE POLICY "Admins can view all task evidence" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'task-evidence' AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Worker Documents Policies
-- Workers can upload their own documents
CREATE POLICY "Workers can upload own documents" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'worker-documents' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Workers can view their own documents
CREATE POLICY "Workers can view own documents" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'worker-documents' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Admins can view all worker documents
CREATE POLICY "Admins can view all worker documents" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'worker-documents' AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Reward Certificates Policies (Public bucket)
-- Anyone can view reward certificates
CREATE POLICY "Public can view reward certificates" ON storage.objects
    FOR SELECT USING (bucket_id = 'reward-certificates');

-- Only admins can upload reward certificates
CREATE POLICY "Admins can upload reward certificates" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'reward-certificates' AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- =====================================================
-- HELPER FUNCTIONS FOR FILE ORGANIZATION
-- =====================================================

-- Function to generate task attachment path
CREATE OR REPLACE FUNCTION generate_task_attachment_path(
    user_id UUID,
    task_id UUID,
    file_name TEXT
) RETURNS TEXT AS $$
BEGIN
    RETURN user_id::text || '/tasks/' || task_id::text || '/' || file_name;
END;
$$ LANGUAGE plpgsql;

-- Function to generate task evidence path
CREATE OR REPLACE FUNCTION generate_task_evidence_path(
    user_id UUID,
    task_id UUID,
    submission_id UUID,
    file_name TEXT
) RETURNS TEXT AS $$
BEGIN
    RETURN user_id::text || '/evidence/' || task_id::text || '/' || submission_id::text || '/' || file_name;
END;
$$ LANGUAGE plpgsql;

-- Function to generate worker document path
CREATE OR REPLACE FUNCTION generate_worker_document_path(
    user_id UUID,
    document_type TEXT,
    file_name TEXT
) RETURNS TEXT AS $$
BEGIN
    RETURN user_id::text || '/' || document_type || '/' || file_name;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- USAGE EXAMPLES
-- =====================================================

/*
-- Example file paths:

-- Task Attachments:
-- {user_id}/tasks/{task_id}/report.pdf
-- {user_id}/tasks/{task_id}/photo1.jpg

-- Task Evidence:
-- {user_id}/evidence/{task_id}/{submission_id}/before.jpg
-- {user_id}/evidence/{task_id}/{submission_id}/after.jpg
-- {user_id}/evidence/{task_id}/{submission_id}/video.mp4

-- Worker Documents:
-- {user_id}/contracts/employment_contract.pdf
-- {user_id}/certifications/safety_cert.pdf
-- {user_id}/id_documents/national_id.jpg

-- Reward Certificates:
-- certificates/{user_id}/monthly_top_performer.pdf
-- badges/{user_id}/task_completion_badge.png
*/

-- =====================================================
-- CLEANUP FUNCTIONS (Optional)
-- =====================================================

-- Function to clean up old task attachments (older than 1 year)
CREATE OR REPLACE FUNCTION cleanup_old_task_attachments()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
BEGIN
    -- This would be implemented based on your cleanup requirements
    -- Example: Delete attachments for tasks older than 1 year
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- NOTES
-- =====================================================

/*
IMPORTANT NOTES:

1. **Bucket Creation**: Run the INSERT statements in your Supabase SQL editor
2. **Policies**: The policies ensure proper access control based on user roles
3. **File Organization**: Use the helper functions to generate consistent file paths
4. **Security**: Private buckets require authentication, public buckets don't
5. **File Limits**: Adjust file size limits based on your needs
6. **MIME Types**: Add or remove allowed file types as needed

OPTIONAL BUCKETS:
- If you don't need reward certificates, skip that bucket
- You can combine task-attachments and task-evidence into one bucket if preferred
- Worker documents can use the existing 'documents' bucket if you prefer

EXISTING BUCKETS USAGE:
- profile-images: Worker profile photos
- product-images: Not directly related to worker system
- invoices: Could store worker payment invoices
- attachments: Could be used instead of task-attachments
- documents: Could be used instead of worker-documents
*/
