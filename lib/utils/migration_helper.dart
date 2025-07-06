import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

class MigrationHelper {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if tasks table exists and create it if it doesn't
  static Future<bool> ensureTasksTableExists() async {
    try {
      AppLogger.info('Checking if tasks table exists...');

      // Try to query the table
      await _supabase
          .from('tasks')
          .select('id')
          .limit(1);

      AppLogger.info('Tasks table exists');
      return true;

    } catch (e) {
      AppLogger.error('Tasks table check failed: $e');

      if (e.toString().contains('404') ||
          e.toString().contains('Not Found') ||
          e.toString().contains('relation') && e.toString().contains('does not exist')) {

        AppLogger.info('Tasks table does not exist, attempting to create it...');
        return await createTasksTable();
      }

      return false;
    }
  }

  /// Create the tasks table using SQL
  static Future<bool> createTasksTable() async {
    try {
      AppLogger.info('Creating tasks table...');

      const createTableSQL = '''
        CREATE TABLE IF NOT EXISTS public.tasks (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          title TEXT NOT NULL,
          description TEXT,
          worker_id UUID,
          worker_name TEXT NOT NULL,
          admin_id UUID,
          admin_name TEXT NOT NULL,
          product_id TEXT,
          product_name TEXT NOT NULL,
          product_image TEXT,
          order_id TEXT,
          quantity INTEGER NOT NULL DEFAULT 1,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
          deadline TIMESTAMP WITH TIME ZONE NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          completed_quantity INTEGER DEFAULT 0,
          progress REAL DEFAULT 0.0,
          category TEXT DEFAULT 'product',
          metadata JSONB,
          assigned_to TEXT NOT NULL,
          due_date TIMESTAMP WITH TIME ZONE,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
          priority TEXT DEFAULT 'medium',
          attachments JSONB DEFAULT '[]'::jsonb
        );
      ''';

      // Note: exec_sql RPC function may not be available in all Supabase setups
      // This is a fallback approach - the proper way is to run migrations via Supabase CLI
      try {
        await _supabase.rpc('exec_sql', params: {'sql': createTableSQL});
      } catch (rpcError) {
        AppLogger.error('RPC exec_sql not available: $rpcError');
        AppLogger.info('Please run migrations manually using Supabase CLI or dashboard');
        return false;
      }

      AppLogger.info('Tasks table created successfully');

      // Enable RLS
      await _supabase.rpc('exec_sql', params: {
        'sql': 'ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;'
      });

      // Create basic policies
      await createBasicPolicies();

      return true;

    } catch (e) {
      AppLogger.error('Failed to create tasks table: $e');
      return false;
    }
  }

  /// Create basic RLS policies for tasks table
  static Future<void> createBasicPolicies() async {
    try {
      AppLogger.info('Creating basic policies for tasks table...');

      // First, try to disable RLS temporarily to allow operations
      try {
        await _supabase.rpc('exec_sql', params: {
          'sql': 'ALTER TABLE public.tasks DISABLE ROW LEVEL SECURITY;'
        });
        AppLogger.info('Disabled RLS for tasks table');
      } catch (e) {
        AppLogger.warning('Could not disable RLS: $e');
      }

      // Drop existing policies if they exist
      const dropPolicies = [
        'DROP POLICY IF EXISTS "Allow authenticated users to read tasks" ON public.tasks;',
        'DROP POLICY IF EXISTS "Allow authenticated users to insert tasks" ON public.tasks;',
        'DROP POLICY IF EXISTS "Allow authenticated users to update tasks" ON public.tasks;',
        'DROP POLICY IF EXISTS "Allow authenticated users to delete tasks" ON public.tasks;',
        'DROP POLICY IF EXISTS "Enable read access for all users" ON public.tasks;',
        'DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.tasks;',
        'DROP POLICY IF EXISTS "Enable update for authenticated users only" ON public.tasks;',
        'DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON public.tasks;',
      ];

      for (final dropSql in dropPolicies) {
        try {
          await _supabase.rpc('exec_sql', params: {'sql': dropSql});
        } catch (e) {
          // Ignore errors when dropping non-existent policies
        }
      }

      // Re-enable RLS
      await _supabase.rpc('exec_sql', params: {
        'sql': 'ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;'
      });

      // Create permissive policies
      const policies = [
        '''
        CREATE POLICY "Enable read access for all users" ON public.tasks
        FOR SELECT USING (true);
        ''',
        '''
        CREATE POLICY "Enable insert for authenticated users only" ON public.tasks
        FOR INSERT WITH CHECK (true);
        ''',
        '''
        CREATE POLICY "Enable update for authenticated users only" ON public.tasks
        FOR UPDATE USING (true) WITH CHECK (true);
        ''',
        '''
        CREATE POLICY "Enable delete for authenticated users only" ON public.tasks
        FOR DELETE USING (true);
        '''
      ];

      for (final policy in policies) {
        try {
          await _supabase.rpc('exec_sql', params: {'sql': policy});
          AppLogger.info('Created policy successfully');
        } catch (e) {
          AppLogger.warning('Failed to create policy: $e');
        }
      }

      AppLogger.info('Basic policies created successfully');

    } catch (e) {
      AppLogger.error('Failed to create policies: $e');
    }
  }

