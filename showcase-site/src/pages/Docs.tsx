import { useLocation, Navigate } from 'react-router-dom';
import Overview from './docs/Overview';
import Architecture from './docs/Architecture';
import AIPipeline from './docs/AIPipeline';
import DataSchema from './docs/DataSchema';

export default function Docs() {
  const location = useLocation();
  const docKey = location.pathname.split('/').pop();

  const renderDoc = () => {
    switch (docKey) {
      case 'overview':
        return <Overview />;
      case 'architecture':
        return <Architecture />;
      case 'ai':
        return <AIPipeline />;
      case 'database':
        return <DataSchema />;
      default:
        return <Overview />;
    }
  };

  // If base /docs path is accessed, redirect to overview
  if (location.pathname === '/docs' || location.pathname === '/docs/') {
    return <Navigate to="/docs/overview" replace />;
  }

  return (
    <div className="w-full max-w-5xl mx-auto">
      {renderDoc()}
    </div>
  );
}
