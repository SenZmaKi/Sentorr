import { Resolution } from "./types";
import { Language } from "@ctrl/video-filename-parser";

export const RESOLUTIONS = Object.values(Resolution).filter(
  (value) => typeof value === "number",
);

export const LANGUAGES = Object.values(Language);
