-- ============================================
-- هجرة قاعدة بيانات Supabase — نقابة المهن التمثيلية
-- تشغيل من SQL Editor في Supabase Dashboard
-- ============================================

-- 1. جدول المشتركين (الموافق عليهم)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    name TEXT,
    email TEXT,
    phone TEXT,
    national_id TEXT,
    whatsapp TEXT,
    role TEXT DEFAULT 'member' CHECK (role IN ('member', 'executive', 'admin')),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- تفعيل Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- سياسات RLS لجداول profiles
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "profiles_select_admin" ON profiles FOR SELECT USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 2. جدول طلبات الإنتساب
CREATE TABLE IF NOT EXISTS affiliations (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    national_id TEXT,
    email TEXT,
    phone TEXT NOT NULL,
    whatsapp TEXT NOT NULL,
    payment_number TEXT NOT NULL,
    payment_date TEXT,
    personal_photo_url TEXT,
    id_card_image_url TEXT,
    payment_receipt_url TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE affiliations ENABLE ROW LEVEL SECURITY;

-- سياسات RLS لجداول طلبات الإنتساب
CREATE POLICY "affiliations_insert_anon" ON affiliations FOR INSERT WITH CHECK (true);
CREATE POLICY "affiliations_select_admin" ON affiliations FOR SELECT USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "affiliations_update_admin" ON affiliations FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 3. إنشاء دالة لإنشاء بروفايل تلقائياً عند تسجيل مستخدم جديد
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO profiles (user_id, email, name)
    VALUES (NEW.id, NEW.email, split_part(NEW.email, '@', 1));
    RETURN NEW;
END;
$$;

-- ربط الدالة مع حدث إنشاء مستخدم
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- 4. جدول رسائل التواصل مع المكتب التنفيذي
CREATE TABLE IF NOT EXISTS contact_messages (
    id BIGSERIAL PRIMARY KEY,
    name TEXT,
    email TEXT,
    subject TEXT,
    department TEXT,
    message TEXT,
    status TEXT DEFAULT 'unread' CHECK (status IN ('unread', 'read', 'replied')),
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "contact_insert_anon" ON contact_messages FOR INSERT WITH CHECK (true);
CREATE POLICY "contact_select_admin" ON contact_messages FOR SELECT USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "contact_update_admin" ON contact_messages FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 5. تحديد صلاحية admin لأول مستخدم يسجل (يدوياً)
-- بعد تسجيل أول مستخدم، شغّل هذا الاستعلام:
-- UPDATE profiles SET role = 'admin' WHERE email = 'admin@example.com';
