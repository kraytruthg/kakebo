import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { restoreUrl: String }

  connect() {
    this._handleFocusOut = this._onFocusOut.bind(this)
    this.element.addEventListener("focusout", this._handleFocusOut)
  }

  disconnect() {
    this.element.removeEventListener("focusout", this._handleFocusOut)
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this._cancel()
    }
  }

  // Private

  _onFocusOut(event) {
    // Use requestAnimationFrame to let the browser set the new activeElement
    requestAnimationFrame(() => {
      // If the new focused element is still within this controller's element, do nothing
      if (this.element.contains(document.activeElement)) return

      this._cancel()
    })
  }

  _cancel() {
    if (!this.hasRestoreUrlValue) return

    // Set the turbo-frame's src to trigger a Turbo reload of the display state
    const frame = this.element.closest("turbo-frame") || this.element
    frame.src = this.restoreUrlValue
  }
}
