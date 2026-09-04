/**
 * REST client for /wp-json/tshirt-designer/v1/.
 */
export class Api {
  constructor({ restUrl, nonce }) {
    this.root = restUrl.replace(/\/$/, '');
    this.nonce = nonce;
  }

  async request(path, { method = 'GET', body = null } = {}) {
    const headers = {};
    if (this.nonce) headers['X-WP-Nonce'] = this.nonce;
    let payload = body;
    if (body && !(body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
      payload = JSON.stringify(body);
    }

    const res = await fetch(`${this.root}${path}`, {
      method,
      headers,
      credentials: 'same-origin',
      body: method === 'GET' ? undefined : payload,
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const message = data && data.message ? data.message : `Request failed (${res.status})`;
      const err = new Error(message);
      err.status = res.status;
      err.data = data;
      throw err;
    }
    return data;
  }

  getModels() { return this.request('/models'); }
  getModel(id) { return this.request(`/models/${id}`); }
  getAssets(category) {
    const q = category && category !== 'all' ? `?category=${encodeURIComponent(category)}` : '';
    return this.request(`/assets${q}`);
  }
  upload(file) {
    const fd = new FormData();
    fd.append('file', file);
    return this.request('/uploads', { method: 'POST', body: fd });
  }
  calculatePrice(design) {
    return this.request('/price', { method: 'POST', body: design });
  }
  saveDesign(design, preview) {
    return this.request('/designs', { method: 'POST', body: { ...design, preview } });
  }
  getDesign(id) { return this.request(`/designs/${id}`); }
}
