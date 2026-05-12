import { FileText, BookOpen, ShieldCheck, Cpu, Database, X } from 'lucide-react';
import { NavLink } from 'react-router-dom';

const navItems = [
  { name: 'System Overview', path: '/docs/overview', icon: BookOpen },
  { name: 'Architecture', path: '/docs/architecture', icon: Cpu },
  { name: 'AI Pipeline', path: '/docs/ai', icon: ShieldCheck },
  { name: 'Data Schema', path: '/docs/database', icon: Database },
  { name: 'Testing Manual', path: '/manual', icon: FileText },
];

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function Sidebar({ isOpen, onClose }: SidebarProps) {
  return (
    <>
      {/* Mobile Overlay */}
      {isOpen && (
        <div 
          className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40 md:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar Content */}
      <aside className={`
        fixed md:absolute top-20 left-0 h-[calc(100vh-5rem)] w-64 glass-panel border-r border-white/10 z-50 transition-transform duration-300 ease-in-out
        ${isOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}
      `}>
        <div className="p-6 h-full overflow-y-auto">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xs font-bold text-aast-gold uppercase tracking-widest flex items-center gap-2">
              <span className="w-1.5 h-1.5 bg-aast-gold rounded-full"></span>
              Documentation
            </h2>
            <button className="md:hidden text-white/50 hover:text-white" onClick={onClose}>
              <X size={20} />
            </button>
          </div>

          <nav className="space-y-2">
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                onClick={() => { if (window.innerWidth < 768) onClose(); }}
                className={({ isActive }) =>
                  `flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all group ${
                    isActive
                      ? 'bg-gradient-to-r from-aast-gold/20 to-transparent border border-aast-gold/30 text-white shadow-[inset_4px_0_0_#C49808]'
                      : 'text-white/60 hover:bg-white/5 hover:text-white border border-transparent'
                  }`
                }
              >
                {({ isActive }) => (
                  <>
                    <item.icon size={18} className={isActive ? 'text-aast-gold' : 'group-hover:text-aast-gold/70 transition-colors'} />
                    {item.name}
                  </>
                )}
              </NavLink>
            ))}
          </nav>
        </div>
      </aside>
    </>
  );
}
