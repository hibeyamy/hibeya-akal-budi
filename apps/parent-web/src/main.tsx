import "@akal-budi/ui/styles.css";
import "@akal-budi/design-system/tokens.css";

document.documentElement.dataset.abAudience = "parent";
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
