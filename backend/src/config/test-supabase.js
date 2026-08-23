require('dotenv').config();

const supabase = require('./supabase');

async function testSupabase() {
  const { data, error } = await supabase
    .from('profiles')
    .select('id')
    .limit(1);

  if (error) {
    console.error('Supabase connection failed:', error);
    process.exit(1);
  }

  console.log('Supabase connection successful');
  console.log('Profiles query result:', data);
}

testSupabase();