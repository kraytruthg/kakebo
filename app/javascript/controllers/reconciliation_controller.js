import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "bankBalance",
    "bankBalanceDisplay",
    "bankBalanceInput",
    "confirmedBalance",
    "difference",
    "completeButton"
  ]
  static values = { reconciledBalance: Number }

  connect() {
    this.calculate()
    this.observer = new MutationObserver(() => this.calculate())
    this.observer.observe(this.element.querySelector("#reconciliation-transactions"), {
      childList: true, subtree: true, attributes: true
    })
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  calculate() {
    const bankBalance = parseFloat(this.bankBalanceTarget.value)
    const clearedSum = this.getClearedSum()
    const confirmedBalance = this.reconciledBalanceValue + clearedSum

    // Update displays
    if (isNaN(bankBalance)) {
      this.bankBalanceDisplayTarget.textContent = "—"
      this.differenceTarget.textContent = "—"
      this.differenceTarget.className = "text-lg font-bold text-slate-400"
      this.completeButtonTarget.disabled = true
      return
    }

    this.bankBalanceDisplayTarget.textContent = this.formatAmount(bankBalance)
    this.confirmedBalanceTarget.textContent = this.formatAmount(confirmedBalance)
    this.bankBalanceInputTarget.value = bankBalance

    const diff = bankBalance - confirmedBalance
    const absDiff = Math.abs(diff)

    if (absDiff < 0.005) {
      this.differenceTarget.textContent = "$0"
      this.differenceTarget.className = "text-lg font-bold text-emerald-600"
      this.completeButtonTarget.disabled = false
    } else {
      this.differenceTarget.textContent = this.formatAmount(diff)
      this.differenceTarget.className = "text-lg font-bold text-red-500"
      this.completeButtonTarget.disabled = true
    }
  }

  getClearedSum() {
    const rows = this.element.querySelectorAll("[data-cleared]")
    let sum = 0
    rows.forEach(row => {
      if (row.dataset.cleared === "true") {
        sum += parseFloat(row.dataset.amount) || 0
      }
    })
    return sum
  }

  formatAmount(value) {
    const formatted = Math.abs(value).toLocaleString("en-US", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    })
    return value < 0 ? `-$${formatted}` : `$${formatted}`
  }
}
