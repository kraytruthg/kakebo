import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]
  static values = { expected: String }

  validate() {
    this.buttonTarget.disabled = this.inputTarget.value !== this.expectedValue
  }
}
