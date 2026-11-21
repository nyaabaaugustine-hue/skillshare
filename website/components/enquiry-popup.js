"use client";

import { useCallback, useEffect, useId, useRef, useState } from "react";

const TYPES = [
  "General enquiry",
  "Programmes and courses",
  "Volunteering",
  "Partnerships",
  "School registration",
  "Donations and support",
];

/**
 * A contact CTA that opens an animated enquiry popup instead of leaving the
 * page. The form posts to /api/contact, which forwards to the project's
 * Formspree form so the team keeps the same inbox notifications.
 */
export default function EnquiryButton({
  children,
  className = "",
  enquiryType = "General enquiry",
  title = "Start a conversation",
  description = "Share a few details and what you have in mind. We usually reply within two working days.",
  programme = "",
}) {
  const [mounted, setMounted] = useState(false);
  const [visible, setVisible] = useState(false);
  const [status, setStatus] = useState("idle");
  const [error, setError] = useState("");

  const triggerRef = useRef(null);
  const dialogRef = useRef(null);
  const firstFieldRef = useRef(null);
  const headingId = useId();
  const formId = useId();

  const close = useCallback(() => {
    setVisible(false);
    window.setTimeout(() => {
      setMounted(false);
      setStatus("idle");
      setError("");
      triggerRef.current?.focus();
    }, 240);
  }, []);

  useEffect(() => {
    if (!mounted) return undefined;

    // A short timer rather than requestAnimationFrame: rAF can be paused in a
    // background tab, which would mount the dialog without its visible class
    // and leave it stuck at opacity 0.
    const frame = window.setTimeout(() => setVisible(true), 20);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const focusTimer = window.setTimeout(() => firstFieldRef.current?.focus(), 90);

    const onKeyDown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        close();
        return;
      }
      if (event.key !== "Tab" || !dialogRef.current) return;
      const focusable = dialogRef.current.querySelectorAll(
        'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])',
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", onKeyDown);
    return () => {
      window.clearTimeout(frame);
      window.clearTimeout(focusTimer);
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [mounted, close]);

  const submit = async (event) => {
    event.preventDefault();
    if (status === "sending") return;

    setStatus("sending");
    setError("");
    try {
      const response = await fetch("/api/contact", {
        method: "POST",
        headers: { accept: "application/json" },
        body: new FormData(event.currentTarget),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data?.error ?? "send failed");
      setStatus("sent");
    } catch {
      setStatus("error");
      setError(
        "That did not send. Check your details and try again, or email support@skillsbridge.tech.",
      );
    }
  };

  return (
    <>
      <button
        type="button"
        ref={triggerRef}
        className={`enquiry-trigger ${className}`.trim()}
        aria-haspopup="dialog"
        aria-expanded={mounted}
        onClick={() => setMounted(true)}
      >
        {children}
      </button>

      {mounted ? (
        <div
          className={`enquiry-modal${visible ? " is-visible" : ""}`}
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) close();
          }}
        >
          <div
            ref={dialogRef}
            className="enquiry-dialog"
            role="dialog"
            aria-modal="true"
            aria-labelledby={headingId}
          >
            <button type="button" className="enquiry-close" onClick={close} aria-label="Close form">
              ×
            </button>

            {status === "sent" ? (
              <div className="enquiry-sent" role="status">
                <span className="enquiry-tick" aria-hidden="true">✓</span>
                <h2 id={headingId}>Thank you — your message is on its way.</h2>
                <p>
                  Our team has your details and will reply by email. For anything urgent, write to
                  support@skillsbridge.tech.
                </p>
                <button type="button" className="button button-primary" onClick={close}>
                  Close
                </button>
              </div>
            ) : (
              <>
                <div className="eyebrow"><span />LET’S CONNECT</div>
                <h2 id={headingId}>{title}</h2>
                <p className="enquiry-intro">{description}</p>

                <form className="school-form enquiry-form" onSubmit={submit} noValidate={false}>
                  <div className="form-field">
                    <label htmlFor={`${formId}-name`}>Your name</label>
                    <input
                      id={`${formId}-name`}
                      ref={firstFieldRef}
                      name="name"
                      autoComplete="name"
                      required
                      maxLength={160}
                    />
                  </div>
                  <div className="form-field">
                    <label htmlFor={`${formId}-email`}>Email</label>
                    <input
                      id={`${formId}-email`}
                      name="email"
                      type="email"
                      autoComplete="email"
                      required
                      maxLength={200}
                    />
                  </div>
                  <div className="form-field">
                    <label htmlFor={`${formId}-phone`}>Phone (optional)</label>
                    <input
                      id={`${formId}-phone`}
                      name="phone"
                      type="tel"
                      autoComplete="tel"
                      maxLength={60}
                    />
                  </div>
                  <div className="form-field">
                    <label htmlFor={`${formId}-type`}>Type of enquiry</label>
                    <select id={`${formId}-type`} name="enquiry_type" defaultValue={enquiryType}>
                      {TYPES.map((type) => (
                        <option key={type} value={type}>{type}</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-field form-field-wide">
                    <label htmlFor={`${formId}-message`}>How can we help?</label>
                    <textarea
                      id={`${formId}-message`}
                      name="message"
                      rows={3}
                      maxLength={2000}
                      defaultValue={
                        programme
                          ? `I would like to know more about the ${programme} pathway.`
                          : ""
                      }
                    />
                  </div>

                  {programme ? (
                    <input type="hidden" name="programme" value={programme} />
                  ) : null}

                  {status === "error" ? (
                    <p className="form-note form-note-error form-field-wide" role="alert">
                      {error}
                    </p>
                  ) : null}

                  <div className="form-field-wide enquiry-actions">
                    <button
                      type="submit"
                      className="button button-primary"
                      disabled={status === "sending"}
                    >
                      {status === "sending" ? "Sending…" : "Send enquiry"}
                    </button>
                    <small>We only use these details to reply to you.</small>
                  </div>
                </form>
              </>
            )}
          </div>
        </div>
      ) : null}
    </>
  );
}
