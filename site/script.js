// ---------------------------------------------------------
// CONFIG — replace after `terraform apply`:
//   terraform output api_endpoint
// e.g. "https://abc123xyz.execute-api.eu-west-2.amazonaws.com/contact"
// ---------------------------------------------------------
const API_ENDPOINT = "REPLACE_WITH_TERRAFORM_OUTPUT_api_endpoint";

// ---------------------------------------------------------
// Footer year
// ---------------------------------------------------------
document.getElementById("year").textContent = new Date().getFullYear();

// ---------------------------------------------------------
// Architecture diagram — hover/focus reveals what each
// node does, for both mouse and keyboard users.
// ---------------------------------------------------------
const infoTitle = document.querySelector(".diagram__info-title");
const infoBody = document.querySelector(".diagram__info-body");
const defaultTitle = infoTitle ? infoTitle.textContent : "";
const defaultBody = infoBody ? infoBody.textContent : "";

document.querySelectorAll(".node").forEach((node) => {
  const show = () => {
    infoTitle.textContent = node.dataset.title + " — ";
    infoBody.textContent = node.dataset.body;
  };
  const reset = () => {
    infoTitle.textContent = defaultTitle;
    infoBody.textContent = defaultBody;
  };
  node.addEventListener("mouseenter", show);
  node.addEventListener("focus", show);
  node.addEventListener("mouseleave", reset);
  node.addEventListener("blur", reset);
});

// ---------------------------------------------------------
// Contact form — POSTs to the API Gateway HTTP API, which
// proxies to Lambda, which calls SES. See lambda/contact_form.
// ---------------------------------------------------------
const form = document.getElementById("contact-form");
const submitButton = document.getElementById("contact-submit");
const statusEl = document.getElementById("contact-status");
const statusDot = submitButton.querySelector(".status-dot");

function setState(state, message) {
  statusDot.className = "status-dot status-dot--" + state;
  statusEl.textContent = message || "";
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  if (API_ENDPOINT.startsWith("REPLACE_WITH")) {
    setState("error", "API endpoint not configured yet — see script.js.");
    return;
  }

  const payload = {
    name: form.name.value.trim(),
    email: form.email.value.trim(),
    message: form.message.value.trim(),
  };

  if (!payload.name || !payload.email || !payload.message) {
    setState("error", "Fill in every field before sending.");
    return;
  }

  submitButton.disabled = true;
  setState("sending", "Sending…");

  try {
    const response = await fetch(API_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      throw new Error("Request failed with status " + response.status);
    }

    setState("success", "Sent. I'll reply by email shortly.");
    form.reset();
  } catch (err) {
    setState("error", "Something went wrong — try again, or email me directly.");
  } finally {
    submitButton.disabled = false;
  }
});
