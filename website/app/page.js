/* eslint-disable @next/next/no-img-element */

import { SiteFooter, SiteHeader } from "../components/site-chrome";
import HomeHero from "../components/home-hero";
import team from "../components/team-data";

const programmes = [
  {
    age: "AGES 7–9",
    title: "Young Explorers",
    subtitle: "Discover the digital world",
    description: "Build confidence with computers, creative thinking and playful introductions to technology.",
    className: "green",
    icon: "✦",
    topics: ["Digital literacy", "Creative computing", "Beginner robotics"]
  },
  {
    age: "AGES 10–13",
    title: "Digital Creators",
    subtitle: "Turn ideas into projects",
    description: "Explore coding, websites and hands-on electronics while learning to solve real problems.",
    className: "blue",
    icon: "</>",
    topics: ["Scratch and Python", "Web foundations", "Robotics projects"]
  },
  {
    age: "AGES 14–16",
    title: "Future Innovators",
    subtitle: "Create what comes next",
    description: "Develop practical skills in programming, AI, IoT and innovation through guided projects.",
    className: "purple",
    icon: "⌘",
    topics: ["Python programming", "AI and IoT basics", "Innovation challenges"]
  }
];

const involvement = [
  { icon: "♧", title: "Volunteer", text: "Share your time and skills." },
  { icon: "⇄", title: "Partner", text: "Bring technology learning to more communities." },
  { icon: "♡", title: "Donate", text: "Help provide tools and learning opportunities." },
  { icon: "⌂", title: "Support a school", text: "Help a school start its digital journey." }
];

function Arrow() {
  return <span aria-hidden="true" className="arrow">↗</span>;
}

function SectionEyebrow({ children }) {
  return <div className="eyebrow"><span />{children}</div>;
}

