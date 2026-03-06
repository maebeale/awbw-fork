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

    // Merge search form values into the URL so they aren't lost on navigation
    if (collectionForm) {
      const formData = new FormData(collectionForm);
      for (const [key, val] of formData.entries()) {
        if (!url.searchParams.has(key) && val !== "") {
          url.searchParams.set(key, val);
        }
      }
    }

    if (param === "audience" && value) {
      const defaults = ["visitors", "users"];
      const current = url.searchParams.has("audience[]")
        ? url.searchParams.getAll("audience[]")
        : defaults;
      const remaining = current.filter((v) => v !== value);
      url.searchParams.delete("audience[]");
      remaining.forEach((v) => url.searchParams.append("audience[]", v));
    } else if (param === "time_period") {
      const current = url.searchParams.get("time_period") || "past_month";
      url.searchParams.set(
        "time_period",
        current === "all_time" ? "past_month" : "all_time",
      );
    } else {
      url.searchParams.delete(param);
    }
    window.location = url.toString();
  }
}
