import './global.css';
import { Header } from './components/organisms/header';

export const metadata = {
  title: 'aws-upskill',
  description: 'AWS upskill application',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Header />
        {children}
      </body>
    </html>
  );
}
