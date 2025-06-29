import React, { useState, useEffect } from 'react';
import { FileText, Upload, MessageSquare, User, Settings, LogOut, Search, Bell } from 'lucide-react';
import { Document, User as UserType, AppView } from '../../types';
import { mockDocuments } from '../../utils/mockData';
import DocumentList from './DocumentList';
import DocumentUpload from './DocumentUpload';

interface DashboardProps {
  user: UserType;
  onViewChange: (view: AppView) => void;
  onSignOut: () => void;
}

export default function Dashboard({ user, onViewChange, onSignOut }: DashboardProps) {
  const [documents, setDocuments] = useState<Document[]>(mockDocuments);
  const [filteredDocuments, setFilteredDocuments] = useState<Document[]>(mockDocuments);
  const [currentPage, setCurrentPage] = useState(1);
  const [activeTab, setActiveTab] = useState<'documents' | 'upload'>('documents');
  const documentsPerPage = 5;

  const totalPages = Math.ceil(filteredDocuments.length / documentsPerPage);
  const startIndex = (currentPage - 1) * documentsPerPage;
  const currentDocuments = filteredDocuments.slice(startIndex, startIndex + documentsPerPage);

  const handleSearch = (query: string) => {
    const filtered = documents.filter(doc =>
      doc.name.toLowerCase().includes(query.toLowerCase()) ||
      doc.description?.toLowerCase().includes(query.toLowerCase()) ||
      doc.tags.some(tag => tag.toLowerCase().includes(query.toLowerCase()))
    );
    setFilteredDocuments(filtered);
    setCurrentPage(1);
  };

  const handleFilter = (filter: string) => {
    if (filter === 'all') {
      setFilteredDocuments(documents);
    } else {
      const filtered = documents.filter(doc => doc.status === filter);
      setFilteredDocuments(filtered);
    }
    setCurrentPage(1);
  };

  const handleUpload = (files: FileList) => {
    // Simulate adding new documents
    const newDocuments = Array.from(files).map((file, index) => ({
      id: Date.now().toString() + index,
      name: file.name,
      type: file.type,
      size: file.size,
      uploadDate: new Date().toISOString(),
      status: 'processing' as const,
      tags: ['uploaded'],
      description: `Recently uploaded document`
    }));

    setDocuments(prev => [...newDocuments, ...prev]);
    setFilteredDocuments(prev => [...newDocuments, ...prev]);
  };

  const stats = [
    { label: 'Total Documents', value: documents.length, color: 'blue' },
    { label: 'Processing', value: documents.filter(d => d.status === 'processing').length, color: 'yellow' },
    { label: 'Ready', value: documents.filter(d => d.status === 'ready').length, color: 'green' },
    { label: 'Errors', value: documents.filter(d => d.status === 'error').length, color: 'red' }
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center gap-4">
              <div className="w-8 h-8 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-lg flex items-center justify-center">
                <FileText className="w-5 h-5 text-white" />
              </div>
              <h1 className="text-xl font-semibold text-gray-900">DocManager</h1>
            </div>

            <div className="flex items-center gap-4">
              <button className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors">
                <Bell className="w-5 h-5" />
              </button>
              
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-500 rounded-full flex items-center justify-center">
                  <span className="text-sm font-medium text-white">
                    {user.name.charAt(0).toUpperCase()}
                  </span>
                </div>
                <div className="hidden md:block">
                  <p className="text-sm font-medium text-gray-900">{user.name}</p>
                  <p className="text-xs text-gray-500">{user.email}</p>
                </div>
              </div>

              <button
                onClick={onSignOut}
                className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                title="Sign Out"
              >
                <LogOut className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex gap-8">
          {/* Sidebar */}
          <aside className="w-64 flex-shrink-0">
            <nav className="space-y-2">
              <button
                onClick={() => setActiveTab('documents')}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                  activeTab === 'documents'
                    ? 'bg-blue-50 text-blue-700 border border-blue-200'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <FileText className="w-5 h-5" />
                Documents
              </button>
              
              <button
                onClick={() => setActiveTab('upload')}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                  activeTab === 'upload'
                    ? 'bg-blue-50 text-blue-700 border border-blue-200'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <Upload className="w-5 h-5" />
                Upload
              </button>
              
              <button
                onClick={() => onViewChange('chat')}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left text-gray-700 hover:bg-gray-100 transition-colors"
              >
                <MessageSquare className="w-5 h-5" />
                Chat Assistant
              </button>
              
              <button
                onClick={() => onViewChange('changePassword')}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left text-gray-700 hover:bg-gray-100 transition-colors"
              >
                <Settings className="w-5 h-5" />
                Settings
              </button>
            </nav>
          </aside>

          {/* Main Content */}
          <main className="flex-1">
            {/* Stats */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
              {stats.map((stat) => (
                <div key={stat.label} className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-gray-600">{stat.label}</p>
                      <p className="text-2xl font-bold text-gray-900 mt-1">{stat.value}</p>
                    </div>
                    <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${
                      stat.color === 'blue' ? 'bg-blue-100' :
                      stat.color === 'yellow' ? 'bg-yellow-100' :
                      stat.color === 'green' ? 'bg-green-100' :
                      'bg-red-100'
                    }`}>
                      <FileText className={`w-6 h-6 ${
                        stat.color === 'blue' ? 'text-blue-600' :
                        stat.color === 'yellow' ? 'text-yellow-600' :
                        stat.color === 'green' ? 'text-green-600' :
                        'text-red-600'
                      }`} />
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* Content */}
            {activeTab === 'documents' && (
              <DocumentList
                documents={currentDocuments}
                currentPage={currentPage}
                totalPages={totalPages}
                onPageChange={setCurrentPage}
                onSearch={handleSearch}
                onFilter={handleFilter}
              />
            )}

            {activeTab === 'upload' && (
              <DocumentUpload onUpload={handleUpload} />
            )}
          </main>
        </div>
      </div>
    </div>
  );
}