import { CheckCircle2, Shield, Zap, Layout, Globe, Cpu } from 'lucide-react';

const features = [
  {
    title: 'Real-time Emotion Analysis',
    desc: 'Powered by YOLOv8 and HSEmotion to detect student engagement levels instantly.',
    icon: Zap,
  },
  {
    title: 'Automated Attendance',
    desc: 'Face-recognition based tracking with historical snapshots and R/Shiny dashboards.',
    icon: CheckCircle2,
  },
  {
    title: 'Smart Proctering',
    desc: 'Automated cheating detection and student behavior monitoring for exam security.',
    icon: Shield,
  },
  {
    title: 'AI Interventions',
    desc: 'Gemini-powered personalized questions and intervention plans for lecturers.',
    icon: Cpu,
  },
  {
    title: 'Cross-Platform App',
    desc: 'React Native student app and R/Shiny staff portal for seamless operation.',
    icon: Layout,
  },
  {
    title: 'Institutional Grade',
    desc: 'Designed specifically for the AASTMT Smart Village Campus ecosystem.',
    icon: Globe,
  },
];

export default function Home() {
  return (
    <div className="space-y-24 pb-20">
      {/* Hero Section */}
      <section className="text-center py-16">
        <div className="inline-block px-4 py-1.5 mb-6 text-sm font-semibold tracking-wide text-aast-gold uppercase bg-aast-navy/5 rounded-full border border-aast-gold/20">
          AASTMT Innovation Project
        </div>
        <h1 className="text-6xl font-extrabold text-aast-navy mb-8 tracking-tight">
          Revolutionizing the <br />
          <span className="text-aast-gold">Classroom Experience</span>
        </h1>
        <p className="text-xl text-gray-600 max-w-3xl mx-auto leading-relaxed mb-10">
          An end-to-end AI system that bridges the gap between student engagement and academic success through real-time vision analytics and intelligent interventions.
        </p>
        <div className="flex justify-center gap-4">
          <a href="/docs/overview" className="bg-aast-navy text-white px-8 py-4 rounded-xl font-bold shadow-xl hover:shadow-aast-navy/20 transition-all">
            Get Started
          </a>
          <a href="#demo" className="bg-white text-aast-navy border-2 border-aast-navy/10 px-8 py-4 rounded-xl font-bold hover:bg-aast-gray transition-all">
            Watch Demo
          </a>
        </div>
      </section>

      {/* Demo Video Section */}
      <section id="demo" className="relative">
        <div className="absolute inset-0 bg-aast-navy rounded-[3rem] -rotate-1 scale-105 opacity-5"></div>
        <div className="bg-black rounded-[2rem] overflow-hidden shadow-2xl aspect-video relative group ring-12 ring-white">
          {/* In a real scenario, this would be a YouTube iframe. Placeholder for now. */}
          <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-tr from-aast-navy/80 to-transparent">
            <div className="w-24 h-24 bg-aast-gold text-aast-navy rounded-full flex items-center justify-center shadow-2xl group-hover:scale-110 transition-all cursor-pointer">
              <div className="ml-2 border-y-[12px] border-y-transparent border-l-[20px] border-l-aast-navy"></div>
            </div>
          </div>
          <div className="absolute top-8 left-8">
            <div className="flex items-center gap-2 bg-white/10 backdrop-blur-md px-4 py-2 rounded-full border border-white/20 text-white text-sm font-medium">
              <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
              Live Demo Recording
            </div>
          </div>
        </div>
      </section>

      {/* Case Study / Feature Grid */}
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {features.map((f, i) => (
          <div key={i} className="bg-white p-8 rounded-2xl border border-aast-gray hover:border-aast-gold/30 hover:shadow-xl hover:shadow-aast-gold/5 transition-all group">
            <div className="w-12 h-12 bg-aast-gray rounded-xl flex items-center justify-center text-aast-navy group-hover:bg-aast-gold group-hover:text-aast-navy transition-colors mb-6">
              <f.icon size={24} />
            </div>
            <h3 className="text-xl font-bold text-aast-navy mb-3">{f.title}</h3>
            <p className="text-gray-500 leading-relaxed text-sm">
              {f.desc}
            </p>
          </div>
        ))}
      </section>

      {/* Case Study Section */}
      <section className="bg-white rounded-3xl p-12 border border-aast-gray shadow-sm">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold text-aast-navy mb-8 text-center">Project Impact</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-12 text-center">
            <div>
              <div className="text-4xl font-black text-aast-gold mb-2">98%</div>
              <div className="text-sm font-medium text-gray-500 uppercase tracking-widest">Attendance Accuracy</div>
            </div>
            <div>
              <div className="text-4xl font-black text-aast-gold mb-2">Real-time</div>
              <div className="text-sm font-medium text-gray-500 uppercase tracking-widest">Emotion Feedback</div>
            </div>
            <div>
              <div className="text-4xl font-black text-aast-gold mb-2">Zero</div>
              <div className="text-sm font-medium text-gray-500 uppercase tracking-widest">Manual Paperwork</div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
