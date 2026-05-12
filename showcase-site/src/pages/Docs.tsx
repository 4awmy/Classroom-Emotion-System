import { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import MarkdownRenderer from '../components/MarkdownRenderer';

const docsMap: any = import.meta.glob('../docs/*.md', { query: '?raw' });

export default function Docs() {
  const location = useLocation();
  const [content, setContent] = useState<string>('Loading documentation...');
  
  const docKey = location.pathname.split('/').pop() || 'overview';
  const docPath = `../docs/${docKey}.md`;

  useEffect(() => {
    const loadDoc = async () => {
      try {
        if (docsMap[docPath]) {
          const module = await docsMap[docPath]();
          setContent(module.default);
        } else {
          setContent('# 404\nDocumentation section not found.');
        }
      } catch (err) {
        setContent('# Error\nFailed to load documentation content.');
      }
    };
    loadDoc();
  }, [docPath]);

  return (
    <div className="max-w-4xl">
      <MarkdownRenderer content={content} />
    </div>
  );
}
