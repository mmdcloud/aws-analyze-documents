import { Document, ChatMessage } from '../types';

export const mockDocuments: Document[] = [
  {
    id: '1',
    name: 'Financial Report Q3 2024.pdf',
    type: 'application/pdf',
    size: 2500000,
    uploadDate: '2024-03-15T10:30:00Z',
    status: 'ready',
    tags: ['finance', 'quarterly'],
    description: 'Third quarter financial analysis and projections'
  },
  {
    id: '2',
    name: 'Marketing Strategy.docx',
    type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    size: 1800000,
    uploadDate: '2024-03-14T14:22:00Z',
    status: 'ready',
    tags: ['marketing', 'strategy'],
    description: 'Comprehensive marketing strategy for 2024'
  },
  {
    id: '3',
    name: 'User Research Data.xlsx',
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    size: 3200000,
    uploadDate: '2024-03-13T09:15:00Z',
    status: 'processing',
    tags: ['research', 'data'],
    description: 'User interview findings and survey results'
  },
  {
    id: '4',
    name: 'Project Timeline.pdf',
    type: 'application/pdf',
    size: 1200000,
    uploadDate: '2024-03-12T16:45:00Z',
    status: 'ready',
    tags: ['project', 'timeline'],
    description: 'Development roadmap and key milestones'
  },
  {
    id: '5',
    name: 'Technical Specifications.pdf',
    type: 'application/pdf',
    size: 4100000,
    uploadDate: '2024-03-11T11:20:00Z',
    status: 'ready',
    tags: ['technical', 'specs'],
    description: 'Detailed technical requirements and architecture'
  },
  {
    id: '6',
    name: 'Budget Analysis.xlsx',
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    size: 2800000,
    uploadDate: '2024-03-10T13:10:00Z',
    status: 'error',
    tags: ['budget', 'finance'],
    description: 'Annual budget breakdown and cost analysis'
  }
];

export const mockChatMessages: ChatMessage[] = [
  {
    id: '1',
    content: 'Hello! How can I help you with your documents today?',
    isUser: false,
    timestamp: '2024-03-15T09:00:00Z'
  },
  {
    id: '2',
    content: 'I need help understanding the financial report from Q3.',
    isUser: true,
    timestamp: '2024-03-15T09:01:00Z'
  },
  {
    id: '3',
    content: 'I can help you with that! The Q3 financial report shows strong growth in revenue, with a 15% increase compared to Q2. The main drivers were increased customer acquisition and improved retention rates. Would you like me to elaborate on any specific section?',
    isUser: false,
    timestamp: '2024-03-15T09:01:30Z'
  }
];

export const formatFileSize = (bytes: number): string => {
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  if (bytes === 0) return '0 Bytes';
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
};

export const formatDate = (dateString: string): string => {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
};