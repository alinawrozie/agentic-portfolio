// ---------------------------------------------------------
// CONFIG — API Gateway endpoint for contact form:
// ---------------------------------------------------------
const API_ENDPOINT = "https://7n4e7a8tdk.execute-api.eu-west-2.amazonaws.com/contact";

// ---------------------------------------------------------
// Footer year auto-update
// ---------------------------------------------------------
const yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = new Date().getFullYear();
}

// ---------------------------------------------------------
// AWS Architecture Diagram — Node Inspector
// ---------------------------------------------------------
const inspectorIcon = document.getElementById("inspector-icon");
const inspectorTitle = document.getElementById("inspector-title");
const inspectorBody = document.getElementById("inspector-body");

const defaultInspector = {
  icon: "💻",
  title: "Client Browser (You)",
  body: "Hover or click any architectural node above to inspect its exact role, security policies, and AWS service configuration."
};

const archNodes = document.querySelectorAll(".arch-node");

archNodes.forEach((node) => {
  const updateInspector = () => {
    archNodes.forEach(n => n.classList.remove("active"));
    node.classList.add("active");
    
    if (inspectorIcon) inspectorIcon.textContent = node.dataset.icon || "⚡";
    if (inspectorTitle) inspectorTitle.textContent = node.dataset.title || "AWS Node";
    if (inspectorBody) inspectorBody.textContent = node.dataset.body || "";
  };

  node.addEventListener("mouseenter", updateInspector);
  node.addEventListener("focus", updateInspector);
  node.addEventListener("click", updateInspector);

  node.addEventListener("mouseleave", () => {
    // Retain node active state if clicked, or reset to default
  });
});

// ---------------------------------------------------------
// Projects Category Filter
// ---------------------------------------------------------
const filterBtns = document.querySelectorAll(".filter-btn");
const projectCards = document.querySelectorAll(".project-card");

filterBtns.forEach(btn => {
  btn.addEventListener("click", () => {
    filterBtns.forEach(b => b.classList.remove("active"));
    btn.classList.add("active");

    const filter = btn.dataset.filter;

    projectCards.forEach(card => {
      if (filter === "all" || card.dataset.category === filter) {
        card.classList.remove("hidden");
      } else {
        card.classList.add("hidden");
      }
    });
  });
});

// ---------------------------------------------------------
// Contact Form Submission (POST to API Gateway -> Lambda -> SES)
// ---------------------------------------------------------
const form = document.getElementById("contact-form");
const submitButton = document.getElementById("contact-submit");
const statusEl = document.getElementById("contact-status");

function setFormState(state, message) {
  if (!statusEl) return;
  statusEl.className = "form-status status--" + state;
  statusEl.textContent = message || "";
}

if (form) {
  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (API_ENDPOINT.includes("REPLACE_WITH")) {
      setFormState("error", "API Gateway endpoint not configured yet.");
      return;
    }

    const payload = {
      name: form.name.value.trim(),
      email: form.email.value.trim(),
      message: form.message.value.trim(),
    };

    if (!payload.name || !payload.email || !payload.message) {
      setFormState("error", "Please fill in all required fields before transmitting.");
      return;
    }

    submitButton.disabled = true;
    setFormState("sending", "Transmitting message to AWS Lambda serverless handler…");

    try {
      const response = await fetch(API_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        throw new Error("API returned status " + response.status);
      }

      setFormState("success", "✓ Message transmitted successfully! I will reply to your email shortly.");
      form.reset();
    } catch (err) {
      console.error(err);
      setFormState("error", "✕ Transmission failed. Please try again or reach out via LinkedIn/GitHub.");
    } finally {
      submitButton.disabled = false;
    }
  });
}

// ---------------------------------------------------------
// Mobile Navbar Toggle
// ---------------------------------------------------------
const navToggle = document.getElementById("navToggle");
const navMenu = document.getElementById("navMenu");

if (navToggle && navMenu) {
  navToggle.addEventListener("click", () => {
    const isOpen = navMenu.classList.toggle("open");
    navToggle.setAttribute("aria-expanded", String(isOpen));
  });

  // Close the menu after a link is tapped
  navMenu.querySelectorAll(".nav-link").forEach((link) => {
    link.addEventListener("click", () => {
      navMenu.classList.remove("open");
      navToggle.setAttribute("aria-expanded", "false");
    });
  });
}

// ---------------------------------------------------------
// Navbar Active Spy on Scroll
// ---------------------------------------------------------
const navLinks = document.querySelectorAll(".nav-link");
const sections = document.querySelectorAll("section[id]");

window.addEventListener("scroll", () => {
  let current = "";
  sections.forEach(section => {
    const sectionTop = section.offsetTop - 100;
    if (window.scrollY >= sectionTop) {
      current = section.getAttribute("id");
    }
  });

  navLinks.forEach(link => {
    link.classList.remove("active");
    if (link.getAttribute("href") === `#${current}`) {
      link.classList.add("active");
    }
  });
});
