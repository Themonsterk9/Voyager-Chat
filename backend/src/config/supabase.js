const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

let supabase = null;

if (supabaseUrl && supabaseServiceRoleKey) {
  try {
    supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });
  } catch (err) {
    console.warn('Failed to initialize Supabase client:', err.message);
  }
} else {
  console.info('Supabase URL/RoleKey missing in environment. Operating in memory/hybrid fallback mode.');
}

module.exports = supabase;