export default function Home() {
  return (
    <main>
      <SiteHeader />
      <HomeHero />

    <section className="about-section" id="about">
      <div className="about-image">
        <div className="image-label"><span>SKILLBRIDGE</span><small>Technology for possibility</small></div>
      </div>
      <div className="about-copy">
        <SectionEyebrow>WHO WE ARE</SectionEyebrow>
        <h2>Opening doors to a world of <span>possibilities.</span></h2>
        <p>SkillBridge is a Ghana-focused technology education initiative working to make digital learning more accessible to children and young people. We believe a child’s background should never determine their opportunity to learn, create and innovate.</p>
        <a className="button button-primary" href="/about">Learn about our mission <Arrow /></a>
      </div>
      <aside className="mission-card">
        <span className="mission-icon">◎</span>
        <SectionEyebrow>OUR MISSION</SectionEyebrow>
        <h3>Bridge the digital divide.</h3>
        <p>Connect young people with the knowledge, tools and mentors they need to participate in a technology-driven world.</p>
        <a href="#get-involved">How you can help <Arrow /></a>
      </aside>
    </section>

      <section className="impact-strip" aria-label="Our impact">
        <div><strong>01</strong><span><b>Children reached</b><small>Growing digital confidence</small></span></div>
        <div><strong>02</strong><span><b>Schools supported</b><small>Bringing learning closer</small></span></div>
        <div><strong>03</strong><span><b>Tech workshops</b><small>Learning by doing</small></span></div>
        <div><strong>04</strong><span><b>Student projects</b><small>Ideas made real</small></span></div>
      </section>

      <section className="programmes section-wrap" id="programmes">
        <div className="section-intro">
          <SectionEyebrow>OUR PROGRAMMES</SectionEyebrow>
          <h2>Technology learning for <span>every stage.</span></h2>
          <p>Every child has a different starting point. Our age-based pathways make technology approachable, practical and exciting.</p>
          <a className="text-link" href="/programmes">Discover all programmes <Arrow /></a>
        </div>
        <div className="programme-grid">
          {programmes.map((item) => (
            <article className={`programme-card ${item.className}`} key={item.title}>
              <div className="programme-top"><span>{item.age}</span><b>{item.icon}</b></div>
              <div className="programme-body">
                <h3>{item.title}</h3>
                <strong>{item.subtitle}</strong>
                <p>{item.description}</p>
                <ul>{item.topics.map((topic) => <li key={topic}>{topic}</li>)}</ul>
                <a href="#contact" className="card-link">Explore pathway <Arrow /></a>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="video-section">
        <div className="section-wrap">
          <div className="video-heading">
            <SectionEyebrow>INNOVATION IN ACTION</SectionEyebrow>
            <div>
              <h2>See young learners bring ideas to life.</h2>
              <p>Explore the creativity and curiosity behind hands-on technology learning.</p>
            </div>
          </div>
          <div className="video-frame">
            <video controls playsInline preload="metadata" aria-label="A young learner interacting with a robot">
              <source src="https://res.cloudinary.com/dx1nrew3h/video/upload/v1794568662/www.magnific.com_boy-interacting-with-a-robot-premium-stock-video-footage_fucjby.mp4" type="video/mp4" />
              Your browser does not support embedded video.
            </video>
          </div>
        </div>
      </section>

      <section className="student-hub section-wrap" id="student-hub">
        <div className="hub-copy">
          <SectionEyebrow>STUDENT INNOVATION HUB</SectionEyebrow>
          <h2>Big ideas can start <span>small.</span></h2>
          <p>Give young creators a place to explore technology, share projects and celebrate what they have built.</p>
          <a className="button button-outline" href="#contact">Explore student projects <Arrow /></a>
        </div>
        <div className="student-showcase">
          <div className="project-tiles">
            <div className="project-tile tile-one"><span>01 / ROBOTICS</span><b>Build. Test. Improve.</b></div>
            <div className="project-tile tile-two"><span>02 / CODING</span><b>Turn logic into ideas.</b></div>
            <div className="project-tile tile-three"><span>03 / CREATIVITY</span><b>Imagine what’s possible.</b></div>
          </div>
          <div className="phone-stage" aria-label="Phone preview placeholder for the app screenshot">
            <div className="phone-device">
              <div className="phone-speaker" />
              <div className="phone-screen">
                <img
                  className="phone-screenshot"
                  src="https://res.cloudinary.com/dx1nrew3h/image/upload/v1795204092/SkillBridge_Academy_Learning_Journey_e0qydt.png"
                  alt="SkillBridge Academy learning journey app preview"
                />
              </div>
              <div className="phone-home-indicator" />
            </div>
            <span className="phone-caption">SKILLBRIDGE APP PREVIEW</span>
          </div>
        </div>
      </section>

      <section className="home-team">
        <div className="section-wrap">
          <div className="home-team-heading">
            <div>
              <SectionEyebrow>THE PEOPLE BEHIND THE POSSIBILITY</SectionEyebrow>
              <h2>Meet the team building <span>what’s next.</span></h2>
            </div>
            <a className="text-link" href="/team">Meet the full team <Arrow /></a>
          </div>
          <p className="profile-disclaimer">Stephen’s name and portrait are supplied; other profile details and biographies are sample content.</p>
          <div className="team-grid home-team-grid">
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
                  <a href="/team">Meet the team <Arrow /></a>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="school-registration-section" id="school-registration">
        <div className="section-wrap school-registration-grid">
          <div className="registration-image">
            <img src="https://images.unsplash.com/photo-1588072432836-e10032774350?auto=format&fit=crop&w=1200&q=85" alt="Students learning together in a classroom" />
            <div className="registration-image-copy">
              <span>FOR SCHOOLS &amp; EDUCATORS</span>
              <h2>Bring new possibilities into your classroom.</h2>
              <p>Tell us about your school and we’ll get in touch about the next steps.</p>
            </div>
          </div>
          <div className="registration-form-panel">
            <SectionEyebrow>START A SCHOOL ENQUIRY</SectionEyebrow>
            <h2>Register your school</h2>
            <p>Share a few details so our team can learn how to support your students.</p>
            <form
              className="school-form"
              action="https://formspree.io/f/maeodqly"
              method="post"
              aria-label="School registration enquiry"
            >
              <input type="hidden" name="_subject" value="School registration enquiry - SkillBridge" />
              <div className="form-field">
                <label htmlFor="school-name">School name</label>
                <input id="school-name" name="school_name" autoComplete="organization" required />
              </div>
              <div className="form-field">
                <label htmlFor="school-location">School location</label>
                <input id="school-location" name="school_location" placeholder="Town or district" required />
              </div>
              <div className="form-field">
                <label htmlFor="contact-name">Your name</label>
                <input id="contact-name" name="contact_name" autoComplete="name" required />
              </div>
              <div className="form-field">
                <label htmlFor="contact-email">Work email</label>
                <input id="contact-email" name="email" type="email" autoComplete="email" required />
              </div>
              <div className="form-field">
                <label htmlFor="contact-phone">Phone number</label>
                <input id="contact-phone" name="phone" type="tel" autoComplete="tel" />
              </div>
              <div className="form-field">
                <label htmlFor="learner-count">Learners to register</label>
                <select id="learner-count" name="learner_count" defaultValue="" required>
                  <option value="" disabled>Select an estimate</option>
                  <option>1–25</option>
                  <option>26–50</option>
                  <option>51–100</option>
                  <option>100+</option>
                </select>
              </div>
              <div className="form-field form-field-wide">
                <label htmlFor="programme-interest">Programme of interest</label>
                <select id="programme-interest" name="programme_interest" defaultValue="Digital skills and coding">
                  <option>Digital skills and coding</option>
                  <option>Robotics and innovation</option>
                  <option>School partnership</option>
                  <option>Not sure yet</option>
                </select>
              </div>
              <div className="form-field form-field-wide">
                <label htmlFor="school-message">Anything else we should know?</label>
                <textarea id="school-message" name="message" rows="3" />
              </div>
              <div className="form-field-wide">
                <button className="button button-primary school-submit" type="submit">Submit school enquiry <span aria-hidden="true" className="arrow">↗</span></button>
                <p className="form-note">
                  Your enquiry will be sent to our team. For help, contact{" "}
                  <a href="mailto:support@skillbridge.tech">support@skillbridge.tech</a>.
                </p>
              </div>
            </form>
          </div>
        </div>
      </section>

      <section className="get-involved-section" id="get-involved">
        <div className="section-wrap involved-inner">
          <div className="involved-heading">
            <SectionEyebrow>BE PART OF THE CHANGE</SectionEyebrow>
            <h2>Help build Ghana’s <span>digital future.</span></h2>
            <p>It takes a community to open opportunities. Your time, support or partnership can help a child take their next step.</p>
          </div>
          <div className="involved-grid">
            {involvement.map((item) => (
              <a href="#contact" className="involved-card" key={item.title}>
                <span className="involved-icon">{item.icon}</span><b>{item.title}</b><small>{item.text}</small><Arrow />
              </a>
            ))}
          </div>
        </div>
      </section>

      <section className="news-section section-wrap" id="news">
        <div>
          <SectionEyebrow>STORIES FROM OUR COMMUNITY</SectionEyebrow>
          <h2>Our <span>News Stories.</span></h2>
        </div>
        <div className="news-placeholder">
          <img
            className="news-image"
            src="https://res.cloudinary.com/dx1nrew3h/image/upload/v1794785382/child-surfing-internet-tablet-computer_342744-389_e16uvq.avif"
            alt="A young person using a tablet to explore digital learning"
          />
          <div className="news-date">SKILLBRIDGE JOURNAL</div>
          <h3>Every young person deserves the chance to create with technology.</h3>
          <p>Follow our programmes, community activities and the ideas young people are bringing to life.</p>
          <a className="text-link" href="#contact">Connect with us <Arrow /></a>
        </div>
      </section>

      <section className="contact-band" id="contact">
        <div className="section-wrap contact-inner">
          <div><SectionEyebrow>LET’S MAKE IT POSSIBLE</SectionEyebrow><h2>Bring technology learning to more children.</h2></div>
          <a className="button button-green" href="mailto:hello@skillbridge.org">Start a conversation <Arrow /></a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
