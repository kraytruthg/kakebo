import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this._escHandler = this._closeOnEsc.bind(this)
    this._tabHandler = this._trapTab.bind(this)
    document.addEventListener("keydown", this._escHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler)
    document.removeEventListener("keydown", this._tabHandler)
  }

  open() {
    this.previouslyFocused = document.activeElement
    this.panelTarget.classList.remove("translate-x-full")
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._tabHandler)
    this._focusFirstElement()
  }

  close() {
    this.panelTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.remove("opacity-100")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._tabHandler)
    if (this.previouslyFocused) {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  // Private

  _closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  _focusFirstElement() {
    const elements = this._focusableElements()
    if (elements.length > 0) elements[0].focus()
  }

  _trapTab(event) {
    if (event.key !== "Tab") return

    const elements = this._focusableElements()
    if (elements.length === 0) return

    const first = elements[0]
    const last = elements[elements.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  _focusableElements() {
    const selector = 'input:not([disabled]):not([type="hidden"]), button:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])'
    return [...this.panelTarget.querySelectorAll(selector)]
      .filter(el => el.offsetParent !== null)
  }
}
