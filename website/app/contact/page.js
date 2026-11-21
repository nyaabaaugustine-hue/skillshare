import { SiteFooter, SiteHeader } from "../../components/site-chrome";
import EnquiryButton from "../../components/enquiry-popup";

export const metadata = {
  title: "Contact | SkillBridge",
  description: "Get in touch with SkillBridge about programmes, partnerships and volunteering."
};

export default function ContactPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <section className="inner-hero contact-hero">
          <div className="inner-hero-content">
            <div className="eyebrow"><span />LET’S CONNECT</div>
            <h1>Let’s open more doors <em>together.</em></h1>
            <p>Ask us about programmes, volunteering, partnerships or bringing technology learning to your community.</p>
            <EnquiryButton
              className="button button-green"
              enquiryType="General enquiry"
              title="Email our team"
              description="Send us a message about programmes, volunteering, partnerships or bringing technology learning to your community."
            >
              Email our team <span className="arrow">↗</span>
            </EnquiryButton>
          </div>
        </section>
        <section className="inner-content section-wrap contact-page-content">
          <div className="contact-details">
            <div className="eyebrow"><span />SAY HELLO</div>
            <h2>We’d love to hear from you.</h2>
            <p>Start a conversation with our team and tell us how you would like to get involved.</p>
            <a className="contact-detail" href="mailto:support@skillsbridge.tech"><span className="contact-detail-icon">✉</span><span><small>EMAIL</small><b>support@skillsbridge.tech</b></span></a>
            <div className="contact-detail"><span className="contact-detail-icon">⌖</span><span><small>HEADQUARTERS · GHANA</small><b>East Legon, Accra</b></span></div>
            <a className="button button-primary" href="https://www.google.com/maps/search/?api=1&query=East%20Legon%2C%20Accra" target="_blank" rel="noreferrer">Open in Google Maps <span className="arrow">↗</span></a>
          </div>
          <div className="map-frame">
            <iframe
              title="SkillBridge headquarters area in East Legon, Accra, Ghana"
              src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d31764.227970961805!2d-0.17891519465508338!3d5.636380888057941!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0xfdf9b501278f4a5%3A0xca081548a0c20ffd!2sEast%20Legon%2C%20Accra!5e0!3m2!1sen!2sgh!4v1795202672969!5m2!1sen!2sgh"
              loading="lazy"
              referrerPolicy="strict-origin-when-cross-origin"
              allowFullScreen
            />
            <div className="map-caption"><span className="map-pin">⌖</span><span><b>East Legon, Accra</b><small>SkillBridge headquarters · Ghana</small></span></div>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
