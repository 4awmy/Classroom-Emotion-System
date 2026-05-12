import { Outlet, useLocation } from 'react-router-dom';
import { useState } from 'react';
import Header from '../components/Header';
import Footer from '../components/Footer';
import Sidebar from '../components/Sidebar';

export default function MainLayout() {
  const location = useLocation();
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  
  const showSidebar = location.pathname !== '/';

  return (
    <div className="min-h-screen flex flex-col font-sans relative">
      <Header onMenuClick={() => setIsSidebarOpen(!isSidebarOpen)} />
      
      <div className="flex-grow flex max-w-7xl mx-auto w-full pt-20">
        {showSidebar && (
          <Sidebar 
            isOpen={isSidebarOpen} 
            onClose={() => setIsSidebarOpen(false)} 
          />
        )}
        
        <main className={`flex-grow p-4 sm:p-8 w-full ${showSidebar ? 'md:ml-64' : ''}`}>
          <Outlet />
        </main>
      </div>
      
      <Footer />
    </div>
  );
}
