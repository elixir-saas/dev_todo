// Note: Phoenix JS dependencies (Phoenix.Socket, LiveView.LiveSocket) are loaded
// from their OTP application directories by the Assets module at compile time.
import Sortable from "sortablejs";
import SortableHook from "@phx-hook/sortable";
import RightClickMenuHook from "@phx-hook/right-click-menu";

let socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live";
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { Sortable: SortableHook(Sortable), RightClickMenu: RightClickMenuHook() },
});

window.addEventListener("phx:page-loading-start", () => {
  document.body.classList.add("phx-loading");
});
window.addEventListener("phx:page-loading-stop", () => {
  document.body.classList.remove("phx-loading");
});

liveSocket.connect();
window.liveSocket = liveSocket;
