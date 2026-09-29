import { Controller } from "@hotwired/stimulus"

// Drag-to-reorder. Each child <li> needs draggable="true" and data-id="...".
// On drop, PATCHes the new ordered ids array to data-sortable-url-value.
//
// Mobile Safari never fires native HTML5 drag events (dragstart/dragover/drop),
// so touch devices get a parallel touch-based implementation. Touch dragging is
// scoped to the ".speakers-list__handle" so it doesn't swallow taps on the
// row's buttons/links.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.draggedItem = null
    this.startOrder = null
    this.touchId = null
    this.autoScrollRAF = null
    this.autoScrollDelta = 0
    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragover",  this.onDragOver)
    this.element.addEventListener("drop",      this.onDrop)
    this.element.addEventListener("dragend",   this.onDragEnd)
    this.element.addEventListener("touchstart", this.onTouchStart, { passive: false })
    this.element.addEventListener("touchmove",  this.onTouchMove,  { passive: false })
    this.element.addEventListener("touchend",   this.onTouchEnd)
    this.element.addEventListener("touchcancel", this.onTouchEnd)
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragover",  this.onDragOver)
    this.element.removeEventListener("drop",      this.onDrop)
    this.element.removeEventListener("dragend",   this.onDragEnd)
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchmove",  this.onTouchMove)
    this.element.removeEventListener("touchend",   this.onTouchEnd)
    this.element.removeEventListener("touchcancel", this.onTouchEnd)
    this.stopAutoScroll()
  }

  onDragStart = (e) => {
    const li = e.target.closest("[data-id]")
    if (!li) return
    this.beginDrag(li)
    e.dataTransfer.effectAllowed = "move"
  }

  onDragOver = (e) => {
    e.preventDefault()
    this.reorderTarget(e.target.closest("[data-id]"), e.clientY)
  }

  onDrop = (e) => { e.preventDefault() }

  onDragEnd = () => { this.endDrag() }

  onTouchStart = (e) => {
    const handle = e.target.closest(".speakers-list__handle")
    if (!handle) return
    const li = handle.closest("[data-id]")
    if (!li) return
    this.touchId = e.changedTouches[0].identifier
    this.beginDrag(li)
    e.preventDefault()
  }

  onTouchMove = (e) => {
    if (!this.draggedItem) return
    const touch = this.touchById(e.touches, this.touchId)
    if (!touch) return
    e.preventDefault()

    this.autoScroll(touch.clientY)

    const target = document.elementFromPoint(touch.clientX, touch.clientY)?.closest("[data-id]")
    if (target && this.element.contains(target)) this.reorderTarget(target, touch.clientY)
  }

  onTouchEnd = (e) => {
    if (!this.draggedItem || !this.touchById(e.changedTouches, this.touchId)) return
    this.touchId = null
    this.endDrag()
  }

  beginDrag(li) {
    this.draggedItem = li
    this.startOrder = this.currentIds()
    li.classList.add("is-dragging")
  }

  reorderTarget(target, clientY) {
    if (!target || target === this.draggedItem) return
    const rect = target.getBoundingClientRect()
    const before = (clientY - rect.top) < rect.height / 2
    target.parentNode.insertBefore(this.draggedItem, before ? target : target.nextSibling)
  }

  endDrag() {
    this.stopAutoScroll()
    if (this.draggedItem) this.draggedItem.classList.remove("is-dragging")
    this.draggedItem = null
    this.persistIfChanged()
  }

  touchById(touchList, id) {
    for (let i = 0; i < touchList.length; i++) {
      if (touchList[i].identifier === id) return touchList[i]
    }
    return null
  }

  // Auto-scrolls the window while a touch-drag is held near the top/bottom
  // edge of the viewport — touch-action: none blocks normal scroll gestures
  // during a drag, so without this an item can't be moved past the fold.
  autoScroll(clientY) {
    const EDGE = 60
    const SPEED = 12
    const fromTop = clientY
    const fromBottom = window.innerHeight - clientY

    let delta = 0
    if (fromTop < EDGE) delta = -SPEED * (1 - fromTop / EDGE)
    else if (fromBottom < EDGE) delta = SPEED * (1 - fromBottom / EDGE)

    if (delta === this.autoScrollDelta) return
    this.autoScrollDelta = delta
    if (this.autoScrollRAF) cancelAnimationFrame(this.autoScrollRAF)
    this.autoScrollRAF = null

    if (delta !== 0) {
      const step = () => {
        window.scrollBy(0, this.autoScrollDelta)
        this.autoScrollRAF = requestAnimationFrame(step)
      }
      this.autoScrollRAF = requestAnimationFrame(step)
    }
  }

  stopAutoScroll() {
    if (this.autoScrollRAF) cancelAnimationFrame(this.autoScrollRAF)
    this.autoScrollRAF = null
    this.autoScrollDelta = 0
  }

  currentIds() {
    return Array.from(this.element.querySelectorAll("[data-id]")).map(el => el.dataset.id)
  }

  persistIfChanged() {
    const ids = this.currentIds()
    const changed = !this.startOrder || ids.length !== this.startOrder.length ||
      ids.some((id, i) => id !== this.startOrder[i])
    this.startOrder = null
    if (changed) this.persist(ids)
  }

  persist(ids) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrf,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ signup_ids: ids })
    })
      .then(r => r.text())
      .then(html => window.Turbo?.renderStreamMessage(html))
  }
}
