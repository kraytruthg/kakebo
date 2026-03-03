import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String,
    handle: { type: String, default: ".drag-handle" }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: this.handleValue,
      draggable: "[data-sortable-id]",
      animation: 150,
      ghostClass: "opacity-30",
      onEnd: this.onEnd.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  async onEnd() {
    const items = this.element.querySelectorAll(":scope > [data-sortable-id]")
    const positions = Array.from(items).map((item, index) => ({
      id: parseInt(item.dataset.sortableId),
      position: index
    }))

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ positions })
      })

      if (!response.ok) {
        window.location.reload()
      }
    } catch {
      window.location.reload()
    }
  }
}
