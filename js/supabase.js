var SB = {
  URL: 'https://bfdixkdwhccriliwtnch.supabase.co',
  KEY: 'sb_publishable_Y3FsxqV_4RA96t7MassN4w_NcOJ31--',
  getToken: function() { try { return localStorage.getItem('sb-access-token'); } catch(e) { return null; } },
  getUser: function() { try { return JSON.parse(localStorage.getItem('sb-user')); } catch(e) { return null; } },
  saveSession: function(at, rt, u) {
    try { localStorage.setItem('sb-access-token', at); localStorage.setItem('sb-refresh-token', rt); localStorage.setItem('sb-user', JSON.stringify(u)); } catch(e) {}
  },
  clearSession: function() {
    try { localStorage.removeItem('sb-access-token'); localStorage.removeItem('sb-refresh-token'); localStorage.removeItem('sb-user'); } catch(e) {}
  },
  api: function(method, path, body) {
    var token = SB.getToken();
    var headers = { 'apikey': SB.KEY };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    if (body) headers['Content-Type'] = 'application/json';
    var opt = { method: method, headers: headers };
    if (body) opt.body = JSON.stringify(body);
    return fetch(SB.URL + path, opt).then(function(r) { return method === 'DELETE' ? r.status : r.json(); });
  },
  login: function(email, password) {
    return fetch(SB.URL + '/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': SB.KEY },
      body: JSON.stringify({ email: email, password: password })
    }).then(function(r) { return r.json(); });
  },
  signup: function(email, password, data) {
    return fetch(SB.URL + '/auth/v1/signup', {
      method: 'POST',
      headers: { 'apikey': SB.KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: email, password: password, data: data })
    }).then(function(r) { return r.json(); });
  },
  requireAuth: function(redirectTo) {
    var user = SB.getUser();
    var token = SB.getToken();
    if (!user || !token) { SB.clearSession(); window.location.href = redirectTo || 'login.html'; return null; }
    return user;
  },
  esc: function(s) { if (!s) return ''; var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }
};
