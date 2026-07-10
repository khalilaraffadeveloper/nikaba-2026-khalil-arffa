(function() {
    var SUPABASE_URL = 'https://bfdixkdwhccriliwtnch.supabase.co';
    var SUPABASE_ANON_KEY = 'sb_publishable_Y3FsxqV_4RA96t7MassN4w_NcOJ31--';

    window.SupabaseAuth = {
        TOKEN_KEY: 'sb_token',
        USER_KEY: 'sb_user',

        // ===== تسجيل الدخول =====
        signIn: async function(email, password) {
            var res = await fetch(SUPABASE_URL + '/auth/v1/token?grant_type=password', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'apikey': SUPABASE_ANON_KEY
                },
                body: JSON.stringify({ email: email, password: password })
            });
            if (!res.ok) {
                var err = await res.json();
                throw new Error(err.error_description || err.msg || 'فشل تسجيل الدخول');
            }
            var data = await res.json();
            this.setSession(data);
            return data;
        },

        // ===== مسار جذر الموقع =====
        rootPath: function() {
            var parts = window.location.pathname.split('/').filter(Boolean);
            return parts.length > 0 && parts[0].indexOf('.html') < 0 ? '/' + parts[0] + '/' : '/';
        },

        // ===== تسجيل خروج =====
        signOut: function() {
            localStorage.removeItem(this.TOKEN_KEY);
            localStorage.removeItem(this.USER_KEY);
            window.location.href = this.rootPath();
        },

        // ===== حفظ الجلسة =====
        setSession: function(data) {
            localStorage.setItem(this.TOKEN_KEY, data.access_token);
            localStorage.setItem(this.USER_KEY, JSON.stringify(data.user));
        },

        // ===== جلب التوكن =====
        getToken: function() {
            return localStorage.getItem(this.TOKEN_KEY);
        },

        // ===== جلب المستخدم =====
        getUser: function() {
            try {
                return JSON.parse(localStorage.getItem(this.USER_KEY));
            } catch(e) { return null; }
        },

        // ===== التحقق من المصادقة =====
        checkAuth: function(redirect) {
            var token = this.getToken();
            if (!token) {
                if (redirect) window.location.href = this.rootPath() + 'index.html';
                return false;
            }
            return true;
        },

        // ===== التحقق من صلاحية الوصول للوحة التحكم =====
        requireRole: async function(redirect) {
            if (!this.checkAuth(redirect)) return false;
            var token = this.getToken();
            if (!token) { window.location.href = this.rootPath() + 'index.html'; return false; }
            try {
                var user = this.getUser();
                if (!user || !user.id) return false;
                var res = await fetch('https://bfdixkdwhccriliwtnch.supabase.co/rest/v1/profiles?user_id=eq.' + user.id + '&select=role', {
                    headers: { 'apikey': 'sb_publishable_Y3FsxqV_4RA96t7MassN4w_NcOJ31--', 'Authorization': 'Bearer ' + token }
                });
                if (!res.ok) return false;
                var profiles = await res.json();
                if (!profiles || !profiles.length) return false;
                var role = profiles[0].role;
                if (role !== 'admin' && role !== 'executive') {
                    window.location.href = this.rootPath() + 'index.html';
                    return false;
                }
                return role;
            } catch(e) {
                window.location.href = this.rootPath() + 'index.html';
                return false;
            }
        },

        // ===== استدعاء API محمي =====
        fetch: async function(url, options) {
            options = options || {};
            options.headers = options.headers || {};
            options.headers['apikey'] = SUPABASE_ANON_KEY;
            var token = this.getToken();
            if (token) {
                options.headers['Authorization'] = 'Bearer ' + token;
            }
            return fetch(url, options);
        }
    };
})();
