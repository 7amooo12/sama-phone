/*
هذا الملف يحدد بنية جداول Supabase المستخدمة في التطبيق
يمكن استخدامه كمرجع لهيكل قاعدة البيانات

SQL CODE FOR CREATING TABLES IN SUPABASE:

-- Enable RLS (Row Level Security)
alter table public.user_profiles enable row level security;

-- Create user_profiles table
create table public.user_profiles (
    id uuid references auth.users on delete cascade primary key,
    email text unique not null,
    name text not null,
    phone_number text,
    role text not null default 'user',
    status text not null default 'pending',
    profile_image text,
    created_at timestamp with time zone default now() not null,
    last_login timestamp with time zone,
    updated_at timestamp with time zone,
    tracking_link text,
    metadata jsonb
);

-- Add RLS policies for user_profiles
-- Allow users to view their own profiles
create policy "Users can view their own profiles"
on public.user_profiles
for select
using (auth.uid() = id);

-- Allow admins to view all profiles
create policy "Admins can view all profiles"
on public.user_profiles
for select
using (
  exists (
    select 1 from public.user_profiles
    where id = auth.uid() and role = 'admin'
  )
);

-- Allow users to update their own profiles
create policy "Users can update their own profiles"
on public.user_profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Allow admins to update all profiles
create policy "Admins can update all profiles"
on public.user_profiles
for update
using (
  exists (
    select 1 from public.user_profiles
    where id = auth.uid() and role = 'admin'
  )
);

-- Create products table
create table public.products (
    id uuid default uuid_generate_v4() primary key,
    name text not null,
    description text,
    price numeric not null,
    image_url text,
    category text,
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone,
    owner_id uuid references public.user_profiles(id),
    is_active boolean default true,
    quantity integer default 0,
    metadata jsonb
);

-- Add RLS policies for products
-- Everyone can view products
create policy "Everyone can view products"
on public.products
for select
to authenticated
using (true);

-- Only owners and admins can update products
create policy "Owners and admins can update products"
on public.products
for update
using (
  auth.uid() = owner_id or
  exists (
    select 1 from public.user_profiles
    where id = auth.uid() and role = 'admin'
  )
);

-- Create orders table
create table public.orders (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid references public.user_profiles(id) not null,
    order_date timestamp with time zone default now() not null,
    status text not null default 'pending',
    total_amount numeric not null default 0,
    payment_status text not null default 'unpaid',
    assigned_to uuid references public.user_profiles(id),
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone,
    tracking_number text,
    shipping_address jsonb,
    metadata jsonb
);

-- Create order_items table
create table public.order_items (
    id uuid default uuid_generate_v4() primary key,
    order_id uuid references public.orders(id) not null,
    product_id uuid references public.products(id) not null,
    quantity integer not null,
    price numeric not null,
    created_at timestamp with time zone default now() not null
);

-- Add RLS policies for orders and order_items
-- Similar to the user_profiles and products policies

-- Create notifications table
create table public.notifications (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references public.user_profiles(id) not null,
    title text not null,
    message text not null,
    type text not null,
    is_read boolean not null default false,
    created_at timestamp with time zone default now() not null
);

-- Add more tables as needed for your application

*/

class SupabaseSchema {
  // Table names
  static const String userProfiles = 'user_profiles';
  static const String products = 'products';
  static const String orders = 'orders';
  static const String orderItems = 'order_items';
  static const String notifications = 'notifications';
  static const String faults = 'faults';
  static const String waste = 'waste';
  static const String productivity = 'productivity';
  static const String returns = 'returns';
  static const String tasks = 'tasks';
  static const String wallets = 'wallets';
  static const String walletTransactions = 'wallet_transactions';
  static const String vouchers = 'vouchers';
  static const String clientVouchers = 'client_vouchers';

  // Warehouse system tables
  static const String warehouses = 'warehouses';
  static const String warehouseInventory = 'warehouse_inventory';
  static const String warehouseRequests = 'warehouse_requests';
  static const String warehouseRequestItems = 'warehouse_request_items';
  static const String warehouseTransactions = 'warehouse_transactions';

  // Storage bucket names
  static const String profileImages = 'profile_images';
  static const String productImages = 'product_images';
  static const String attachments = 'attachments';
}