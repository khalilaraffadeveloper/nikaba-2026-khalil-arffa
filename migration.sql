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

-- دالة مساعدة لتجنب recursion في RLS
CREATE OR REPLACE FUNCTION is_admin_or_exec()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role IN ('admin', 'executive'));
END;
$$;

-- سياسات RLS لجداول profiles
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "profiles_select_admin" ON profiles FOR SELECT USING (is_admin_or_exec());
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "profiles_update_admin" ON profiles FOR UPDATE USING (is_admin_or_exec());

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
    generated_email TEXT,
    generated_password TEXT,
    account_created BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    credentials TEXT,
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

-- 5. جدول الأخبار
CREATE TABLE IF NOT EXISTS news (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    excerpt TEXT,
    content TEXT,
    image_url TEXT,
    author TEXT,
    views BIGINT DEFAULT 0,
    likes BIGINT DEFAULT 0,
    status TEXT DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE news ENABLE ROW LEVEL SECURITY;

CREATE POLICY "news_select_all" ON news FOR SELECT USING (true);
CREATE POLICY "news_insert_admin" ON news FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "news_update_admin" ON news FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "news_delete_admin" ON news FOR DELETE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 6. جدول الفعاليات
CREATE TABLE IF NOT EXISTS events (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    day TEXT,
    month TEXT,
    full_date TEXT,
    location TEXT,
    image_url TEXT,
    status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "events_select_all" ON events FOR SELECT USING (true);
CREATE POLICY "events_insert_admin" ON events FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "events_update_admin" ON events FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "events_delete_admin" ON events FOR DELETE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 7. جدول الانتخابات
CREATE TABLE IF NOT EXISTS elections (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    position TEXT,
    candidates JSONB DEFAULT '[]'::jsonb,
    start_date TEXT,
    end_date TEXT,
    status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'completed')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE elections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "elections_select_all" ON elections FOR SELECT USING (true);
CREATE POLICY "elections_insert_admin" ON elections FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "elections_update_admin" ON elections FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "elections_delete_admin" ON elections FOR DELETE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 8. جدول رسائل الشات العام
CREATE TABLE IF NOT EXISTS chat_messages (
    id BIGSERIAL PRIMARY KEY,
    sender_name TEXT NOT NULL,
    sender_email TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_select_all" ON chat_messages FOR SELECT USING (true);
CREATE POLICY "chat_insert_auth" ON chat_messages FOR INSERT WITH CHECK (
    auth.role() = 'authenticated'
);

-- 9. جدول البرامج التعليمية
CREATE TABLE IF NOT EXISTS educational_videos (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    video_url TEXT,
    thumbnail_url TEXT,
    category TEXT,
    sort_order INT DEFAULT 0,
    status TEXT DEFAULT 'published' CHECK (status IN ('published', 'draft')),
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE educational_videos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "edu_select_all" ON educational_videos FOR SELECT USING (true);
CREATE POLICY "edu_insert_admin" ON educational_videos FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "edu_update_admin" ON educational_videos FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);
CREATE POLICY "edu_delete_admin" ON educational_videos FOR DELETE USING (
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 9.5 دالة لتجاوز RLS عند إدراج طلبات الإنتساب (للنماذج العامة)
CREATE OR REPLACE FUNCTION insert_affiliation(
    p_name TEXT DEFAULT '',
    p_national_id TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT '',
    p_whatsapp TEXT DEFAULT '',
    p_payment_number TEXT DEFAULT '',
    p_payment_date TEXT DEFAULT NULL,
    p_personal_photo_url TEXT DEFAULT NULL,
    p_id_card_image_url TEXT DEFAULT NULL,
    p_payment_receipt_url TEXT DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    INSERT INTO affiliations (name, national_id, email, phone, whatsapp, payment_number, payment_date, personal_photo_url, id_card_image_url, payment_receipt_url)
    VALUES (p_name, p_national_id, p_email, p_phone, p_whatsapp, p_payment_number, p_payment_date, p_personal_photo_url, p_id_card_image_url, p_payment_receipt_url)
    RETURNING row_to_json(affiliations) INTO result;
    RETURN result;
END;
$$;

-- 10. إنشاء Storage Bucket لرفع ملفات الإنتساب
INSERT INTO storage.buckets (id, name, public)
VALUES ('affiliation-files', 'affiliation-files', true)
ON CONFLICT (id) DO NOTHING;

-- سياسات التخزين: السماح للجميع بقراءة الملفات
CREATE POLICY "affiliation_files_public_read"
ON storage.objects FOR SELECT USING (bucket_id = 'affiliation-files');

-- السماح للزوار برفع الملفات (للنماذج العامة)
CREATE POLICY "affiliation_files_anon_insert"
ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'affiliation-files');

-- السماح للإدارة بحذف الملفات
CREATE POLICY "affiliation_files_admin_delete"
ON storage.objects FOR DELETE USING (
    bucket_id = 'affiliation-files' AND
    auth.uid() IN (SELECT user_id FROM profiles WHERE role IN ('executive', 'admin'))
);

-- 11. تحديد صلاحية admin لأول مستخدم يسجل (يدوياً)
-- بعد تسجيل أول مستخدم، شغّل هذا الاستعلام:
-- UPDATE profiles SET role = 'admin' WHERE email = 'admin@example.com';
