import "./globals.css";

export const metadata = {
  title: "SkillBridge | Learn Today. Innovate Tomorrow.",
  description:
    "SkillBridge is a Ghanaian technology education initiative empowering children aged 7–16 through digital literacy, coding, robotics and innovation.",
  openGraph: {
    title: "SkillBridge | Empowering Ghana's Next Generation",
    description: "Digital skills, coding, robotics and innovation for children aged 7–16.",
    type: "website"
  }
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      {/* Browser extensions (ClickUp and friends) stamp attributes onto <body>
          before React hydrates, which React reports as a mismatch on an
          element this app never gave a className or style to. */}
      <body suppressHydrationWarning>{children}</body>
    </html>
  );
}
