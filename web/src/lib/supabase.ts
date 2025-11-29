import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://zthekwndkbowxmlneplh.supabase.co';
const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0aGVrd25ka2Jvd3htbG5lcGxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzOTA3MjYsImV4cCI6MjA3OTk2NjcyNn0.15gC2Qi5hMy1Q3BG-1znaw5EtpU76aCc0sXMHaBwaj8';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

