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
