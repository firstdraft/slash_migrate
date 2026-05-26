// Self-contained Stimulus controllers for the engine. Loaded as a plain script
// after the vendored Stimulus + Turbo UMD builds, so it relies only on the
// `Stimulus` and `Turbo` globals — no bundler, importmap, or host JS.
(function () {
  "use strict";

  var application = Stimulus.Application.start();

  // Drives the "new model" form: add/remove column rows and stream a live
  // preview of the migration the form would generate.
  var ModelFormController = class extends Stimulus.Controller {
    static targets = ["rows", "template", "preview"];
    static values = { previewUrl: String };

    connect() {
      this.timer = null;
      this.refresh();
    }

    addRow() {
      this.rowsTarget.appendChild(this.templateTarget.content.cloneNode(true));
      this.refresh();
    }

    removeRow(event) {
      var row = event.target.closest("[data-row]");
      if (row) row.remove();
      this.refresh();
    }

    // Debounced so we don't fire a request on every keystroke.
    scheduleRefresh() {
      clearTimeout(this.timer);
      this.timer = setTimeout(() => this.refresh(), 300);
    }

    refresh() {
      fetch(this.previewUrlValue, {
        method: "POST",
        body: new FormData(this.element),
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken()
        }
      })
        .then((response) => response.text())
        .then((html) => Turbo.renderStreamMessage(html));
    }

    csrfToken() {
      var meta = document.querySelector('meta[name="csrf-token"]');
      return meta ? meta.content : "";
    }
  };

  application.register("model-form", ModelFormController);
})();
