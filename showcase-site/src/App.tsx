import { BrowserRouter, Routes, Route } from 'react-router-dom';
import MainLayout from './layouts/MainLayout';
import Home from './pages/Home';
import Docs from './pages/Docs';
import Manual from './pages/Manual';

function App() {
  return (
    <BrowserRouter basename="/showcase">
      <Routes>
        <Route path="/" element={<MainLayout />}>
          <Route index element={<Home />} />
          <Route path="docs/*" element={<Docs />} />
          <Route path="manual" element={<Manual />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
