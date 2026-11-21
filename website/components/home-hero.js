"use client";

import { useEffect, useState } from "react";

const slides = [
  {
    kicker: "A brighter digital future starts here",
    title: <>Empowering Ghana’s next generation <em>through technology.</em></>,
    description: "We equip children aged 7–16 with digital skills, coding, robotics and the confidence to build a brighter future.",
    image: "https://res.cloudinary.com/z43ds8bn/image/upload/v1795200962/WhatsApp_Image_2026-11-17_at_3.11.34_AM.jpg",
    alt: "SkillBridge Academy learners",
    caption: "LEARN. CREATE. INNOVATE."
  },
  {
    kicker: "Curiosity becomes capability",
    title: <>Make room for <em>big ideas.</em></>,
    description: "From first lines of code to hands-on robotics, young creators learn by making, testing and sharing.",
    image: "https://images.unsplash.com/photo-1588072432836-e10032774350?auto=format&fit=crop&w=2000&q=88",
    alt: "Students learning together in a classroom",
    caption: "EXPLORE. BUILD. GROW."
  },
  {
    kicker: "Opportunity belongs to everyone",
    title: <>Build skills for a <em>brighter tomorrow.</em></>,
    description: "Join a community opening doors to practical digital learning for children and young people across Ghana.",
    image: "https://images.unsplash.com/photo-1529390079861-591de354faf5?auto=format&fit=crop&w=2000&q=88",
    alt: "A group of students working together",
    caption: "LEARN TODAY. LEAD TOMORROW."
  }
];

export default function HomeHero() {
  const [active, setActive] = useState(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused) return undefined;
    const timer = window.setInterval(() => {
      setActive((current) => (current + 1) % slides.length);
    }, 6000);
    return () => window.clearInterval(timer);
  }, [paused]);

  const slide = slides[active];
  const showSlide = (index) => setActive((index + slides.length) % slides.length);

  return (
    <section
      className="hero"
      id="home"
      aria-roledescription="carousel"
      aria-label="SkillBridge highlights"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocus={() => setPaused(true)}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) setPaused(false);
      }}
    >
      <div
        className="hero-photo"
        style={{ backgroundImage: `linear-gradient(90deg,rgba(4,27,67,.98) 0%,rgba(4,35,82,.91) 34%,rgba(4,35,82,.34) 59%,rgba(4,35,82,.04) 100%),url("${slide.image}")` }}
      >
        <span className="sr-only">{slide.alt}</span>
        <div className="photo-overlay" />
        <div className="hero-content" aria-live="polite">
          <div className="hero-kicker"><span className="kicker-line" />{slide.kicker}</div>
          <h1>{slide.title}</h1>
          <p>{slide.description}</p>
          <div className="hero-actions">
            <a className="button button-green" href="/programmes">Explore programmes <span aria-hidden="true" className="arrow">↗</span></a>
            <a className="button button-glass" href="/contact">Become a volunteer</a>
          </div>
          <div className="hero-note"><span className="note-dot" /> Learning today. Leading tomorrow.</div>
        </div>
        <div className="hero-caption">{slide.caption}</div>
        <div className="hero-controls" aria-label="Choose a highlight">
          <button type="button" className="hero-arrow" aria-label="Previous slide" onClick={() => showSlide(active - 1)}>←</button>
          {slides.map((item, index) => (
            <button
              type="button"
              key={item.kicker}
              className={`hero-dot${index === active ? " is-active" : ""}`}
              aria-label={`Show slide ${index + 1}`}
              aria-current={index === active ? "true" : undefined}
              onClick={() => showSlide(index)}
            />
          ))}
          <button type="button" className="hero-arrow" aria-label="Next slide" onClick={() => showSlide(active + 1)}>→</button>
        </div>
      </div>
    </section>
  );
}
