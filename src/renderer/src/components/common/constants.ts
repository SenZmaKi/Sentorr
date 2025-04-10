import { createTippy } from "svelte-tippy";
import "tippy.js/animations/scale.css";
import "tippy.js/dist/tippy.css";
import "tippy.js/themes/light.css";

export const tippy = createTippy({
  delay: [500, 100],
  animation: "scale",
  arrow: false,
  theme: "light",
  hideOnClick: false,
});
