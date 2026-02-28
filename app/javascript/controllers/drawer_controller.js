import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("translate-x-full")
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.panelTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.remove("opacity-100")
    document.body.classList.remove("overflow-hidden")
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  connect() {
    this._escHandler = this.closeOnEsc.bind(this)
    document.addEventListener("keydown", this._escHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler)
  }
}
