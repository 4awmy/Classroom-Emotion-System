import { useEffect, useRef } from 'react';
import mermaid from 'mermaid';

mermaid.initialize({
  startOnLoad: true,
  theme: 'base',
  themeVariables: {
    primaryColor: '#002244',
    primaryTextColor: '#fff',
    primaryBorderColor: '#C49808',
    lineColor: '#C49808',
    secondaryColor: '#f4f4f4',
    tertiaryColor: '#fff',
  },
});

interface MermaidProps {
  chart: string;
}

export default function Mermaid({ chart }: MermaidProps) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (ref.current) {
      mermaid.contentLoaded();
    }
  }, [chart]);

  return (
    <div className="mermaid flex justify-center my-8 p-4 bg-white rounded-xl shadow-sm border border-gray-100 overflow-x-auto" ref={ref}>
      {chart}
    </div>
  );
}
