import { writable } from "svelte/store";
import type { Field } from "./types";

export const currentFieldModal = writable<Field | undefined>(undefined);
