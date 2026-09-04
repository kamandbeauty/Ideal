/**
 * REST client for /wp-json/tshirt-designer/v1/.
 */
export class Api {
  constructor({ restUrl, restUrlV2, nonce }) {
    this.root = restUrl.replace(/\/$/, '');
    // The v2 namespace carries the cart/product-type routes; v1 stays as-is.
    this.rootV2 = (restUrlV2 || '').replace(/\/$/, '');
    this.nonce = nonce;
  }

  async request(path, { method = 'GET', body = null, v2 = false } = {}) {
    const headers = {};
    if (this.nonce) headers['X-WP-Nonce'] = this.nonce;
    let payload = body;
    if (body && !(body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
      payload = JSON.stringify(body);
    }

    const base = v2 ? this.rootV2 : this.root;
    const res = await fetch(`${base}${path}`, {
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

  /**
   * Add a saved design to the WooCommerce cart. Only the design id and a
   * quantity are sent - the server recomputes the price from the stored
   * snapshot, so nothing here can influence what the customer is charged.
   */
  addToCart(designId, quantity = 1) {
    return this.request('/cart', {
      method: 'POST',
      v2: true,
      body: { design_id: designId, quantity },
    });
  }
}
