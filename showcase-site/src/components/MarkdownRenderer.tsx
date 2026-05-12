import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import Mermaid from './Mermaid';

interface MarkdownRendererProps {
  content: string;
}

export default function MarkdownRenderer({ content }: MarkdownRendererProps) {
  return (
    <div className="prose prose-slate max-w-none 
      prose-headings:text-aast-navy prose-headings:font-bold
      prose-a:text-aast-gold prose-a:no-underline hover:prose-a:underline
      prose-table:border prose-table:border-gray-200
      prose-th:bg-aast-gray prose-th:p-2
      prose-td:p-2 prose-td:border-t prose-td:border-gray-100">
      <ReactMarkdown 
        remarkPlugins={[remarkGfm]}
        components={{
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          code({ inline, className, children, ...props }: any) {
            const match = /language-mermaid/.exec(className || '');
            return !inline && match ? (
              <Mermaid chart={String(children).replace(/\n$/, '')} />
            ) : (
              <code className={className} {...props}>
                {children}
              </code>
            );
          },
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  );
}
