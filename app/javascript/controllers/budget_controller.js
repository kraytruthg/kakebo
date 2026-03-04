import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["drawer"]
  static targets = [
    "categoryId", "categoryName",
    "form", "accountSelect",
    "outflow", "inflow"
  ]

  openWithCategory(event) {
    const { categoryId, categoryName } = event.params
    this.categoryIdTarget.value        = categoryId
    this.categoryNameTarget.textContent = categoryName
    this.updateFormAction()
    this.drawerOutlet.open()
    if (this.hasOutflowTarget) {
      this.outflowTarget.focus()
    }
  }

  closeDrawer() {
    this.drawerOutlet.close()
  }

  accountChanged() {
    this.updateFormAction()
  }

  updateFormAction() {
    const accountId = this.accountSelectTarget.value
    this.formTarget.action = `/accounts/${accountId}/transactions`
  }

  outflowInput() {
    if (this.outflowTarget.value !== "") {
      this.inflowTarget.value = ""
    }
  }

  inflowInput() {
    if (this.inflowTarget.value !== "") {
      this.outflowTarget.value = ""
    }
  }
}
