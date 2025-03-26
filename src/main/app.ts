import { app, shell, BrowserWindow } from "electron";
import { join } from "path";
import { electronApp, optimizer, is } from "@electron-toolkit/utils";
import { beforeQuitTasks } from "@/backend/common/constants";
import { tryCatchAsync } from "@/common/functions";

// import icon from "../renderer/src/assets/icon.png?asset";
const icon = "";
process.env.ELECTRON_DISABLE_SECURITY_WARNINGS = "true";

// https://github.com/ThaUnknown/miru/blob/master/electron/src/main/util.js#L6
// const flags = [
//   // not sure if safe?
//   ["disable-gpu-sandbox"],
//   ["disable-direct-composition-video-overlays"],
//   ["double-buffer-compositing"],
//   ["enable-zero-copy"],
//   ["ignore-gpu-blocklist"],
//   // should be safe
//   ["enable-hardware-overlays", "single-fullscreen,single-on-top,underlay"],
//   // safe performance stuff
//   [
//     "enable-features",
//     "PlatformEncryptedDolbyVision,CanvasOopRasterization,ThrottleDisplayNoneAndVisibilityHiddenCrossOriginIframes,UseSkiaRenderer,WebAssemblyLazyCompilation",
//   ],
//   // disabling shit, vulkan rendering, widget layering aka right click context menus [I think] for macOS [I think]
//   ["disable-features", "Vulkan,WidgetLayering"],
//   // utility stuff, aka website security that's useless for a native app:
//   ["autoplay-policy", "no-user-gesture-required"],
//   ["disable-notifications"],
//   ["disable-logging"],
//   ["disable-permissions-api"],
//   ["no-sandbox"],
//   ["no-zygote"],
//   ["bypasscsp-schemes"],
//   ["force_high_performance_gpu", "disable-renderer-backgroundin"],
// ];
//
// for (const [flag, value] of flags) {
//   app.commandLine.appendSwitch(flag, value);
// }

export function startApp() {
  // This method will be called when Electron has finished
  // initialization and is ready to create browser windows.
  // Some APIs can only be used after this event occurs.
  app.whenReady().then(() => {
    // Set app user model id for windows
    electronApp.setAppUserModelId("com.sentorr.app");

    // Default open or close DevTools by F12 in development
    // and ignore CommandOrControl + R in production.
    // see https://github.com/alex8088/electron-toolkit/tree/master/packages/utils
    app.on("browser-window-created", (_, window) => {
      optimizer.watchWindowShortcuts(window);
    });

    createWindow();

    app.on("activate", function () {
      // On macOS it's common to re-create a window in the app when the
      // dock icon is clicked and there are no other windows open.
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });

    // Quit when all windows are closed, except on macOS. There, it's common
    // for applications and their menu bar to stay active until the user quits
    // explicitly with Cmd + Q.
    app.on("window-all-closed", () => {
      if (process.platform !== "darwin") {
        app.quit();
      }
    });

    // In this file you can include the rest of your app"s specific main process
    // code. You can also put them in separate files and require them here.

    app.on("before-quit", async (event) => {
      console.log("before-quit");
      if (!beforeQuitTasks.length) return;
      event.preventDefault();
      console.log("beforeQuitTasks:", beforeQuitTasks);
      for (const task of beforeQuitTasks) {
        const [, taskError] = await tryCatchAsync(task);
        if (taskError)
          console.error(`Before quit task error:`, task, taskError);
      }
      beforeQuitTasks.length = 0;
      app.quit();
    });
  });
}
export function createWindow(): void {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    // FIXME: Without this linux doesn't start maximised for some reason
    show: process.platform === "linux",
    titleBarStyle: "hidden",
    titleBarOverlay: {
      height: 30,
      symbolColor: "rgba(255, 255, 255, 1)",
      color: "rgba(0, 0, 0, 0.13)",
    },
    resizable: true,
    autoHideMenuBar: true,
    ...(process.platform === "linux" ? { icon } : {}),
    webPreferences: {
      preload: join(__dirname, "../preload/index.mjs"),
      nodeIntegration: true,
      contextIsolation: true,
      webSecurity: false,
      enableBlinkFeatures: "FontAccess, AudioVideoTracks",
    },
  });

  mainWindow.on("ready-to-show", () => {
    mainWindow.maximize();
    mainWindow.show();
  });

  mainWindow.webContents.setWindowOpenHandler((details) => {
    shell.openExternal(details.url);
    return { action: "deny" };
  });

  // HMR for renderer base on electron-vite cli.
  // Load the remote URL for development or the local html file for production.
  if (is.dev && process.env["ELECTRON_RENDERER_URL"]) {
    mainWindow.loadURL(process.env["ELECTRON_RENDERER_URL"]);
  } else {
    mainWindow.loadFile(join(__dirname, "../renderer/index.html"));
  }
}
