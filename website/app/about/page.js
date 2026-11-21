import { SiteFooter, SiteHeader } from "../../components/site-chrome";
import EnquiryButton from "../../components/enquiry-popup";

export const metadata = {
  title: "About SkillBridge | Learn Today. Innovate Tomorrow.",
  description: "Learn about SkillBridge's mission to make technology education more accessible to young people in Ghana."
};

export default function AboutPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <section className="inner-hero about-hero">
          <div className="inner-hero-content">
            <div className="eyebrow"><span />WHO WE ARE</div>
            <h1>Bridging young people to a world of <em>possibility.</em></h1>
            <p>We believe every child deserves the chance to learn, create and find their place in a digital future.</p>
            <EnquiryButton
              className="button button-green"
              enquiryType="Partnerships"
              title="Work with us"
              description="Tell us about your organisation and the kind of collaboration you have in mind."
            >
              Work with us <span className="arrow">↗</span>
            </EnquiryButton>
          </div>
        </section>
        <section className="inner-content section-wrap about-story">
          <div>
            <div className="eyebrow"><span />OUR PURPOSE</div>
            <h2>Opportunity should never depend on where you start.</h2>
          </div>
          <div className="inner-copy">
            <p>SkillBridge is a Ghana-focused technology education initiative working to make digital learning more accessible to children and young people. We pair practical, age-appropriate learning with the encouragement to ask questions, experiment and build.</p>
            <p>Our goal is to help close the digital divide by connecting young people with useful skills, welcoming learning communities and the confidence to imagine what comes next.</p>
          </div>
        </section>
        <section className="values-band">
          <div className="section-wrap values-grid">
            <article><span>01</span><h3>Access</h3><p>Make meaningful technology learning welcoming and reachable.</p></article>
            <article><span>02</span><h3>Creativity</h3><p>Learn by making, testing ideas and solving real problems.</p></article>
            <article><span>03</span><h3>Community</h3><p>Build progress through collaboration, mentorship and care.</p></article>
          </div>
        </section>
        <section className="inner-cta section-wrap">
          <div><div className="eyebrow"><span />MEET THE PEOPLE BEHIND THE WORK</div><h2>Good futures are built together.</h2></div>
          <a className="button button-primary" href="/team">Meet our team <span className="arrow">↗</span></a>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
