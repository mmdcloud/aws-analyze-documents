export interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
}

export interface Document {
  id: string;
  name: string;
  type: string;
  size: number;
  uploadDate: string;
  status: 'processing' | 'ready' | 'error';
  tags: string[];
  description?: string;
}

export interface ChatMessage {
  id: string;
  content: string;
  isUser: boolean;
  timestamp: string;
  attachments?: string[];
}

export interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  loading: boolean;
}

export type AppView = 'signIn' | 'signUp' | 'changePassword' | 'dashboard' | 'chat';