import { Outlet, useLocation } from 'react-router-dom';
import Header from '../components/Header';
import Footer from '../components/Footer';
import Sidebar from '../components/Sidebar';

export default function MainLayout() {
  const location = useLocation();
  const isDocs = location.pathname.startsWith('/docs');

  return (
    <div className="min-h-screen flex flex-col font-sans">
      <Header />
      <div className="flex-grow flex max-w-7xl mx-auto w-full">
        {isDocs && <Sidebar />}
        <main className={`flex-grow p-8 ${isDocs ? 'bg-white' : 'bg-aast-gray'}`}>
          <Outlet />
        </main>
      </div>
      <Footer />
    </div>
  );
}
