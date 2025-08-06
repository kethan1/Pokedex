import type { Metadata } from "next";
import { DM_Sans, Bangers } from "next/font/google";
import "./globals.css";

const dmSans = DM_Sans({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const bangers = Bangers({
  variable: "--font-bangers",
  subsets: ["latin"],
  weight: "400",
});

export const metadata: Metadata = {
  title: "Pokédex",
  description: "Multi-modal Pokémon classifier. Upload images or audio to identify Pokémon.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${dmSans.className} ${dmSans.variable} ${bangers.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
