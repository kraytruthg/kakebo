import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["restore"]

  connect() {
    this._handleFocusOut = this._onFocusOut.bind(this)
    this._handleFocusIn = this._onFocusIn.bind(this)
    // Wait for first focusin before listening for focusout,
    // to avoid race condition with autofocus on Turbo Frame load
    this.element.addEventListener("focusin", this._handleFocusIn, { once: true })
  }

  disconnect() {
    this.element.removeEventListener("focusin", this._handleFocusIn)
    this.element.removeEventListener("focusout", this._handleFocusOut)
  }

  _onFocusIn() {
    this.element.addEventListener("focusout", this._handleFocusOut)
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this._cancel()
    }
  }

  // Private

  _onFocusOut(event) {
    requestAnimationFrame(() => {
      if (this.element.contains(document.activeElement)) return
      this._cancel()
    })
  }

  _cancel() {
    if (!this.hasRestoreTarget) return

    const frame = this.element.closest("turbo-frame") || this.element
    frame.innerHTML = this.restoreTarget.innerHTML
  }
}
