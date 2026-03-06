import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="checkbox-select"
// Updates a label from checked checkboxes and optionally submits the parent form.
export default class extends Controller {
  static targets = ["label"];
  static values = {
    labels: Object,
    fieldName: String,
    allLabel: { type: String, default: "All" },
    autoSubmit: { type: Boolean, default: true }
  };

  update() {
    const name = this.fieldNameValue || "audience[]";
    const checkboxes = this.element.querySelectorAll(
      `input[name="${name}"]`,
    );
    const checked = [...checkboxes]
      .filter((c) => c.checked)
      .map((c) => this.labelsValue[c.value]);
    const total = Object.keys(this.labelsValue).length;

    this.labelTarget.textContent =
      checked.length === total ? this.allLabelValue : checked.join(", ");

    if (this.autoSubmitValue) {
      const form = this.element.closest("form");
      if (form) form.requestSubmit();
    }
  }
}
