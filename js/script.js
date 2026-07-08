const SUPABASE_URL = 'https://bfdixkdwhccriliwtnch.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_Y3FsxqV_4RA96t7MassN4w_NcOJ31--';

let supabase;

function initSupabase() {
  supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

async function signUp(email, password, fullName, metadata) {
  const { data: authData, error: authError } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName, ...metadata }
    }
  });
  if (authError) return { error: authError.message };
  return { success: true, user: authData.user };
}

async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) return { error: error.message };
  return { success: true, user: data.user };
}

async function signOut() {
  await supabase.auth.signOut();
}

async function getCurrentUser() {
  const { data } = await supabase.auth.getUser();
  return data?.user;
}

async function onAuthChange(callback) {
  supabase.auth.onAuthStateChange((event, session) => {
    callback(event, session?.user);
  });
}

async function getMembers() {
  const { data, error } = await supabase.from('members').select('*').order('created_at', { ascending: false });
  if (error) return { error: error.message };
  return { data };
}

async function getMyProfile() {
  const user = await getCurrentUser();
  if (!user) return { error: 'Not logged in' };
  const { data, error } = await supabase.from('members').select('*').eq('user_id', user.id).maybeSingle();
  if (error && error.code !== 'PGRST116') return { error: error.message };
  return { data, metadata: user.user_metadata };
}

async function updateProfile(fields) {
  const user = await getCurrentUser();
  if (!user) return { error: 'Not logged in' };
  const profile = await getMyProfile();
  if (!profile.data) return { error: 'Profile not found' };
  const { data, error } = await supabase.from('members').update(fields).eq('user_id', user.id).select().maybeSingle();
  if (error) return { error: error.message };
  return { data };
}

async function getMemberById(id) {
  const { data, error } = await supabase.from('members').select('*').eq('id', id).maybeSingle();
  if (error) return { error: error.message };
  return { data };
}

async function requireAuth() {
  const user = await getCurrentUser();
  if (!user) {
    window.location.href = 'login.html';
    return null;
  }
  return user;
}

async function requireAdmin() {
  const user = await requireAuth();
  if (!user) return null;
  const { data } = await getMyProfile();
  if (!data?.is_admin) {
    window.location.href = 'dashboard.html';
    return null;
  }
  return { user, profile: data };
}

initSupabase();
