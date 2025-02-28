// import { env } from "process";

import { createClient } from "./client";

export const DATE = new Date();
// export const DEBUG = env.DEBUG === "true";
export const DEBUG = true;
export const Client = createClient();
