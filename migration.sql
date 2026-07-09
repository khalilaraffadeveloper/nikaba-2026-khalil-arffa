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

-- 12. إنشاء جدول طلبات العضوية
CREATE TABLE IF NOT EXISTS membership_applications (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  profession TEXT,
  national_id TEXT,
  birth_date DATE,
  gender TEXT,
  address TEXT,
  specialty TEXT,
  bio TEXT,
  status TEXT DEFAULT 'pending',
  review_notes TEXT,
  reviewed_at TIMESTAMPTZ
);

ALTER TABLE membership_applications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert applications" ON membership_applications FOR INSERT WITH CHECK (true);
CREATE POLICY "Admins can manage applications" ON membership_applications FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 13. إنشاء جدول الانتخابات
CREATE TABLE IF NOT EXISTS elections (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending',
  voting_start TIMESTAMPTZ,
  voting_end TIMESTAMPTZ
);

ALTER TABLE elections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view elections" ON elections FOR SELECT USING (true);
CREATE POLICY "Admins can manage elections" ON elections FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 14. إنشاء جدول مرشحي الانتخابات
CREATE TABLE IF NOT EXISTS election_candidates (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  election_id BIGINT REFERENCES elections(id) ON DELETE CASCADE,
  candidate_name TEXT NOT NULL,
  member_name TEXT,
  position TEXT,
  email TEXT,
  status TEXT DEFAULT 'pending',
  votes BIGINT DEFAULT 0
);

ALTER TABLE election_candidates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view candidates" ON election_candidates FOR SELECT USING (true);
CREATE POLICY "Admins can manage candidates" ON election_candidates FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 15. إنشاء جدول أصوات الانتخابات
CREATE TABLE IF NOT EXISTS election_votes (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  election_id BIGINT REFERENCES elections(id) ON DELETE CASCADE,
  member_id BIGINT REFERENCES members(id) ON DELETE SET NULL,
  member_name TEXT,
  candidate_name TEXT,
  amount NUMERIC DEFAULT 0,
  votes BIGINT DEFAULT 1
);

ALTER TABLE election_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view votes" ON election_votes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can insert votes" ON election_votes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can manage votes" ON election_votes FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 16. إنشاء جدول التعليقات
CREATE TABLE IF NOT EXISTS comments (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  news_id BIGINT REFERENCES news(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  text TEXT NOT NULL,
  status TEXT DEFAULT 'pending'
);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view approved comments" ON comments FOR SELECT USING (status = 'approved');
CREATE POLICY "Anyone can insert comments" ON comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Admins can manage comments" ON comments FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 17. إنشاء جدول الإشعارات
CREATE TABLE IF NOT EXISTS notifications (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  title TEXT NOT NULL,
  message TEXT,
  type TEXT DEFAULT 'system',
  status TEXT DEFAULT 'unread'
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage notifications" ON notifications FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 18. إنشاء جدول تذاكر الدعم
CREATE TABLE IF NOT EXISTS support_tickets (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  member_id BIGINT REFERENCES members(id) ON DELETE SET NULL,
  subject TEXT NOT NULL,
  message TEXT,
  priority TEXT DEFAULT 'medium',
  status TEXT DEFAULT 'open',
  resolved_at TIMESTAMPTZ
);

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own tickets" ON support_tickets FOR SELECT TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE id = member_id) OR auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));
CREATE POLICY "Users can insert tickets" ON support_tickets FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can manage tickets" ON support_tickets FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 19. إنشاء جدول المحافظ المالية
CREATE TABLE IF NOT EXISTS wallets (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  member_id BIGINT UNIQUE REFERENCES members(id) ON DELETE CASCADE,
  balance NUMERIC DEFAULT 0,
  total_purchased NUMERIC DEFAULT 0,
  total_transferred NUMERIC DEFAULT 0,
  donation_total NUMERIC DEFAULT 0,
  total_received NUMERIC DEFAULT 0,
  total_sent NUMERIC DEFAULT 0,
  last_activity TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own wallet" ON wallets FOR SELECT TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE id = member_id) OR auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));
CREATE POLICY "Admins can manage wallets" ON wallets FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 20. إنشاء جدول المعاملات المالية
CREATE TABLE IF NOT EXISTS finance_transactions (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  type TEXT NOT NULL,
  from_member TEXT,
  to_member TEXT,
  amount NUMERIC DEFAULT 0,
  reason TEXT,
  created_by TEXT
);

ALTER TABLE finance_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view transactions" ON finance_transactions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert transactions" ON finance_transactions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can manage transactions" ON finance_transactions FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 21. إنشاء جدول الخزينة
CREATE TABLE IF NOT EXISTS treasury (
  id BIGSERIAL PRIMARY KEY,
  total_income NUMERIC DEFAULT 0,
  total_expense NUMERIC DEFAULT 0,
  net_balance NUMERIC DEFAULT 0,
  share_price NUMERIC DEFAULT 0
);

INSERT INTO treasury (id, total_income, total_expense, net_balance, share_price)
VALUES (1, 0, 0, 0, 0)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE treasury ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view treasury" ON treasury FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage treasury" ON treasury FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 22. إنشاء جدول معاملات الخزينة
CREATE TABLE IF NOT EXISTS treasury_transactions (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  entry_type TEXT NOT NULL,
  category TEXT,
  amount NUMERIC DEFAULT 0,
  shares_amount NUMERIC DEFAULT 0,
  note TEXT
);

ALTER TABLE treasury_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view treasury transactions" ON treasury_transactions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage treasury transactions" ON treasury_transactions FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 23. إنشاء جدول تاريخ سعر السهم
CREATE TABLE IF NOT EXISTS share_price_history (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  price NUMERIC DEFAULT 0,
  changed_by TEXT,
  reason TEXT
);

ALTER TABLE share_price_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view share history" ON share_price_history FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage share history" ON share_price_history FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));

-- 24. إنشاء جدول رسائل الشات
CREATE TABLE IF NOT EXISTS chat_messages (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  text TEXT NOT NULL,
  author_name TEXT,
  user_id UUID,
  channel TEXT DEFAULT 'general'
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated can view chat" ON chat_messages FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can insert chat" ON chat_messages FOR INSERT TO authenticated WITH CHECK (true);

-- 25. إنشاء جدول قطع الأفترا (المتجر)
CREATE TABLE IF NOT EXISTS avatar_items (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  name TEXT NOT NULL,
  price NUMERIC DEFAULT 0,
  category TEXT,
  color TEXT,
  accent TEXT,
  status TEXT DEFAULT 'active',
  premium BOOLEAN DEFAULT false,
  shape TEXT,
  sales BIGINT DEFAULT 0
);

ALTER TABLE avatar_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view avatar items" ON avatar_items FOR SELECT USING (true);
CREATE POLICY "Admins can manage avatar items" ON avatar_items FOR ALL TO authenticated USING (auth.uid() IN (SELECT user_id FROM members WHERE is_admin = true));
