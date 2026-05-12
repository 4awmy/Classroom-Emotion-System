import { FileText, BookOpen, ShieldCheck, Cpu, Database } from 'lucide-react';
import { NavLink } from 'react-router-dom';

const navItems = [
  { name: 'System Overview', path: '/docs/overview', icon: BookOpen },
  { name: 'Architecture', path: '/docs/architecture', icon: Cpu },
  { name: 'AI Pipeline', path: '/docs/ai', icon: ShieldCheck },
  { name: 'Data Schema', path: '/docs/database', icon: Database },
  { name: 'Testing Manual', path: '/manual', icon: FileText },
];

export default function Sidebar() {
  return (
    <aside className="w-64 bg-white border-r border-aast-gray h-[calc(100vh-5rem)] sticky top-20 overflow-y-auto">
      <div className="p-6">
        <h2 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-4">
          Documentation
        </h2>
        <nav className="space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-aast-navy text-white shadow-md'
                    : 'text-gray-600 hover:bg-aast-gray hover:text-aast-navy'
                }`
              }
            >
              <item.icon size={18} />
              {item.name}
            </NavLink>
          ))}
        </nav>
      </div>
    </aside>
  );
}
