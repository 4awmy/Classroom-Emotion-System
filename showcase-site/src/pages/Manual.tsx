import { ExternalLink, Key, ShieldAlert, BookOpen } from 'lucide-react';
import MarkdownRenderer from '../components/MarkdownRenderer';
import manualContent from '../docs/manual.md?raw';

export default function Manual() {
  return (
    <div className="max-w-5xl mx-auto space-y-12">
      <section className="bg-white rounded-3xl p-8 border border-aast-gray shadow-sm">
        <div className="flex flex-col md:flex-row gap-8 items-center">
          <div className="p-4 bg-aast-navy text-white rounded-2xl">
            <Key size={40} />
          </div>
          <div className="flex-grow text-center md:text-left">
            <h1 className="text-3xl font-bold text-aast-navy mb-2">Testing Credentials</h1>
            <p className="text-gray-500">Use these accounts to explore the Classroom Emotion System's features.</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
          <div className="p-6 bg-aast-gray rounded-2xl border border-gray-100">
            <div className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-2">Administrator</div>
            <div className="text-aast-navy font-bold">admin@aast.edu</div>
            <div className="text-sm text-gray-500 font-mono mt-1">password: admin123</div>
          </div>
          <div className="p-6 bg-aast-gray rounded-2xl border border-gray-100">
            <div className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-2">Lecturer</div>
            <div className="text-aast-navy font-bold">omar@aast.edu</div>
            <div className="text-sm text-gray-500 font-mono mt-1">password: omar123</div>
          </div>
          <div className="p-6 bg-aast-gray rounded-2xl border border-gray-100">
            <div className="text-xs font-bold text-gray-400 uppercase tracking-widest mb-2">Student</div>
            <div className="text-aast-navy font-bold">student@aast.edu</div>
            <div className="text-sm text-gray-500 font-mono mt-1">password: student123</div>
          </div>
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="bg-white p-8 rounded-3xl border border-aast-gray shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 bg-blue-50 text-blue-600 rounded-lg"><BookOpen size={20} /></div>
              <h2 className="text-xl font-bold text-aast-navy">Staff Portal</h2>
            </div>
            <p className="text-gray-500 text-sm mb-6">
              Access the deep analytics dashboard and real-time classroom monitoring tool built with R/Shiny.
            </p>
          </div>
          <a href="#" className="flex items-center justify-center gap-2 w-full py-3 bg-aast-navy text-white rounded-xl font-bold hover:bg-aast-navy/90 transition-all">
            Launch Portal <ExternalLink size={16} />
          </a>
        </div>

        <div className="bg-white p-8 rounded-3xl border border-aast-gray shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 bg-purple-50 text-purple-600 rounded-lg"><ShieldAlert size={20} /></div>
              <h2 className="text-xl font-bold text-aast-navy">API Documentation</h2>
            </div>
            <p className="text-gray-500 text-sm mb-6">
              Explore the FastAPI Swagger documentation to understand the vision pipeline and AI endpoints.
            </p>
          </div>
          <a href="#" className="flex items-center justify-center gap-2 w-full py-3 border-2 border-aast-navy/10 text-aast-navy rounded-xl font-bold hover:bg-aast-gray transition-all">
            Open Swagger <ExternalLink size={16} />
          </a>
        </div>
      </section>

      <div className="bg-white p-12 rounded-3xl border border-aast-gray shadow-sm">
        <MarkdownRenderer content={manualContent} />
      </div>
    </div>
  );
}
