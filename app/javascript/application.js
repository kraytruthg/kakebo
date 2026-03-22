// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

// Turbo loading state tracking for system test synchronization.
// Bridges the aria-busy gap between form submit-redirect and page navigation.
document.addEventListener("turbo:load", () => {
  document.documentElement.removeAttribute("data-turbo-not-loaded")
  document.documentElement.removeAttribute("data-turbo-loading")
})

document.addEventListener("turbo:submit-start", (event) => {
  if (!event.target.closest("turbo-frame")) {
    document.documentElement.setAttribute("data-turbo-loading", "1")
  }
})

document.addEventListener("turbo:submit-end", (event) => {
  if (!event.detail.fetchResponse?.redirected) {
    document.documentElement.removeAttribute("data-turbo-loading")
  }
})