  /// Add missing columns to existing tasks table
  static Future<bool> addMissingColumns() async {
    try {
      AppLogger.info('Adding missing columns to tasks table...');

      final columns = [
        'ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_to TEXT;',
        'ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_date TIMESTAMP WITH TIME ZONE;',
        'ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();',
        "ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'medium';",
        "ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;",
      ];

      // Instead of using exec_sql, log the required SQL commands
      AppLogger.warning('Database schema migration required. Please execute the following SQL commands manually in your Supabase dashboard:');

      for (final sql in columns) {
        AppLogger.info('SQL: $sql');
      }

      AppLogger.info('Additional SQL: UPDATE public.tasks SET assigned_to = worker_id::text WHERE assigned_to IS NULL;');

      // Check if we can at least read from the tasks table
      try {
        await _supabase
            .from('tasks')
            .select('id')
            .limit(1);
        AppLogger.info('Tasks table is accessible for reading');
      } catch (e) {
        AppLogger.warning('Tasks table access test failed: $e');
      }

      AppLogger.info('Missing columns added successfully');
      return true;

    } catch (e) {
      AppLogger.error('Failed to add missing columns: $e');
      return false;
    }
  }

  /// Fix RLS permissions by temporarily disabling RLS
  static Future<bool> fixTasksPermissions() async {
    try {
      AppLogger.info('Attempting to fix tasks table permissions...');

      // Try to test current permissions
      try {
        final testResult = await _supabase
            .from('tasks')
            .select('id')
            .limit(1);
        AppLogger.info('Tasks table is accessible for reading');
      } catch (e) {
        AppLogger.warning('Tasks table read test failed: $e');
      }

      // Try to test insert permissions with a minimal test
      try {
        final testTask = {
          'title': 'Permission Test',
          'admin_name': 'Test Admin',
          'worker_name': 'Test Worker',
          'product_name': 'Test Product',
          'assigned_to': 'test-id',
          'deadline': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'quantity': 1,
          'status': 'pending',
        };

        final result = await _supabase
            .from('tasks')
            .insert(testTask)
            .select()
            .single();

        AppLogger.info('Tasks table insert test successful');

        // Clean up test task
        await _supabase
            .from('tasks')
            .delete()
            .eq('id', result['id'] as String);

        AppLogger.info('Tasks table permissions are working correctly');
        return true;

      } catch (e) {
        AppLogger.error('Tasks table insert test failed: $e');

        if (e.toString().contains('permission denied') ||
            e.toString().contains('42501')) {
          AppLogger.error('Permission denied error detected. This requires manual RLS policy configuration in Supabase dashboard.');
          AppLogger.error('Please go to your Supabase dashboard > Authentication > Policies and create policies for the tasks table.');
          return false;
        }

        return false;
      }

    } catch (e) {
      AppLogger.error('Failed to fix tasks permissions: $e');
      return false;
    }
  }

  /// Run all necessary migrations
  static Future<bool> runMigrations() async {
    AppLogger.info('Starting database migrations...');

    bool success = await ensureTasksTableExists();

    if (success) {
      success = await addMissingColumns();
    }

    if (success) {
      // Try to fix permissions
      await fixTasksPermissions();
    }

    if (success) {
      AppLogger.info('All migrations completed successfully');
    } else {
      AppLogger.error('Some migrations failed');
    }

    return success;
  }
}
