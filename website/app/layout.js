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
      <body>{children}</body>
    </html>
  );
}
