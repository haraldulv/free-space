import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'no.tuno.app',
  appName: 'Tuno',
  webDir: 'out',
  server: {
    url: 'https://www.tuno.no',
    cleartext: false,
  },
  ios: {
    scheme: 'Tuno',
    contentInset: 'always',
  },
  plugins: {
    StatusBar: {
      overlaysWebView: false,
      style: 'LIGHT',
      backgroundColor: '#ffffff',
    },
    SplashScreen: {
      launchAutoHide: true,
      backgroundColor: '#1a4fd6',
      showSpinner: false,
      androidSpinnerStyle: 'small',
      splashFullScreen: true,
      splashImmersive: true,
    },
  },
};

export default config;
