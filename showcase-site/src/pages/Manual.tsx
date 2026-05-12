import { ExternalLink, Key, ShieldAlert, BookOpen, User, Mail, Lock } from 'lucide-react';
import MarkdownRenderer from '../components/MarkdownRenderer';
import manualContent from '../docs/manual.md?raw';

export default function Manual() {
  const credentials = [
    { role: 'Administrator', email: 'admin@aast.edu', pass: 'admin123', icon: ShieldAlert, color: 'text-red-400' },
    { role: 'Lecturer', email: 'omar@aast.edu', pass: 'omar123', icon: User, color: 'text-blue-400' },
    { role: 'Student', email: 'student@aast.edu', pass: 'student123', icon: BookOpen, color: 'text-green-400' },
  ];

  return (
    <div className="max-w-5xl mx-auto space-y-16 animate-fade-in-up">
      {/* Header */}
      <section className="glass-panel p-10 rounded-[2.5rem] border border-white/10 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-aast-gold/5 rounded-full blur-3xl pointer-events-none"></div>
        <div className="flex flex-col md:flex-row gap-8 items-center relative z-10">
          <div className="p-5 bg-gradient-to-br from-aast-gold to-aast-gold-light text-aast-navy rounded-2xl shadow-[0_0_30px_rgba(196,152,8,0.3)]">
            <Key size={40} />
          </div>
          <div className="flex-grow text-center md:text-left">
            <h1 className="text-4xl font-extrabold text-white mb-2">Testing Credentials</h1>
            <p className="text-white/60 text-lg">Use these verified accounts to explore the system's full range of capabilities.</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
          {credentials.map((cred, idx) => (
            <div key={idx} className="glass-card p-6 rounded-2xl border border-white/5 hover:border-aast-gold/30 transition-all group">
              <div className="flex items-center gap-3 mb-6">
                <div className={`p-2 bg-white/5 rounded-lg ${cred.color}`}>
                  <cred.icon size={20} />
                </div>
                <div className="text-xs font-bold text-white/40 uppercase tracking-widest">{cred.role}</div>
              </div>
              <div className="space-y-3">
                <div className="flex items-center gap-2 text-white/80">
                  <Mail size={14} className="text-aast-gold" />
                  <span className="text-sm font-medium truncate">{cred.email}</span>
                </div>
                <div className="flex items-center gap-2 text-white/80">
                  <Lock size={14} className="text-aast-gold" />
                  <span className="text-sm font-mono bg-black/30 px-2 py-0.5 rounded border border-white/5 tracking-wider">{cred.pass}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Action Cards */}
      <section className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="glass-card p-10 rounded-[2rem] border border-white/5 flex flex-col justify-between group hover:shadow-[0_0_40px_rgba(59,130,246,0.1)] transition-all">
          <div>
            <div className="flex items-center gap-3 mb-6">
              <div className="p-3 bg-blue-500/10 text-blue-400 rounded-xl group-hover:scale-110 transition-transform">
                <BookOpen size={24} />
              </div>
              <h2 className="text-2xl font-bold text-white">Staff Portal</h2>
            </div>
            <p className="text-white/50 text-sm mb-8 leading-relaxed">
              Access the deep analytics dashboard and real-time classroom monitoring tool built with R/Shiny.
            </p>
          </div>
          <a href="https://classroomx-lkbxf.ondigitalocean.app" target="_blank" className="flex items-center justify-center gap-2 w-full py-4 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl font-bold hover:shadow-[0_0_30px_rgba(59,130,246,0.4)] hover:scale-[1.02] transition-all">
            Launch Portal <ExternalLink size={18} />
          </a>
        </div>

        <div className="glass-card p-10 rounded-[2rem] border border-white/5 flex flex-col justify-between group hover:shadow-[0_0_40px_rgba(168,85,247,0.1)] transition-all">
          <div>
            <div className="flex items-center gap-3 mb-6">
              <div className="p-3 bg-purple-500/10 text-purple-400 rounded-xl group-hover:scale-110 transition-transform">
                <ShieldAlert size={24} />
              </div>
              <h2 className="text-2xl font-bold text-white">API Documentation</h2>
            </div>
            <p className="text-white/50 text-sm mb-8 leading-relaxed">
              Explore the FastAPI Swagger documentation to understand the vision pipeline and AI endpoints.
            </p>
          </div>
          <a href="https://classroomx-lkbxf.ondigitalocean.app/docs" target="_blank" className="flex items-center justify-center gap-2 w-full py-4 bg-white/5 text-white border border-white/10 rounded-xl font-bold hover:bg-white/10 hover:border-white/20 transition-all">
            Open Swagger <ExternalLink size={18} />
          </a>
        </div>
      </section>

      {/* Manual Content Section */}
      <div className="glass-panel p-12 rounded-[2.5rem] border border-white/5 relative overflow-hidden">
        <div className="absolute -bottom-24 -left-24 w-96 h-96 bg-blue-500/5 rounded-full blur-3xl pointer-events-none"></div>
        <div className="relative z-10 prose prose-invert max-w-none prose-headings:text-aast-gold prose-a:text-blue-400">
          <MarkdownRenderer content={manualContent} />
        </div>
      </div>
    </div>
  );
}
