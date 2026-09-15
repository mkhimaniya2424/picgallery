/// Supabase project config for the Super Admin app.
///
/// REPLACES the old `ApiConstants` (which pointed at the FastAPI
/// backend's base URL). There is no backend to point at anymore —
/// this app talks to Supabase directly (Postgres + Auth), gated by
/// Row Level Security instead of the backend's `admin:` JWT checks.
/// See `supabase/migration.sql` for the schema + policies this
/// assumes.
///
/// Both values are safe to ship in the compiled app: the anon key is
/// a PUBLIC key by design — it identifies the project, it does not
/// grant access. Access is entirely controlled by the RLS policies in
/// migration.sql. Never put the Supabase *service_role* key here.
class SupabaseConstants {
  SupabaseConstants._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vpklamqkglivyviezzrf.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwa2xhbXFrZ2xpdnl2aWV6enJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwMDQ1MTQsImV4cCI6MjA5OTU4MDUxNH0.6CqLzAsAnTQFF3l_oX3YZDSpvl5W9tzUhugFtsBJ4gw',
  );
}