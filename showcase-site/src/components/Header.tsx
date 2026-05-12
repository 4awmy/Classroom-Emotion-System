import { GraduationCap, Menu, X } from 'lucide-react';
import { useState } from 'react';
import { Link } from 'react-router-dom';

export default function Header() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <nav className="bg-aast-navy text-aast-white sticky top-0 z-50 shadow-lg border-b border-aast-gold/20">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-20">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-aast-gold rounded-lg text-aast-navy">
              <GraduationCap size={28} />
            </div>
            <Link to="/" className="flex flex-col">
              <span className="text-xl font-bold tracking-tight">AASTMT</span>
              <span className="text-xs text-aast-gold font-medium uppercase tracking-widest">
                Classroom Emotion System
              </span>
            </Link>
          </div>
          
          <div className="hidden md:block">
            <div className="ml-10 flex items-baseline space-x-8">
              <Link to="/" className="hover:text-aast-gold transition-colors font-medium">Home</Link>
              <Link to="/docs" className="hover:text-aast-gold transition-colors font-medium">Documentation</Link>
              <Link to="/manual" className="hover:text-aast-gold transition-colors font-medium">Testing Manual</Link>
              <a 
                href="https://github.com/omarh/Classroom-Emotion-System" 
                target="_blank" 
                className="bg-aast-gold text-aast-navy px-4 py-2 rounded-md font-bold hover:bg-white transition-all shadow-sm"
              >
                GitHub
              </a>
            </div>
          </div>

          <div className="md:hidden">
            <button onClick={() => setIsOpen(!isOpen)} className="text-aast-gold">
              {isOpen ? <X size={24} /> : <Menu size={24} />}
            </button>
          </div>
        </div>
      </div>

      {isOpen && (
        <div className="md:hidden bg-aast-navy/95 backdrop-blur-sm border-t border-aast-gold/10">
          <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
            <Link to="/" className="block px-3 py-2 rounded-md text-base font-medium hover:text-aast-gold">Home</Link>
            <Link to="/docs" className="block px-3 py-2 rounded-md text-base font-medium hover:text-aast-gold">Documentation</Link>
            <Link to="/manual" className="block px-3 py-2 rounded-md text-base font-medium hover:text-aast-gold">Testing Manual</Link>
          </div>
        </div>
      )}
    </nav>
  );
}
