// import { env } from "process";

import { createNetClient } from "./net";

// export const DEBUG = env.DEBUG === "true";
export const DEBUG = true;
export const netClient = createNetClient();
