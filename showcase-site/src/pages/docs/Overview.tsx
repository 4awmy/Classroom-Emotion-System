import { Zap, ShieldCheck, Database, Layout } from 'lucide-react';

export default function Overview() {
  return (
    <div className="space-y-12 animate-fade-in-up">
      <div>
        <h1 className="text-4xl font-extrabold text-white mb-4">System Overview</h1>
        <p className="text-xl text-white/60">
          The AASTMT Classroom Emotion System is a multi-modal AI pipeline designed to capture, analyze, and act upon student engagement data in real-time.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="glass-card p-8 rounded-2xl">
          <div className="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center text-blue-400 mb-6">
            <Zap size={24} />
          </div>
          <h2 className="text-xl font-bold text-white mb-3">Real-time Processing</h2>
          <p className="text-white/60 text-sm leading-relaxed">
            Utilizes cutting-edge edge computing devices running YOLOv8 and HSEmotion models to process 30 frames per second natively inside the classroom, minimizing latency.
          </p>
        </div>

        <div className="glass-card p-8 rounded-2xl">
          <div className="w-12 h-12 bg-purple-500/20 rounded-xl flex items-center justify-center text-purple-400 mb-6">
            <ShieldCheck size={24} />
          </div>
          <h2 className="text-xl font-bold text-white mb-3">Smart Proctoring</h2>
          <p className="text-white/60 text-sm leading-relaxed">
            Employs behavioral heuristic algorithms to detect anomalies during examination periods, alerting proctors instantly through the centralized dashboard.
          </p>
        </div>

        <div className="glass-card p-8 rounded-2xl">
          <div className="w-12 h-12 bg-green-500/20 rounded-xl flex items-center justify-center text-green-400 mb-6">
            <Database size={24} />
          </div>
          <h2 className="text-xl font-bold text-white mb-3">Supabase Integration</h2>
          <p className="text-white/60 text-sm leading-relaxed">
            All extracted metadata is instantly synced to a highly available Supabase PostgreSQL database, ensuring data integrity and enabling complex analytical queries.
          </p>
        </div>

        <div className="glass-card p-8 rounded-2xl">
          <div className="w-12 h-12 bg-orange-500/20 rounded-xl flex items-center justify-center text-orange-400 mb-6">
            <Layout size={24} />
          </div>
          <h2 className="text-xl font-bold text-white mb-3">R/Shiny Dashboards</h2>
          <p className="text-white/60 text-sm leading-relaxed">
            Lecturers have access to a rich R/Shiny application that visualizes classroom sentiment trends, attendance metrics, and automated AI interventions.
          </p>
        </div>
      </div>
    </div>
  );
}
