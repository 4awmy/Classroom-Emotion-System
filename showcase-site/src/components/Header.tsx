import { GraduationCap, Menu } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function Header({ onMenuClick }: { onMenuClick?: () => void }) {
  return (
    <nav className="fixed w-full top-0 z-50 glass-panel border-b border-white/10 transition-all duration-300">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-20">
          <div className="flex items-center gap-3">
            <div className="md:hidden mr-2">
              <button onClick={onMenuClick} className="text-aast-gold p-2 hover:bg-white/5 rounded-lg transition-colors">
                <Menu size={24} />
              </button>
            </div>
            <div className="p-2 bg-gradient-to-br from-aast-gold to-aast-gold-light rounded-lg text-aast-navy shadow-[0_0_15px_rgba(196,152,8,0.3)]">
              <GraduationCap size={28} />
            </div>
            <Link to="/" className="flex flex-col group">
              <span className="text-xl font-bold tracking-tight text-white group-hover:text-aast-gold transition-colors">AASTMT</span>
              <span className="text-xs text-aast-gold font-medium uppercase tracking-widest hidden sm:block">
                Classroom Emotion System
              </span>
            </Link>
          </div>
          
          <div className="flex items-center">
            <a 
              href="https://github.com/4awmy/Classroom-Emotion-System"
              target="_blank" 
              className="bg-gradient-to-r from-aast-gold to-aast-gold-light text-aast-navy px-5 py-2 rounded-lg font-bold hover:shadow-[0_0_20px_rgba(196,152,8,0.4)] hover:scale-105 transition-all text-sm sm:text-base"
            >
              GitHub
            </a>
          </div>
        </div>
      </div>
    </nav>
  );
}
