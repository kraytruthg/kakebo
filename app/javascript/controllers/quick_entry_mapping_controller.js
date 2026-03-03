import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "categoryField", "accountField"]

  connect() {
    this.syncDisabledState()
  }

  toggleTarget() {
    const type = this.typeSelectTarget.value
    this.categoryFieldTarget.classList.toggle("hidden", type !== "Category")
    this.accountFieldTarget.classList.toggle("hidden", type !== "Account")
    this.syncDisabledState()
  }

  syncDisabledState() {
    const type = this.typeSelectTarget.value
    const categorySelect = this.categoryFieldTarget.querySelector("select")
    const accountSelect = this.accountFieldTarget.querySelector("select")
    if (categorySelect) categorySelect.disabled = (type !== "Category")
    if (accountSelect) accountSelect.disabled = (type !== "Account")
  }
}
