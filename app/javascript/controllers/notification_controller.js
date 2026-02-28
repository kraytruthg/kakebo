import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.dismiss(), 3000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.style.transition = "opacity 0.3s"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
