import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

async function start() {
	try {
		const resp = await fetch('/config.json', { cache: 'no-store' });
		if (resp.ok) {
			(window as any).runtimeConfig = await resp.json();
		}
	} catch {
		// ignore, will fallback to defaults
	}
	createRoot(document.getElementById('root')!).render(<App />);
}

start();
