// import { env } from "process";

import { Client } from "./types";

export const DATE = new Date();
// export const DEBUG = env.DEBUG === "true";
export const DEBUG = true;
export const CLIENT = new Client();
export const IS_ELECTRON = true;
export const IS_NODE = typeof window === "undefined";
