import React, { useEffect, useState } from 'react';
import axios from 'axios';

interface Product { id: string; name: string; price: number; }
interface Order { id: string; productId: string; createdAt: string; }

const apiBaseProducts = import.meta.env.VITE_PRODUCTS_URL || 'http://localhost:5001';
const apiBaseOrders = import.meta.env.VITE_ORDERS_URL || 'http://localhost:5002';

export default function App() {
  const [products, setProducts] = useState<Product[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [name, setName] = useState('');
  const [price, setPrice] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    try {
      const [p,o] = await Promise.all([
        axios.get<Product[]>(`${apiBaseProducts}/products`),
        axios.get<Order[]>(`${apiBaseOrders}/orders`)
      ]);
      setProducts(p.data);
      setOrders(o.data);
    } catch (e:any) {
      setError(e.message);
    }
  }

  async function createProduct(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await axios.post(`${apiBaseProducts}/products`, { name, price: parseFloat(price) });
      setName(''); setPrice('');
      // allow Dapr event propagation then refresh
      setTimeout(refresh, 600);
    } catch (e:any) { setError(e.message); }
    finally { setLoading(false); }
  }

  useEffect(() => { refresh(); const i = setInterval(refresh, 5000); return () => clearInterval(i); }, []);

  return (
    <div style={{ fontFamily:'system-ui', margin:'2rem' }}>
      <h1>Dapr Products & Orders</h1>
      <form onSubmit={createProduct} style={{ marginBottom:'1rem' }}>
        <input placeholder="Name" value={name} onChange={e=>setName(e.target.value)} required />{' '}
        <input placeholder="Price" type="number" step="0.01" value={price} onChange={e=>setPrice(e.target.value)} required />{' '}
        <button disabled={loading}>{loading?'Creating...':'Create Product'}</button>
      </form>
      {error && <p style={{color:'red'}}>{error}</p>}
      <div style={{display:'flex', gap:'2rem'}}>
        <div>
          <h2>Products ({products.length})</h2>
          <ul>
            {products.map(p=> <li key={p.id}>{p.name} (${p.price})</li>)}
          </ul>
        </div>
        <div>
          <h2>Orders ({orders.length})</h2>
          <ul>
            {orders.map(o=> <li key={o.id}>{o.id.slice(0,8)}... product {o.productId.slice(0,8)}...</li>)}
          </ul>
        </div>
      </div>
    </div>
  );
}
