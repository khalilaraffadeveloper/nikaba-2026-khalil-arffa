(function() {
    var SUPABASE_URL = 'https://bfdixkdwhccriliwtnch.supabase.co';
    var SUPABASE_ANON_KEY = 'sb_publishable_Y3FsxqV_4RA96t7MassN4w_NcOJ31--';

    window.NikabaAPI = {
        // ===== طلبات الإنتساب =====
        submitAffiliation: async function(formData) {
            var data = {
                name: formData.get('name'),
                national_id: formData.get('national_id') || null,
                email: formData.get('email') || null,
                phone: formData.get('phone'),
                whatsapp: formData.get('whatsapp'),
                payment_number: formData.get('payment_number'),
                payment_date: formData.get('payment_date') || null,
                personal_photo_url: null,
                id_card_image_url: null,
                payment_receipt_url: null
            };

            // رفع الصور
            var photoFields = [
                { file: formData.get('personal_photo'), key: 'personal_photo_url', folder: 'photos' },
                { file: formData.get('id_card_image'), key: 'id_card_image_url', folder: 'id_cards' },
                { file: formData.get('payment_receipt_image'), key: 'payment_receipt_url', folder: 'receipts' }
            ];

            for (var i = 0; i < photoFields.length; i++) {
                var f = photoFields[i];
                if (f.file && f.file.size > 0) {
                    try {
                        var url = await this.uploadFile(f.file, f.folder);
                        if (url) data[f.key] = url;
                    } catch(e) {
                        console.warn('Upload failed for ' + f.key, e);
                    }
                }
            }

            var res = await fetch(SUPABASE_URL + '/rest/v1/rpc/insert_affiliation', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'apikey': SUPABASE_ANON_KEY
                },
                body: JSON.stringify({
                    p_name: data.name,
                    p_national_id: data.national_id,
                    p_email: data.email,
                    p_phone: data.phone,
                    p_whatsapp: data.whatsapp,
                    p_payment_number: data.payment_number,
                    p_payment_date: data.payment_date,
                    p_personal_photo_url: data.personal_photo_url,
                    p_id_card_image_url: data.id_card_image_url,
                    p_payment_receipt_url: data.payment_receipt_url
                })
            });

            if (!res.ok) {
                var err = await res.text();
                throw new Error(err || 'فشل تقديم الطلب');
            }
            return await res.json();
        },

        // ===== رفع ملف إلى Supabase Storage =====
        uploadFile: async function(file, folder) {
            var bucket = 'affiliation-files';
            var fileName = folder + '/' + Date.now() + '_' + file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
            var res = await fetch(SUPABASE_URL + '/storage/v1/object/' + bucket + '/' + fileName, {
                method: 'POST',
                headers: {
                    'apikey': SUPABASE_ANON_KEY,
                    'x-upsert': 'true'
                },
                body: file
            });

            if (!res.ok) {
                var errText = await res.text();
                console.warn('Storage upload error:', errText);
                return null;
            }

            var publicUrl = SUPABASE_URL + '/storage/v1/object/public/' + bucket + '/' + fileName;
            return publicUrl;
        },

        // ===== جلب طلبات الإنتساب =====
        getAffiliations: async function(status) {
            var url = SUPABASE_URL + '/rest/v1/affiliations?order=created_at.desc';
            if (status) {
                url += '&status=eq.' + status;
            }

            var token = window.SupabaseAuth ? SupabaseAuth.getToken() : null;

            var res = await fetch(url, {
                headers: {
                    'apikey': SUPABASE_ANON_KEY,
                    'Authorization': 'Bearer ' + (token || SUPABASE_ANON_KEY)
                }
            });

            if (!res.ok) throw new Error('فشل جلب البيانات');
            return await res.json();
        },

        // ===== تحديث حالة طلب =====
        updateAffiliationStatus: async function(id, status) {
            var token = window.SupabaseAuth ? SupabaseAuth.getToken() : null;
            var res = await fetch(SUPABASE_URL + '/rest/v1/affiliations?id=eq.' + id, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'apikey': SUPABASE_ANON_KEY,
                    'Authorization': 'Bearer ' + (token || SUPABASE_ANON_KEY),
                    'Prefer': 'return=representation'
                },
                body: JSON.stringify({ status: status })
            });

            if (!res.ok) throw new Error('فشل تحديث الحالة');
            return await res.json();
        },

        // ===== إحصائيات سريعة للوحة التحكم =====
        getStats: async function() {
            var all = await this.getAffiliations();
            var pending = all.filter(function(a) { return a.status === 'pending'; });
            var approved = all.filter(function(a) { return a.status === 'approved'; });
            var rejected = all.filter(function(a) { return a.status === 'rejected'; });

            return {
                total: all.length,
                pending: pending.length,
                approved: approved.length,
                rejected: rejected.length
            };
        }
    };
})();
