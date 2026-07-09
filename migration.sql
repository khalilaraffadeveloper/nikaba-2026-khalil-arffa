-- 1. إضافة الأعمدة الجديدة لجدول الأعضاء
ALTER TABLE members ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE members ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;
ALTER TABLE members ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS professional_type TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS membership_status TEXT DEFAULT 'pending';
ALTER TABLE members ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS birth_date DATE;
ALTER TABLE members ADD COLUMN IF NOT EXISTS national_id TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE members ADD COLUMN IF NOT EXISTS join_date DATE DEFAULT CURRENT_DATE;

-- 2. إنشاء سجل عضو تلقائياً عند تسجيل مستخدم جديد
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.members (full_name, email, user_id)
  VALUES (
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.email, ''),
    NEW.id
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. تفعيل أمان الصفوف (RLS)
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- 4. سياسات RLS
--    - الجمهور يرى فقط الأعضاء المعتمدين
--    - المستخدمون المسجلون يرون الكل
--    - كل مستخدم يعدّل فقط سجله الخاص
DROP POLICY IF EXISTS "Public can view approved members" ON members;
CREATE POLICY "Public can view approved members" ON members
  FOR SELECT USING (membership_status = 'approved');

DROP POLICY IF EXISTS "Authenticated users can view all members" ON members;
CREATE POLICY "Authenticated users can view all members" ON members
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert own member" ON members;
CREATE POLICY "Users can insert own member" ON members
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own member" ON members;
CREATE POLICY "Users can update own member" ON members
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 5. إضافة عمود is_admin
ALTER TABLE members ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- 6. إنشاء جدول الأخبار
CREATE TABLE IF NOT EXISTS news (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  title TEXT NOT NULL,
  summary TEXT,
  content TEXT,
  image_path TEXT,
  category TEXT,
  event_date TEXT,
  is_published BOOLEAN DEFAULT true
);

ALTER TABLE news ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view published news" ON news FOR SELECT USING (is_published = true);
CREATE POLICY "Admins can manage news" ON news FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 7. إنشاء جدول الفعاليات
CREATE TABLE IF NOT EXISTS events (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  title TEXT NOT NULL,
  summary TEXT,
  description TEXT,
  image_path TEXT,
  location TEXT,
  event_date TEXT,
  is_published BOOLEAN DEFAULT true
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view published events" ON events FOR SELECT USING (is_published = true);
CREATE POLICY "Admins can manage events" ON events FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 8. إنشاء جدول المعرض
CREATE TABLE IF NOT EXISTS gallery (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  title TEXT,
  image_path TEXT NOT NULL,
  album TEXT
);

ALTER TABLE gallery ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view gallery" ON gallery FOR SELECT USING (true);
CREATE POLICY "Admins can manage gallery" ON gallery FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 9. إنشاء جدول الشهادات
CREATE TABLE IF NOT EXISTS testimonials (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  content TEXT NOT NULL,
  author TEXT,
  author_title TEXT
);

ALTER TABLE testimonials ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view testimonials" ON testimonials FOR SELECT USING (true);
CREATE POLICY "Admins can manage testimonials" ON testimonials FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 10. إنشاء جدول الإعدادات
CREATE TABLE IF NOT EXISTS settings (
  id BIGSERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view settings" ON settings FOR SELECT USING (true);
CREATE POLICY "Admins can manage settings" ON settings FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- إضافة بعض البيانات الافتراضية
INSERT INTO settings (key, value) VALUES
  ('site_name', 'نقابة المهن التمثيلية'),
  ('site_email', 'facebooyy@gmail.com'),
  ('site_phone', '0022236280528'),
  ('site_address', 'نواكشوط، موريتانيا')
ON CONFLICT (key) DO NOTHING;

-- 11. إنشاء جدول رسائل الاتصال
CREATE TABLE IF NOT EXISTS contact_messages (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false
);

ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert contact messages" ON contact_messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Admins can view contact messages" ON contact_messages FOR SELECT TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));
