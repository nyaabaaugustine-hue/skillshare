/* eslint-disable @next/next/no-html-link-for-pages, @next/next/no-img-element */

const appUrl = (process.env.NEXT_PUBLIC_APP_URL || "https://academy-skillshare.vercel.app").replace(/\/$/, "");
const pwaUrl = `${appUrl}/app/index.html?v=2`;

function Brand() {
  return (
    <a className="brand" href="/" aria-label="SkillBridge home">
      <span className="brand-mark"><img src="https://res.cloudinary.com/z43ds8bn/image/upload/v1795200948/WhatsApp_Image_2026-11-16_at_7.25.58_AM.jpg" alt="" /></span>
      <span className="brand-copy">
        <strong>SkillBridge</strong>
        <small>Digital Talent &amp; Outsourcing Academy</small>
      </span>
    </a>
  );
}

export function SiteHeader() {
  return (
    <header className="site-header">
      <div className="header-inner">
        <Brand />
        <nav className="main-nav" aria-label="Main navigation">
          <a href="/">Home</a>
          <a href="/about">About us</a>
          <a href="/programmes">Programmes</a>
          <a href="/team">Our team</a>
          <a href="/#student-hub">Student hub</a>
          <a href="/#news">News &amp; impact</a>
          <a href="/contact">Contact</a>
        </nav>
        <div className="auth-actions">
          <a className="button button-outline button-small" href={pwaUrl}>Register</a>
          <a className="button button-primary button-small" href={pwaUrl}>Login</a>
        </div>
        <details className="mobile-menu">
          <summary aria-label="Open navigation"><span></span><span></span><span></span></summary>
          <nav aria-label="Mobile navigation">
            <a href="/">Home</a><a href="/about">About us</a>
            <a href="/programmes">Programmes</a><a href="/team">Our team</a>
            <a href="/#student-hub">Student hub</a><a href="/#news">News &amp; impact</a>
            <a href="/contact">Contact</a>
            <a href={pwaUrl}>Register</a>
            <a href={pwaUrl}>Login</a>
          </nav>
        </details>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="footer-main section-wrap">
        <div className="footer-brand">
          <Brand />
          <p>Empowering young people in Ghana through accessible technology education, creativity and practical skills.</p>
          <div className="socials">
            <a href="/contact" aria-label="Facebook">f</a><a href="/contact" aria-label="Instagram">◎</a>
            <a href="/contact" aria-label="LinkedIn">in</a><a href="/contact" aria-label="YouTube">▶</a>
          </div>
        </div>
        <div><h4>Explore</h4><a href="/about">About us</a><a href="/programmes">Our programmes</a><a href="/team">Our team</a><a href="/#news">News &amp; impact</a></div>
        <div><h4>Get involved</h4><a href="/contact">Volunteer</a><a href="/contact">Partner with us</a><a href="/contact">Donate</a><a href="/contact">Support a school</a></div>
        <div><h4>Contact</h4><p>East Legon, Accra, Ghana</p><a href="mailto:support@skillsbridge.tech">support@skillsbridge.tech</a><a href="/contact">Visit us</a></div>
      </div>
      <div className="footer-bottom section-wrap">
        <span>© {new Date().getFullYear()} SkillBridge. All rights reserved.</span>
        <div><a href="/contact">Privacy</a><a href="/contact">Child safeguarding</a><a href="/contact">Terms</a></div>
        <b>LEARN TODAY. INNOVATE TOMORROW.</b>
      </div>
    </footer>
  );
}
