// Self-contained Stimulus controllers for the engine. Loaded as a plain script
// after the vendored Stimulus + Turbo UMD builds, so it relies only on the
// `Stimulus` and `Turbo` globals — no bundler, importmap, or host JS.
(function () {
  "use strict";

  var application = Stimulus.Application.start();

  // Drives the "new model" form: add/remove column rows and stream a live
  // preview of the migration the form would generate.
  var ModelFormController = class extends Stimulus.Controller {
    static targets = ["rows", "template", "preview", "optionHeader", "idWarning"];
    static values = { previewUrl: String };

    connect() {
      this.timer = null;
      this.syncRows();
      this.refreshHints();
      this.refresh();
    }

    addRow() {
      this.rowsTarget.appendChild(this.templateTarget.content.cloneNode(true));
      this.syncRows();
      this.refreshHints();
      this.refresh();
    }

    removeRow(event) {
      var row = event.target.closest("[data-row]");
      if (row) row.remove();
      this.refreshHints();
      this.refresh();
    }

    // A reference column points at a table (and takes no default), so swap the
    // default input for the "references table" picker on reference rows.
    typeChanged(event) {
      var row = event.target.closest("[data-row]");
      if (row) this.syncRow(row);
      this.refreshHints();
    }

    // As a column name is typed, point its foreign key at the table Rails would
    // infer — but only if that table actually exists.
    nameInput(event) {
      var row = event.target.closest("[data-row]");
      if (row) this.autoTarget(row);
      this.updateIdWarning();
    }

    // Once the student picks a target themselves, stop auto-steering it.
    pickerTouched(event) {
      event.target.dataset.touched = "1";
    }

    // The "→ this table" self-reference option mirrors the model name above.
    modelNameInput() {
      this.updateSelfSuggestions();
    }

    // Header, _id warning, and self-reference suggestion all derive from the
    // whole row set, so refresh them together after structural changes.
    refreshHints() {
      this.updateOptionHeader();
      this.updateIdWarning();
      this.updateSelfSuggestions();
    }

    syncRows() {
      this.rowsTarget.querySelectorAll("[data-row]").forEach((row) => this.syncRow(row));
    }

    syncRow(row) {
      var type = row.querySelector('select[name="attributes[][type]"]').value;
      var isReference = type === "references" || type === "belongs_to";
      var picker = row.querySelector("[data-row-table]");
      var defaultField = row.querySelector("[data-row-default]");
      if (picker) picker.style.display = isReference ? "" : "none";
      if (defaultField) defaultField.style.display = isReference ? "none" : "";
      this.autoTarget(row);
    }

    // Select the existing table the column name points at (column "zebra" ->
    // "zebras"), or fall back to "no foreign key" when no such table exists — so
    // the default never produces a foreign key to a missing table. Leaves a
    // target the student picked themselves alone.
    autoTarget(row) {
      var picker = row.querySelector("[data-row-table]");
      if (!picker || picker.dataset.touched) return;
      var type = row.querySelector('select[name="attributes[][type]"]').value;
      if (type !== "references" && type !== "belongs_to") return;
      var field = row.querySelector('input[name="attributes[][name]"]');
      var inferred = field ? this.pluralize(this.underscore(field.value.trim())) : "";
      var match = Array.from(picker.options).some((option) => option.value === inferred);
      picker.value = match ? inferred : "";
    }

    pluralize(word) {
      if (/[^aeiou]y$/i.test(word)) return word.replace(/y$/i, "ies");
      if (/(s|ss|sh|ch|x|z)$/i.test(word)) return word + "es";
      return word + "s";
    }

    // The shared fourth-column header reflects the row types currently in play:
    // "Default", "To table", or both when the builder mixes them.
    updateOptionHeader() {
      if (!this.hasOptionHeaderTarget) return;
      var types = Array.from(this.rowsTarget.querySelectorAll('select[name="attributes[][type]"]')).map((select) => select.value);
      var hasReference = types.some((type) => type === "references" || type === "belongs_to");
      var hasOther = types.some((type) => type !== "references" && type !== "belongs_to");
      this.optionHeaderTarget.textContent = hasReference ? (hasOther ? "Default / to table" : "To table") : "Default";
    }

    // The self-reference option ("→ this table") names the table the model maps
    // to, derived from the model-name field (model "Zebra" -> table "zebras").
    updateSelfSuggestions() {
      var options = this.element.querySelectorAll("[data-self-suggestion]");
      if (!options.length) return;
      var field = this.element.querySelector('input[name="model_name"]');
      var name = field ? field.value.trim() : "";
      var label = name ? "→ " + this.pluralize(this.underscore(name)) : "→ this table";
      options.forEach((option) => { option.textContent = label; });
    }

    underscore(word) {
      return word.replace(/([a-z0-9])([A-Z])/g, "$1_$2").replace(/[\s-]+/g, "_").toLowerCase();
    }

    // references appends _id itself, so a column named foo_id becomes foo_id_id.
    // Surface any such rows as inline helper text below the builder.
    updateIdWarning() {
      if (!this.hasIdWarningTarget) return;
      var offenders = [];
      this.rowsTarget.querySelectorAll("[data-row]").forEach((row) => {
        var type = row.querySelector('select[name="attributes[][type]"]').value;
        if (type !== "references" && type !== "belongs_to") return;
        var name = (row.querySelector('input[name="attributes[][name]"]').value || "").trim();
        if (/_id$/i.test(name)) offenders.push(name);
      });
      var el = this.idWarningTarget;
      el.replaceChildren();
      if (!offenders.length) {
        el.hidden = true;
        return;
      }
      el.hidden = false;
      el.append("references adds ", this.code("_id"), " for you — drop it: ");
      offenders.forEach((name, index) => {
        if (index > 0) el.append(", ");
        el.append(this.code(name), " → ", this.code(name.replace(/_id$/i, "")));
      });
      el.append(".");
    }

    code(text) {
      var node = document.createElement("code");
      node.textContent = text;
      return node;
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

  // Debounced live preview for a single form (the edit-column form): POST the
  // form to its preview URL and render the returned Turbo Stream.
  var LivePreviewController = class extends Stimulus.Controller {
    static values = { url: String };

    connect() {
      this.timer = null;
      this.refresh();
    }

    scheduleRefresh() {
      clearTimeout(this.timer);
      this.timer = setTimeout(() => this.refresh(), 300);
    }

    refresh() {
      // Drop Rails' _method override so this preview stays a POST even when the
      // form itself submits as PATCH.
      var body = new FormData(this.element);
      body.delete("_method");
      fetch(this.urlValue, {
        method: "POST",
        body: body,
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

  application.register("live-preview", LivePreviewController);

  // Tick the would-be migration version (a UTC timestamp) once a second, so the
  // 14-digit number in a preview filename visibly counts up — showing students
  // exactly where that number comes from. Re-queries the DOM each tick, so it
  // keeps working after the live preview swaps in fresh markup.
  function pad(n) {
    return String(n).padStart(2, "0");
  }
  function migrationVersion() {
    var d = new Date();
    return "" + d.getUTCFullYear() + pad(d.getUTCMonth() + 1) + pad(d.getUTCDate()) +
      pad(d.getUTCHours()) + pad(d.getUTCMinutes()) + pad(d.getUTCSeconds());
  }
  function tickTimestamps() {
    var stamp = migrationVersion();
    document.querySelectorAll("[data-timestamp]").forEach(function (el) {
      el.textContent = stamp;
    });
  }
  setInterval(tickTimestamps, 1000);
  tickTimestamps();
})();
