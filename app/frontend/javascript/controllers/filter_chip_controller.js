import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="filter-chip"
// Dismisses filter chips by clearing the matching input in the collection
// form (for search params) or navigating to a modified URL (for header params).
export default class extends Controller {
  remove(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const param = button.dataset.param;
    const value = button.dataset.value;

    const collectionForm = document.querySelector(
      '[data-controller="collection"]',
    );

    // Search params: clear input in collection form and re-submit
    if (collectionForm && param !== "audience" && param !== "time_period") {
      const input = collectionForm.querySelector(`[name="${param}"]`);
      if (input) {
        if (input.tagName === "SELECT") {
          input.selectedIndex = 0;
        } else {
          input.value = "";
        }
        collectionForm.requestSubmit();
        return;
      }
    }

    // Header-level params (audience, time_period): rebuild URL and navigate
    const url = new URL(window.location);
    if (param === "audience" && value) {
      const remaining = url.searchParams
        .getAll("audience[]")
        .filter((v) => v !== value);
      url.searchParams.delete("audience[]");
      remaining.forEach((v) => url.searchParams.append("audience[]", v));
    } else {
      url.searchParams.delete(param);
    }
    window.location = url.toString();
  }
}
