import { createNetClient } from "./net";

export const DEBUG = true;
export const IS_BROWSER = typeof window !== "undefined";
export const netClient = createNetClient();
