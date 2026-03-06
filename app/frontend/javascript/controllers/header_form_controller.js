import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="header-form"
// Merges search form (collection controller) values into the header form
// before submitting, so search filters aren't lost when changing audience
// or time period.
export default class extends Controller {
  submit() {
    const collectionForm = document.querySelector(
      '[data-controller="collection"]',
    );

    if (collectionForm) {
      // Remove any previously injected hidden fields
      this.element
        .querySelectorAll("input[data-header-form-injected]")
        .forEach((el) => el.remove());

      const formData = new FormData(collectionForm);
      for (const [key, val] of formData.entries()) {
        // Skip params already handled by the header form (audience, time_period)
        if (key === "audience[]" || key === "time_period") continue;
        if (val === "") continue;

        const hidden = document.createElement("input");
        hidden.type = "hidden";
        hidden.name = key;
        hidden.value = val;
        hidden.setAttribute("data-header-form-injected", "true");
        this.element.appendChild(hidden);
      }
    }

    this.element.requestSubmit();
  }
}
