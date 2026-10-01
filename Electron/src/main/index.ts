import configManager from "@/backend/config/manager";
import { handle } from "@/common/ipc";
import { createWorker } from "./worker";
import { startApp } from "./app";

startApp();

// IPC

createWorker();
handle("getConfig", configManager.getConfig);
handle("setConfig", configManager.setConfig);
