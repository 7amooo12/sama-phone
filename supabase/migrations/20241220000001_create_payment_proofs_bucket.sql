-- Create payment-proofs storage bucket for electronic payment system
-- Migration: 20241220000001_create_payment_proofs_bucket.sql

-- Create the payment-proofs bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'payment-proofs',
    'payment-proofs',
    true,
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/jpg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for payment-proofs bucket

-- Allow authenticated users to upload payment proofs
CREATE POLICY "Users can upload payment proofs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'payment-proofs' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to view their own payment proofs
CREATE POLICY "Users can view their own payment proofs"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'payment-proofs' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow admins and accountants to view all payment proofs
CREATE POLICY "Admins and accountants can view all payment proofs"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'payment-proofs' AND
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role IN ('admin', 'accountant')
    )
);

-- Allow users to update their own payment proofs
CREATE POLICY "Users can update their own payment proofs"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'payment-proofs' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own payment proofs
CREATE POLICY "Users can delete their own payment proofs"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'payment-proofs' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow admins to delete any payment proofs
CREATE POLICY "Admins can delete any payment proofs"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'payment-proofs' AND
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
);
