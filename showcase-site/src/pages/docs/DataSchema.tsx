import { Database, User, Calendar, Activity, AlertCircle, FileText } from 'lucide-react';

export default function DataSchema() {
  const tableGroups = [
    {
      title: 'User Identity',
      icon: User,
      tables: ['students', 'lecturers', 'admins'],
      desc: 'Manages credentials, UUID-based authentication, and face embeddings.'
    },
    {
      title: 'Academic Structure',
      icon: Calendar,
      tables: ['courses', 'classes', 'class_schedule', 'enrollments'],
      desc: 'Defines the institutional hierarchy and semester-based scheduling.'
    },
    {
      title: 'Session Logs',
      icon: Activity,
      tables: ['lectures', 'emotion_log', 'attendance_log', 'focus_strikes'],
      desc: 'Stores high-velocity real-time data from the vision pipeline and mobile apps.'
    },
    {
      title: 'Academic Assets',
      icon: FileText,
      tables: ['materials', 'comprehension_checks', 'student_answers'],
      desc: 'Links lecture slides, AI-generated quizzes, and student responses.'
    },
    {
      title: 'Security & Monitoring',
      icon: AlertCircle,
      tables: ['exams', 'incidents', 'notifications'],
      desc: 'Tracks proctoring violations and system-wide alerts.'
    }
  ];

  return (
    <div className="space-y-16 animate-fade-in-up">
      <section>
        <h1 className="text-4xl font-extrabold text-white mb-4">Data Architecture</h1>
        <p className="text-xl text-white/60">
          A relational schema optimized for concurrent vision-thread writes and complex analytics.
        </p>
      </section>

      {/* Grid of Tables */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {tableGroups.map((group, idx) => (
          <div key={idx} className="glass-card p-8 rounded-3xl group">
            <div className="flex items-center gap-4 mb-6">
              <div className="p-3 bg-aast-gold/20 text-aast-gold rounded-xl">
                <group.icon size={24} />
              </div>
              <h3 className="text-xl font-bold text-white">{group.title}</h3>
            </div>
            <p className="text-white/50 text-sm mb-6 leading-relaxed">
              {group.desc}
            </p>
            <div className="flex flex-wrap gap-2">
              {group.tables.map(table => (
                <span key={table} className="px-3 py-1 bg-white/5 border border-white/10 rounded-lg text-xs font-mono text-white/70 group-hover:border-aast-gold/30 group-hover:text-aast-gold transition-colors">
                  {table}
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Database Stats Section */}
      <section className="glass-panel p-10 rounded-3xl border border-white/5 bg-gradient-to-br from-white/[0.02] to-transparent">
        <div className="flex flex-col md:flex-row items-center justify-between gap-12">
          <div className="space-y-6 md:w-1/2">
            <h2 className="text-2xl font-bold text-white">PostgreSQL Performance</h2>
            <div className="space-y-4">
              <div className="flex items-center gap-4">
                <div className="w-2 h-2 rounded-full bg-green-400"></div>
                <p className="text-sm text-white/70 font-medium">Write-Ahead Logging (WAL) for 100+ concurrent streams</p>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-2 h-2 rounded-full bg-green-400"></div>
                <p className="text-sm text-white/70 font-medium">TIMESTAMPTZ (UTC) for global temporal accuracy</p>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-2 h-2 rounded-full bg-green-400"></div>
                <p className="text-sm text-white/70 font-medium">BYTEA storage for optimized ArcFace embedding lookups</p>
              </div>
            </div>
          </div>
          
          <div className="md:w-1/2 flex justify-center">
            <div className="relative w-48 h-48 flex items-center justify-center">
              {/* Decorative Rings */}
              <div className="absolute inset-0 border border-aast-gold/20 rounded-full animate-spin" style={{ animationDuration: '10s' }}></div>
              <div className="absolute inset-4 border border-white/5 rounded-full animate-spin" style={{ animationDuration: '15s', animationDirection: 'reverse' }}></div>
              
              <div className="flex flex-col items-center">
                <Database size={48} className="text-aast-gold mb-2" />
                <span className="text-3xl font-black text-white">16</span>
                <span className="text-[10px] font-bold text-white/40 uppercase tracking-widest">Normal Tables</span>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
