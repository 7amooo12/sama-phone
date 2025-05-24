-- Create a table for User Profiles instead of modifying auth.users directly
create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  name text not null,
  phone_number text,
  role text not null,
  status text not null default 'pending',
  profile_image text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on User Profiles table
alter table public.user_profiles enable row level security;

-- Create Todos table for testing
create table public.todos (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  is_complete boolean default false,
  user_id uuid references auth.users,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on Todos table
alter table public.todos enable row level security;

-- Create RLS policies for Todos
create policy "Todos are viewable by everyone" on public.todos
  for select using (true);

create policy "Users can insert their own todos" on public.todos
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own todos" on public.todos
  for update using (auth.uid() = user_id);

create policy "Users can delete their own todos" on public.todos
  for delete using (auth.uid() = user_id);

-- Create Products table
create table public.products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  price decimal(10, 2) not null,
  sale_price decimal(10, 2),
  stock_quantity integer not null default 0,
  category text,
  image_url text,
  sku text unique,
  barcode text,
  manufacturer text,
  active boolean default true,
  created_by uuid references auth.users not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on Products table
alter table public.products enable row level security;

-- Create Orders table
create table public.orders (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  status text not null default 'pending',
  total_amount decimal(10, 2) not null,
  payment_method text,
  payment_status text default 'pending',
  shipping_address jsonb,
  shipping_method text,
  tracking_number text,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on Orders table
alter table public.orders enable row level security;

-- Create Order Items table
create table public.order_items (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders on delete cascade not null,
  product_id uuid references public.products not null,
  quantity integer not null,
  unit_price decimal(10, 2) not null,
  subtotal decimal(10, 2) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on Order Items table
alter table public.order_items enable row level security;

-- Create Categories table
create table public.categories (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  parent_id uuid references public.categories,
  image_url text,
  active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on Categories table
alter table public.categories enable row level security;

-- Create Notifications table
create table public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  title text not null,
  body text not null,
  type text not null,
  reference_id text,
  read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on Notifications table
alter table public.notifications enable row level security;

-- Create Favorites table
create table public.favorites (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  product_id uuid references public.products not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, product_id)
);

-- Enable RLS on Favorites table
alter table public.favorites enable row level security;

-- Create RLS Policies

-- User Profiles policies
create policy "Public profiles are viewable by everyone" on public.user_profiles
  for select using (true);

create policy "Users can insert their own profile" on public.user_profiles
  for insert with check (auth.uid() = id);

create policy "Users can update their own profile" on public.user_profiles
  for update using (auth.uid() = id);

-- Admin users can view/insert/update all profiles
create policy "Admins can view all profiles" on public.user_profiles
  for select using (
    exists (
      select 1 from public.user_profiles
      where user_profiles.id = auth.uid() and user_profiles.role = 'admin'
    )
  );

create policy "Admins can insert all profiles" on public.user_profiles
  for insert with check (
    exists (
      select 1 from public.user_profiles
      where user_profiles.id = auth.uid() and user_profiles.role = 'admin'
    )
  );

create policy "Admins can update all profiles" on public.user_profiles
  for update using (
    exists (
      select 1 from public.user_profiles
      where user_profiles.id = auth.uid() and user_profiles.role = 'admin'
    )
  );

-- Products policies
create policy "Products are viewable by everyone" on public.products
  for select using (active = true);

create policy "Admins can manage products" on public.products
  for all using (
    exists (
      select 1 from public.user_profiles
      where user_profiles.id = auth.uid() and user_profiles.role = 'admin'
    )
  );

-- Orders policies
create policy "Users can view their own orders" on public.orders
  for select using (auth.uid() = user_id);

create policy "Users can insert their own orders" on public.orders
  for insert with check (auth.uid() = user_id);

create policy "Admins can view all orders" on public.orders
  for select using (
    exists (
      select 1 from public.user_profiles
      where user_profiles.id = auth.uid() and user_profiles.role = 'admin'
    )
  );

create policy "Admins can update all orders" on public.orders
  for update using (
    exists (
      select 1 from public.user_profiles
      where user_profiles.id = auth.uid() and user_profiles.role = 'admin'
    )
  );

-- Order Items policies
create policy "Users can view their own order items" on public.order_items
  for select using (
    exists (
      select 1 from public.orders
      where orders.id = order_id and orders.user_id = auth.uid()
    )
  );

create policy "Admins can view all order items" on public.order_items
  for select using (
    exists (
      select 1 from public.user_profiles
      where user_profiles.id = auth.uid() and user_profiles.role = 'admin'
    )
  );

-- Notifications policies
create policy "Users can view their own notifications" on public.notifications
  for select using (auth.uid() = user_id);

create policy "Users can update their own notifications" on public.notifications
  for update using (auth.uid() = user_id);

-- Favorites policies
create policy "Users can manage their own favorites" on public.favorites
  for all using (auth.uid() = user_id);

-- Functions and Triggers

-- Function to update updated_at column
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger for user_profiles table
create trigger handle_updated_at
before update on public.user_profiles
for each row execute procedure public.handle_updated_at();

-- Trigger for todos table
create trigger handle_updated_at
before update on public.todos
for each row execute procedure public.handle_updated_at();

-- Trigger for products table
create trigger handle_updated_at
before update on public.products
for each row execute procedure public.handle_updated_at();

-- Trigger for orders table
create trigger handle_updated_at
before update on public.orders
for each row execute procedure public.handle_updated_at();

-- Trigger for categories table
create trigger handle_updated_at
before update on public.categories
for each row execute procedure public.handle_updated_at(); 