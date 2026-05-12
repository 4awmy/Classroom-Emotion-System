import { Scan, Users, Smile, BrainCircuit, MessageSquare, Zap } from 'lucide-react';

export default function AIPipeline() {
  const steps = [
    {
      title: 'Crowd Detection',
      icon: Users,
      model: 'YOLOv8 Nano',
      desc: 'Detects all persons in the classroom frame to define processing regions of interest (ROIs).',
      color: 'bg-blue-500/20 text-blue-400'
    },
    {
      title: 'Face Localization',
      icon: Scan,
      model: 'YOLOv8-Face',
      desc: 'Isolates high-resolution face crops within person ROIs for precise emotional mapping.',
      color: 'bg-purple-500/20 text-purple-400'
    },
    {
      title: 'Emotion Recognition',
      icon: Smile,
      model: 'HSEmotion (ENet-B0)',
      desc: 'Classifies facial expressions into 8 AffectNet categories, then maps them to educational states.',
      color: 'bg-green-500/20 text-green-400'
    },
    {
      title: 'Identity Matching',
      icon: Zap,
      model: 'InsightFace / ArcFace',
      desc: 'Compares 512-dim embeddings against the student roster to log attendance and unique profiles.',
      color: 'bg-orange-500/20 text-orange-400'
    }
  ];

  return (
    <div className="space-y-16 animate-fade-in-up">
      <section>
        <h1 className="text-4xl font-extrabold text-white mb-4">AI Pipeline Specification</h1>
        <p className="text-xl text-white/60">
          A sequential, high-velocity inference stack combining computer vision and generative AI.
        </p>
      </section>

      {/* Sequential Pipeline */}
      <div className="relative">
        {/* Connector Line */}
        <div className="absolute left-8 top-0 bottom-0 w-px bg-gradient-to-b from-transparent via-white/10 to-transparent hidden md:block"></div>
        
        <div className="space-y-8">
          {steps.map((step, idx) => (
            <div key={idx} className="relative md:pl-20 group">
              {/* Step Number Badge */}
              <div className="absolute left-0 top-0 hidden md:flex w-16 h-16 rounded-2xl glass-panel border border-white/10 items-center justify-center text-white/40 group-hover:border-aast-gold/50 group-hover:text-aast-gold transition-all duration-300">
                <span className="text-2xl font-black">0{idx + 1}</span>
              </div>
              
              <div className="glass-card p-8 rounded-3xl group-hover:translate-x-2 transition-transform duration-300">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-4">
                  <div className="flex items-center gap-4">
                    <div className={`p-3 rounded-xl ${step.color}`}>
                      <step.icon size={24} />
                    </div>
                    <div>
                      <h3 className="text-xl font-bold text-white">{step.title}</h3>
                      <p className="text-aast-gold text-xs font-mono tracking-widest uppercase">{step.model}</p>
                    </div>
                  </div>
                </div>
                <p className="text-white/60 text-sm leading-relaxed max-w-2xl">
                  {step.desc}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Gemini Section */}
      <section className="glass-panel p-10 rounded-3xl border border-aast-gold/10 relative overflow-hidden">
        <div className="absolute -top-24 -right-24 w-64 h-64 bg-aast-gold/5 rounded-full blur-3xl animate-pulse"></div>
        
        <div className="flex flex-col lg:flex-row gap-12 items-center">
          <div className="lg:w-1/2">
            <div className="flex items-center gap-3 mb-6">
              <div className="p-3 bg-gradient-to-br from-aast-gold to-aast-gold-light text-aast-navy rounded-2xl shadow-xl shadow-aast-gold/20">
                <BrainCircuit size={32} />
              </div>
              <h2 className="text-3xl font-bold text-white leading-tight">Gemini-Powered <br />Interventions</h2>
            </div>
            <p className="text-white/70 mb-8 leading-relaxed">
              When the system detects a confusion spike in the classroom, it automatically triggers the Google Gemini model to analyze lecture slides and generate real-time clarifying questions.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="flex items-center gap-3 p-4 bg-white/5 rounded-xl border border-white/5">
                <MessageSquare className="text-aast-gold" size={20} />
                <span className="text-sm text-white/80">Smart Notes</span>
              </div>
              <div className="flex items-center gap-3 p-4 bg-white/5 rounded-xl border border-white/5">
                <Zap className="text-aast-gold" size={20} />
                <span className="text-sm text-white/80">Fresh-Brainer Live Quizzes</span>
              </div>
            </div>
          </div>
          
          <div className="lg:w-1/2 w-full">
            <div className="bg-black/40 rounded-2xl border border-white/10 p-6 font-mono text-xs space-y-4">
              <div className="flex justify-between items-center text-white/40 border-b border-white/5 pb-2 mb-4">
                <span>gemini-2.5-flash-inference.log</span>
                <div className="flex gap-1">
                  <div className="w-2 h-2 rounded-full bg-red-500/50"></div>
                  <div className="w-2 h-2 rounded-full bg-yellow-500/50"></div>
                  <div className="w-2 h-2 rounded-full bg-green-500/50"></div>
                </div>
              </div>
              <div className="text-green-400">{">"} Trigger: Confusion Spike Detected (0.42)</div>
              <div className="text-white/60">{">"} Analyzing current slide content...</div>
              <div className="text-blue-400">{">"} Querying Gemini: "Generate clarifying question for topic: Neural Architecture"</div>
              <div className="text-aast-gold bg-aast-gold/10 p-3 rounded border border-aast-gold/20 animate-pulse">
                "Wait, do we all understand how the backpropagation error propagates through the convolutional layers?"
              </div>
              <div className="text-green-400">{">"} Broadcast sent to WebSocket hub.</div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
