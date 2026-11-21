/* eslint-disable @next/next/no-img-element */

import { SiteFooter, SiteHeader } from "../../components/site-chrome";
import EnquiryButton from "../../components/enquiry-popup";
import team from "../../components/team-data";

export const metadata = {
  title: "Our Team | SkillBridge",
  description: "Meet the people and expertise that help SkillBridge make technology learning accessible."
};

export default function TeamPage() {
  return (
    <>
      <SiteHeader />
      <main>
        <section className="inner-hero team-hero">
          <div className="inner-hero-content">
            <div className="eyebrow"><span />THE PEOPLE BEHIND THE POSSIBILITY</div>
            <h1>Meet the team building <em>what’s next.</em></h1>
            <p>Educators, community builders and advocates for a more inclusive digital future.</p>
            <EnquiryButton
              className="button button-green"
              enquiryType="General enquiry"
              title="Connect with our team"
              description="Send us a note and the right person on the team will get back to you."
            >
              Connect with our team <span className="arrow">↗</span>
            </EnquiryButton>
          </div>
        </section>
        <section className="inner-content section-wrap team-section">
          <div className="inner-section-heading team-heading">
            <div className="eyebrow"><span />OUR PEOPLE</div>
            <h2>Different strengths. One shared purpose.</h2>
            <p>Stephen’s name and portrait are supplied. Other profile details and biographies remain sample content and should be confirmed with the team.</p>
          </div>
          <div className="team-grid">
            {team.map((member, index) => (
              <article className="team-card" key={member.name}>
                <div className="team-photo-wrap">
                  <img src={member.image} alt={`Sample portrait for ${member.role}`} className="team-photo" />
                  <span className="team-number">0{index + 1}</span>
                </div>
                <div className="team-card-content">
                  <span className="team-focus">{member.focus}</span>
                  <h3>{member.name}</h3>
                  <p className="team-role">{member.role}</p>
                  <p className="team-bio">{member.bio}</p>
                  <EnquiryButton
                    className="enquiry-plain enquiry-card-link"
                    enquiryType="General enquiry"
                    title={`Connect with SkillBridge`}
                    description={`Tell us what you would like to discuss about the ${member.role} role.`}
                  >
                    Connect with SkillBridge <span className="arrow">↗</span>
                  </EnquiryButton>
                </div>
              </article>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
