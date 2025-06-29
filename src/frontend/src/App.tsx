import React, { useState, useEffect } from 'react';
import { AppView, AuthState, User } from './types';
import SignIn from './components/auth/SignIn';
import SignUp from './components/auth/SignUp';
import ChangePassword from './components/auth/ChangePassword';
import Dashboard from './components/dashboard/Dashboard';
import ChatInterface from './components/chat/ChatInterface';

function App() {
  const [currentView, setCurrentView] = useState<AppView>('signIn');
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    user: null,
    loading: false
  });

  // Check for existing session on app load
  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (savedUser) {
      setAuthState({
        isAuthenticated: true,
        user: JSON.parse(savedUser),
        loading: false
      });
      setCurrentView('dashboard');
    }
  }, []);

  const handleSignIn = async (email: string, password: string) => {
    setAuthState(prev => ({ ...prev, loading: true }));
    
    // Simulate authentication
    setTimeout(() => {
      const user: User = {
        id: '1',
        email,
        name: email.split('@')[0].charAt(0).toUpperCase() + email.split('@')[0].slice(1),
        avatar: `https://ui-avatars.com/api/?name=${email}&background=random`
      };
      
      localStorage.setItem('user', JSON.stringify(user));
      setAuthState({
        isAuthenticated: true,
        user,
        loading: false
      });
      setCurrentView('dashboard');
    }, 1500);
  };

  const handleSignUp = async (name: string, email: string, password: string) => {
    setAuthState(prev => ({ ...prev, loading: true }));
    
    // Simulate registration
    setTimeout(() => {
      const user: User = {
        id: Date.now().toString(),
        email,
        name,
        avatar: `https://ui-avatars.com/api/?name=${name}&background=random`
      };
      
      localStorage.setItem('user', JSON.stringify(user));
      setAuthState({
        isAuthenticated: true,
        user,
        loading: false
      });
      setCurrentView('dashboard');
    }, 1500);
  };

  const handleChangePassword = async (currentPassword: string, newPassword: string) => {
    setAuthState(prev => ({ ...prev, loading: true }));
    
    // Simulate password change
    setTimeout(() => {
      setAuthState(prev => ({ ...prev, loading: false }));
      setCurrentView('dashboard');
      // In a real app, you might want to show a success message
    }, 1500);
  };

  const handleSignOut = () => {
    localStorage.removeItem('user');
    setAuthState({
      isAuthenticated: false,
      user: null,
      loading: false
    });
    setCurrentView('signIn');
  };

  const handleViewChange = (view: AppView) => {
    setCurrentView(view);
  };

  // Render current view
  switch (currentView) {
    case 'signIn':
      return (
        <SignIn
          onSignIn={handleSignIn}
          onViewChange={handleViewChange}
          loading={authState.loading}
        />
      );
    
    case 'signUp':
      return (
        <SignUp
          onSignUp={handleSignUp}
          onViewChange={handleViewChange}
          loading={authState.loading}
        />
      );
    
    case 'changePassword':
      return (
        <ChangePassword
          onChangePassword={handleChangePassword}
          onViewChange={handleViewChange}
          loading={authState.loading}
        />
      );
    
    case 'dashboard':
      if (!authState.user) return null;
      return (
        <Dashboard
          user={authState.user}
          onViewChange={handleViewChange}
          onSignOut={handleSignOut}
        />
      );
    
    case 'chat':
      return (
        <ChatInterface
          onViewChange={handleViewChange}
        />
      );
    
    default:
      return null;
  }
}

export default App;