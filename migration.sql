-- ============================================
-- ترقية جدول الأعضاء - نقابة المهن التمثيلية
-- شغّل هذا الملف في SQL Editor في Supabase
-- ============================================

-- إضافة الأعمدة المفقودة
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

-- تحديث RLS policies
DROP POLICY IF EXISTS "Members are viewable by everyone" ON members;
DROP POLICY IF EXISTS "Users can insert own member record" ON members;

CREATE POLICY "Anyone can view members"
  ON members FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert"
  ON members FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own record"
  ON members FOR UPDATE
  USING (auth.uid() = user_id);

-- تفعيل RLS إن لم يكن مفعلاً
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- منح صلاحيات الأدوار
GRANT SELECT ON members TO anon;
GRANT SELECT, INSERT, UPDATE ON members TO authenticated;
GRANT ALL ON members TO service_role;
