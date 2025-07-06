-- ============================================================================
-- RESTORE EVERYTHING BACK TO ORIGINAL STATE
-- ============================================================================
-- إرجاع كل حاجة زي ما كانت
-- ============================================================================

-- إيقاف RLS على كل الجداول
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.electronic_wallets DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.distributors DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.distribution_centers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.vouchers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_vouchers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.todos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_rewards DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_reward_balances DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_submissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_feedback DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.electronic_payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.electronic_wallet_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_returns DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_tracking_links DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_request_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_request_allocations DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.advances DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.error_reports DISABLE ROW LEVEL SECURITY;

-- منح كل الصلاحيات للجميع (زي ما كان)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO postgres;

-- إعادة تفعيل RLS بدون أي policies (مفتوح للكل)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- إنشاء policies مفتوحة للكل
CREATE POLICY "allow_all_products" ON public.products FOR ALL USING (true);
CREATE POLICY "allow_all_warehouses" ON public.warehouses FOR ALL USING (true);
CREATE POLICY "allow_all_warehouse_inventory" ON public.warehouse_inventory FOR ALL USING (true);
CREATE POLICY "allow_all_user_profiles" ON public.user_profiles FOR ALL USING (true);

-- إعادة تفعيل باقي الجداول بدون قيود
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_invoices" ON public.invoices FOR ALL USING (true);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_orders" ON public.orders FOR ALL USING (true);

ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_client_orders" ON public.client_orders FOR ALL USING (true);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_tasks" ON public.tasks FOR ALL USING (true);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_notifications" ON public.notifications FOR ALL USING (true);

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_wallets" ON public.wallets FOR ALL USING (true);

ALTER TABLE public.distributors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_distributors" ON public.distributors FOR ALL USING (true);

ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_warehouse_requests" ON public.warehouse_requests FOR ALL USING (true);

ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_withdrawal_requests" ON public.withdrawal_requests FOR ALL USING (true);

ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_vouchers" ON public.vouchers FOR ALL USING (true);

-- اختبار إن كل حاجة رجعت تشتغل
SELECT 'كل حاجة رجعت تشتغل' as status;
SELECT 'المنتجات' as table_name, COUNT(*) as count FROM products;
SELECT 'المخازن' as table_name, COUNT(*) as count FROM warehouses;
SELECT 'المستخدمين' as table_name, COUNT(*) as count FROM user_profiles;
SELECT 'الفواتير' as table_name, COUNT(*) as count FROM invoices;
SELECT 'الطلبات' as table_name, COUNT(*) as count FROM orders;

-- رسالة نهائية
SELECT 
  'تم إرجاع كل حاجة زي ما كانت' as message,
  'يمكنك الآن تسجيل الدخول والوصول لكل البيانات' as instruction,
  'البحث والداتا كلها شغالة' as confirmation;
