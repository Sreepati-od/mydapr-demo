import React, { useEffect, useState } from 'react';
import axios from 'axios';

interface Product { id: string; name: string; price: number; }
interface Order { id: string; productId: string; createdUtc: string; }

// Resolve API bases: prefer build-time VITE_*, then runtime injected config, fallback to localhost
const runtimeCfg: any = (window as any).runtimeConfig || {};
const apiBaseProducts = import.meta.env.VITE_PRODUCTS_URL || runtimeCfg.productsApiUrl || 'http://localhost:5001';
const apiBaseOrders = import.meta.env.VITE_ORDERS_URL || runtimeCfg.ordersApiUrl || 'http://localhost:5002';

export default function App() {
  const [products, setProducts] = useState<Product[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [name, setName] = useState('');
  const [price, setPrice] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<{productsOk:boolean;ordersOk:boolean}>({productsOk:false,ordersOk:false});

  async function refresh() {
    try {
      const [pResp,oResp] = await Promise.all([
        axios.get<Product[]>(`${apiBaseProducts}/products`).catch(e=>{throw {kind:'products',e};}),
        axios.get<Order[]>(`${apiBaseOrders}/orders`).catch(e=>{throw {kind:'orders',e};})
      ]);
      setProducts(pResp.data);
      setOrders(oResp.data);
      setStatus({productsOk:true,ordersOk:true});
    } catch (ex:any) {
      if (ex && ex.kind === 'products') {
        setStatus(s=>({...s,productsOk:false}));
        setError(`Products API error: ${ex.e.message}`);
      } else if (ex && ex.kind === 'orders') {
        setStatus(s=>({...s,ordersOk:false}));
        setError(`Orders API error: ${ex.e.message}`);
      } else {
        setError((ex as any)?.message || 'Unknown error');
      }
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
      <div style={{marginBottom:'0.75rem', fontSize:'0.9rem'}}>
        <strong>API Bases:</strong> products: <code>{apiBaseProducts}</code> | orders: <code>{apiBaseOrders}</code><br/>
        <strong>Status:</strong> products: <span style={{color:status.productsOk?'green':'red'}}>{status.productsOk?'OK':'DOWN'}</span> | orders: <span style={{color:status.ordersOk?'green':'red'}}>{status.ordersOk?'OK':'DOWN'}</span>
        <button style={{marginLeft:'1rem'}} type="button" onClick={refresh}>Manual Refresh</button>
      </div>
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
