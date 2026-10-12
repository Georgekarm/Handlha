import React from 'react';
import { useApp } from './context/AppContext';
import { HandelhaAppShell } from './components/HandelhaAppShell';
import { DashboardScreen } from './screens/DashboardScreen';
import { TasksScreen } from './screens/TasksScreen';
import { ProjectsScreen } from './screens/ProjectsScreen';
import { ProjectWorkspaceScreen } from './screens/ProjectWorkspaceScreen';
import { HandelhaFocusSessionScreen } from './screens/HandelhaFocusSessionScreen';
import { ChatScreen } from './screens/ChatScreen';
import { NotificationsScreen } from './screens/NotificationsScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { LoginScreen } from './screens/LoginScreen';
import { SignUpScreen } from './screens/SignUpScreen';
import { ForgotPasswordScreen } from './screens/ForgotPasswordScreen';
import { OnboardingScreen } from './screens/OnboardingScreen';
import { SplashScreen } from './screens/SplashScreen';
import { AddChoiceModal } from './components/AddChoiceModal';
import { QuickAddModal } from './components/QuickAddModal';
import { SmartAddTaskSheet } from './components/SmartAddTaskSheet';
import { AiBreakdownModal } from './components/AiBreakdownModal';
import { NewProjectModal } from './components/NewProjectModal';
import { AnalyticsScreen } from './screens/AnalyticsScreen';
import { SmartNotificationToast } from './components/SmartNotificationToast';

export const AppContent: React.FC = () => {
  const { currentRoute } = useApp();

  const renderScreen = () => {
    switch (currentRoute) {
      case '/splash':
        return <SplashScreen />;
      case '/login':
        return <LoginScreen />;
      case '/signup':
        return <SignUpScreen />;
      case '/forgot-password':
        return <ForgotPasswordScreen />;
      case '/onboarding':
        return <OnboardingScreen />;
      case '/focus-session':
        return <HandelhaFocusSessionScreen />;
      case '/notifications':
        return (
          <HandelhaAppShell>
            <NotificationsScreen />
          </HandelhaAppShell>
        );
      case '/settings':
        return (
          <HandelhaAppShell>
            <SettingsScreen />
          </HandelhaAppShell>
        );
      case '/project-workspace':
        return (
          <HandelhaAppShell>
            <ProjectWorkspaceScreen />
          </HandelhaAppShell>
        );
      case '/tasks':
        return (
          <HandelhaAppShell>
            <TasksScreen />
          </HandelhaAppShell>
        );
      case '/projects':
        return (
          <HandelhaAppShell>
            <ProjectsScreen />
          </HandelhaAppShell>
        );
      case '/analytics':
        return (
          <HandelhaAppShell>
            <AnalyticsScreen />
          </HandelhaAppShell>
        );
      case '/chat':
        return (
          <HandelhaAppShell>
            <ChatScreen />
          </HandelhaAppShell>
        );
      case '/home':
      default:
        return (
          <HandelhaAppShell>
            <DashboardScreen />
          </HandelhaAppShell>
        );
    }
  };

  return (
    <>
      <SmartNotificationToast />
      {renderScreen()}
      {/* Global Modals & Sheets — Guaranteed to be available and functional across ALL screens */}
      <AddChoiceModal />
      <QuickAddModal />
      <SmartAddTaskSheet />
      <AiBreakdownModal />
      <NewProjectModal />
    </>
  );
};

export default function App() {
  return <AppContent />;
}

