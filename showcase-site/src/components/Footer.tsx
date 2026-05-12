export default function Footer() {
  return (
    <footer className="relative z-10 glass-panel border-t border-white/5 py-12 mt-auto">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
          <div>
            <h3 className="text-aast-gold font-bold text-lg mb-4 flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-aast-gold animate-pulse"></span>
              About the Project
            </h3>
            <p className="text-white/60 text-sm leading-relaxed hover:text-white/80 transition-colors">
              An AI-powered Classroom Emotion System developed for AASTMT to enhance student engagement and automated proctoring through real-time vision pipelines.
            </p>
          </div>
          <div>
            <h3 className="text-aast-gold font-bold text-lg mb-4">Quick Links</h3>
            <ul className="space-y-3 text-sm text-white/60">
              <li><a href="https://aast.edu" target="_blank" className="hover:text-aast-gold transition-colors flex items-center gap-2"><span>→</span> University Website</a></li>
              <li><a href="https://classroomx-lkbxf.ondigitalocean.app" target="_blank" className="hover:text-aast-gold transition-colors flex items-center gap-2"><span>→</span> Staff Portal (Shiny)</a></li>
              <li><a href="https://github.com/omarh/Classroom-Emotion-System/blob/main/AI_TOOLS_HANDOUT.md" target="_blank" className="hover:text-aast-gold transition-colors flex items-center gap-2"><span>→</span> AI Research Handout</a></li>
            </ul>
          </div>
          <div>
            <h3 className="text-aast-gold font-bold text-lg mb-4">Contact</h3>
            <p className="text-white/60 text-sm hover:text-white/80 transition-colors">
              Arab Academy for Science, Technology & Maritime Transport<br />
              Smart Village Campus, Egypt
            </p>
          </div>
        </div>
        <div className="mt-12 pt-8 border-t border-white/5 text-center text-xs text-white/40">
          &copy; {new Date().getFullYear()} Classroom Emotion System. All rights reserved.
        </div>
      </div>
    </footer>
  );
}
