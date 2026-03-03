import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "backdrop", "panel",
    "categoryId", "categoryName",
    "form", "accountSelect",
    "outflow", "inflow"
  ]

  // 開啟 Drawer 並預先設定類別
  openWithCategory(event) {
    const { categoryId, categoryName } = event.params
    this.categoryIdTarget.value        = categoryId
    this.categoryNameTarget.textContent = categoryName
    this.updateFormAction()
    this.open()
  }

  // Drawer 開關
  open() {
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    this.panelTarget.classList.remove("translate-x-full")
    if (this.hasOutflowTarget) {
      this.outflowTarget.focus()
    }
  }

  close() {
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.remove("opacity-100")
    this.panelTarget.classList.add("translate-x-full")
  }

  backdropClick() {
    this.close()
  }

  // 帳戶下拉改變時更新 form action
  accountChanged() {
    this.updateFormAction()
  }

  updateFormAction() {
    const accountId = this.accountSelectTarget.value
    this.formTarget.action = `/accounts/${accountId}/transactions`
  }

  // Outflow/Inflow 互斥
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
