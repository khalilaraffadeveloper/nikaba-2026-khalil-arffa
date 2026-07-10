-- ============================================
-- إنشاء جدول طلبات الإنتساب (affiliations)
-- ============================================

CREATE TABLE IF NOT EXISTS affiliations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    national_id TEXT,
    email TEXT,
    phone TEXT NOT NULL,
    whatsapp TEXT NOT NULL,
    personal_photo_url TEXT,
    id_card_image_url TEXT,
    payment_receipt_url TEXT,
    payment_number TEXT NOT NULL,
    payment_date TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE affiliations ENABLE ROW LEVEL SECURITY;

-- Allow anonymous insert
CREATE POLICY "allow_anon_insert" ON affiliations
    FOR INSERT TO anon
    WITH CHECK (true);

-- Allow authenticated users to read all rows
CREATE POLICY "allow_auth_select" ON affiliations
    FOR SELECT TO authenticated
    USING (true);

-- Allow authenticated users to update
CREATE POLICY "allow_auth_update" ON affiliations
    FOR UPDATE TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- إنشاء Bucket لرفع الصور (افتراضياً)
-- ============================================
-- يتم إنشاء bucket يدوياً من Supabase Dashboard:
-- 1. اذهب إلى Storage → Create bucket
-- 2. الاسم: affiliation-files
-- 3. Public bucket: ✅
-- 4. السياسة: Allow public read + anon insert
