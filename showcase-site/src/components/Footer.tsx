export default function Footer() {
  return (
    <footer className="bg-aast-navy text-aast-white border-t border-aast-gold/20 py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
          <div>
            <h3 className="text-aast-gold font-bold text-lg mb-4">About the Project</h3>
            <p className="text-aast-gray/80 text-sm leading-relaxed">
              An AI-powered Classroom Emotion System developed for AASTMT to enhance student engagement and automated proctoring through real-time vision pipelines.
            </p>
          </div>
          <div>
            <h3 className="text-aast-gold font-bold text-lg mb-4">Quick Links</h3>
            <ul className="space-y-2 text-sm text-aast-gray/80">
              <li><a href="#" className="hover:text-aast-gold">University Website</a></li>
              <li><a href="#" className="hover:text-aast-gold">Staff Portal (Shiny)</a></li>
              <li><a href="#" className="hover:text-aast-gold">AI Research Handout</a></li>
            </ul>
          </div>
          <div>
            <h3 className="text-aast-gold font-bold text-lg mb-4">Contact</h3>
            <p className="text-aast-gray/80 text-sm">
              Arab Academy for Science, Technology & Maritime Transport<br />
              Smart Village Campus, Egypt
            </p>
          </div>
        </div>
        <div className="mt-12 pt-8 border-t border-aast-gold/10 text-center text-xs text-aast-gray/50">
          &copy; {new Date().getFullYear()} Classroom Emotion System. All rights reserved.
        </div>
      </div>
    </footer>
  );
}
