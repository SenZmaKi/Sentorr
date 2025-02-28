import { isHovering } from "./store";

export function hoverManager() {
  function onPointerEnter() {
    isHovering.set(true);
  }
  function onPointerLeave() {
    isHovering.set(false);
  }

  return {
    onPointerEnter,
    onPointerLeave,
  };
}
