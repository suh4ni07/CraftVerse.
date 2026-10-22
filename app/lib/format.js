export const money = (amount) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(Number(amount) || 0);
export const dateTime = (value) => value ? new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Kolkata' }).format(new Date(value)) : '—';
export const shippingFee = (subtotal) => subtotal <= 0 || subtotal >= 999 ? 0 : 49;
export const productImage = (product) => product?.image_url || `/images/${product?.image_name || 'ArtisanHomeAccent.jpg'}`;
export const escapeSlug = (value) => String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
export const categoryLabel = (value, categories = []) => categories.find(category => category.slug === escapeSlug(value) || escapeSlug(category.name) === escapeSlug(value))?.name || String(value || '').replaceAll('-', ' ');
