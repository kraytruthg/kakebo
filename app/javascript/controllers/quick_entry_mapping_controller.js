import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "categoryField", "accountField"]

  toggleTarget() {
    const type = this.typeSelectTarget.value
    this.categoryFieldTarget.classList.toggle("hidden", type !== "Category")
    this.accountFieldTarget.classList.toggle("hidden", type !== "Account")
  }
}
