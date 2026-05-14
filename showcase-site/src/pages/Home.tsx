import { CheckCircle2, Shield, Zap, Layout, Globe, Cpu, BookOpen, Key, PlayCircle } from 'lucide-react';
import { Link } from 'react-router-dom';

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
    title: 'Smart Proctoring',
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

const quickNav = [
  { name: 'System Architecture', path: '/docs/architecture', icon: Cpu, desc: 'Technical component breakdown' },
  { name: 'Testing Manual', path: '/manual', icon: Key, desc: 'Credentials & instructions' },
  { name: 'User Documentation', path: '/docs/overview', icon: BookOpen, desc: 'How to use the system' },
  { name: 'Live Demo', path: '#demo', icon: PlayCircle, desc: 'Watch the system in action' },
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
          <Link to="/docs/overview" className="bg-aast-navy text-white px-8 py-4 rounded-xl font-bold shadow-xl hover:shadow-aast-navy/20 transition-all text-center">
            Get Started
          </Link>
          <a href="#demo" className="bg-white text-aast-navy border-2 border-aast-navy/10 px-8 py-4 rounded-xl font-bold hover:bg-aast-gray transition-all text-center">
            Watch Demo
          </a>
        </div>
      </section>

      {/* Quick Navigation / "Navbar" on Main Page */}
      <section className="bg-white rounded-3xl p-4 shadow-xl border border-gray-100 max-w-5xl mx-auto -mt-12 relative z-10">
        <div className="grid grid-cols-2 md:grid-cols-4 divide-x divide-gray-100">
          {quickNav.map((item) => (
            <Link 
              key={item.name} 
              to={item.path} 
              className="p-6 hover:bg-aast-gray transition-all group flex flex-col items-center text-center"
            >
              <item.icon size={24} className="text-aast-navy mb-3 group-hover:text-aast-gold transition-colors" />
              <span className="font-bold text-aast-navy text-sm">{item.name}</span>
              <span className="text-[10px] text-gray-400 mt-1 uppercase tracking-wider">{item.desc}</span>
            </Link>
          ))}
        </div>
      </section>

      {/* Demo Video Section */}
      <section id="demo" className="relative">
        <div className="absolute inset-0 bg-aast-navy rounded-[3rem] -rotate-1 scale-105 opacity-5"></div>
        <div className="bg-black rounded-[2rem] overflow-hidden shadow-2xl relative ring-12 ring-white">
          <div className="absolute top-8 left-8 z-10 pointer-events-none">
            <div className="flex items-center gap-2 bg-white/10 backdrop-blur-md px-4 py-2 rounded-full border border-white/20 text-white text-sm font-medium">
              <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
              Live Demo Recording
            </div>
          </div>
          <video
            className="w-full rounded-[2rem]"
            controls
            preload="metadata"
            poster=""
          >
            <source src="/demo.mp4" type="video/mp4" />
            Your browser does not support the video tag.
          </video>
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

      {/* Impact Section */}
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
