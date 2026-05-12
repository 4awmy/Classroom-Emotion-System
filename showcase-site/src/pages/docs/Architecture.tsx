import { Server, Monitor, Database, Cloud, Activity, Smartphone } from 'lucide-react';

export default function Architecture() {
  return (
    <div className="space-y-16 animate-fade-in-up">
      <section>
        <h1 className="text-4xl font-extrabold text-white mb-4">Logical Architecture</h1>
        <p className="text-xl text-white/60">
          A hybrid cloud-edge system designed for high-throughput vision analytics and low-latency feedback.
        </p>
      </section>

      {/* Layer Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Layer 1: Classroom Edge */}
        <div className="glass-card p-8 rounded-3xl relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-32 h-32 bg-blue-500/5 rounded-full blur-3xl group-hover:bg-blue-500/10 transition-colors"></div>
          <div className="flex items-center gap-4 mb-8">
            <div className="p-3 bg-blue-500/20 text-blue-400 rounded-2xl">
              <Monitor size={32} />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-white">Classroom Edge</h2>
              <p className="text-blue-400/60 text-sm font-mono">Local Processing Layer</p>
            </div>
          </div>
          <ul className="space-y-4">
            <li className="flex items-start gap-3">
              <div className="mt-1.5 w-1.5 h-1.5 rounded-full bg-blue-400"></div>
              <p className="text-white/70 text-sm"><strong className="text-white">Vision Node:</strong> Python-based pipeline running on classroom hardware.</p>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1.5 w-1.5 h-1.5 rounded-full bg-blue-400"></div>
              <p className="text-white/70 text-sm"><strong className="text-white">AI Inference:</strong> Local execution of YOLOv8 and HSEmotion to preserve privacy.</p>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1.5 w-1.5 h-1.5 rounded-full bg-blue-400"></div>
              <p className="text-white/70 text-sm"><strong className="text-white">Metadata Sync:</strong> Anonymized JSON logs sent to cloud via HTTP/WS.</p>
            </li>
          </ul>
        </div>

        {/* Layer 2: DigitalOcean Cloud */}
        <div className="glass-card p-8 rounded-3xl relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-32 h-32 bg-purple-500/5 rounded-full blur-3xl group-hover:bg-purple-500/10 transition-colors"></div>
          <div className="flex items-center gap-4 mb-8">
            <div className="p-3 bg-purple-500/20 text-purple-400 rounded-2xl">
              <Cloud size={32} />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-white">Cloud Infrastructure</h2>
              <p className="text-purple-400/60 text-sm font-mono">Centralized Management</p>
            </div>
          </div>
          <ul className="space-y-4">
            <li className="flex items-start gap-3">
              <div className="mt-1.5 w-1.5 h-1.5 rounded-full bg-purple-400"></div>
              <p className="text-white/70 text-sm"><strong className="text-white">FastAPI Backend:</strong> High-performance async API orchestrating all data flows.</p>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1.5 w-1.5 h-1.5 rounded-full bg-purple-400"></div>
              <p className="text-white/70 text-sm"><strong className="text-white">Managed DB:</strong> Scalable PostgreSQL instance with WAL for concurrent writes.</p>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1.5 w-1.5 h-1.5 rounded-full bg-purple-400"></div>
              <p className="text-white/70 text-sm"><strong className="text-white">Object Storage:</strong> S3-compatible spaces for attendance snapshots.</p>
            </li>
          </ul>
        </div>
      </div>

      {/* Visual Flow Diagram */}
      <section className="glass-panel p-10 rounded-3xl border border-white/10">
        <h2 className="text-2xl font-bold text-white mb-10 text-center">End-to-End Data Flow</h2>
        <div className="flex flex-col md:flex-row items-center justify-between gap-8 md:gap-4 relative">
          {/* Connector Line (Desktop) */}
          <div className="hidden md:block absolute top-1/2 left-0 w-full h-px bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-y-1/2"></div>
          
          {[
            { icon: Monitor, label: 'Camera Feed', desc: 'RTSP Stream' },
            { icon: Activity, label: 'AI Inference', desc: 'Vision Pipeline' },
            { icon: Server, label: 'FastAPI', desc: 'WebSocket Hub' },
            { icon: Database, label: 'PostgreSQL', desc: 'Managed DB' },
            { icon: Smartphone, label: 'Student App', desc: 'Real-time Alerts' }
          ].map((item, idx) => (
            <div key={idx} className="relative z-10 flex flex-col items-center text-center group">
              <div className="w-16 h-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-aast-gold group-hover:scale-110 group-hover:border-aast-gold/50 transition-all duration-300 backdrop-blur-md mb-4 shadow-xl">
                <item.icon size={28} />
              </div>
              <h3 className="text-white font-bold text-sm mb-1">{item.label}</h3>
              <p className="text-white/40 text-xs font-mono">{item.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Standards Section */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="p-6 border border-white/5 rounded-2xl bg-white/2">
          <h4 className="text-aast-gold font-bold text-sm uppercase tracking-widest mb-3">Identity</h4>
          <p className="text-white/60 text-sm">Standardized UUID-based auth with English transliteration for names.</p>
        </div>
        <div className="p-6 border border-white/5 rounded-2xl bg-white/2">
          <h4 className="text-aast-gold font-bold text-sm uppercase tracking-widest mb-3">Timezone</h4>
          <p className="text-white/60 text-sm">UTC persistence (TIMESTAMPTZ) for all academic and analytical logs.</p>
        </div>
        <div className="p-6 border border-white/5 rounded-2xl bg-white/2">
          <h4 className="text-aast-gold font-bold text-sm uppercase tracking-widest mb-3">Formats</h4>
          <p className="text-white/60 text-sm">BYTEA storage for 512-dim face embeddings to ensure fast lookups.</p>
        </div>
      </section>
    </div>
  );
}
