// HTTP Download Engine simulation model.
// Based on the real implementation in Senpwai/Sentorr (lib/shared/net/download):
// - Multi-connection byte-range slicing (Range: bytes=start-end)
// - 206 Partial Content vs 200 fallback (single-connection sequential)
// - Serialized offset file writer (_OffsetFileWriter queue)
// - 1 MiB block SHA-256 checkpointing (HttpCheckpoint)
// - DownloadThrottler rate shaping
// - Transient failure exponential backoff (2 << attempt)
// - ETag / If-Range resource change invalidation

export const SLOTS = 32; // File representation divided into 32 blocks (e.g. 2 MiB each = 64 MiB)
export const BLOCK_MIB = 2;
export const MAX_WORKERS = 8;
export const DEFAULT_WORKERS = 4;
export const DEFAULT_SPEED_MBPS = 8; // 8 MB/s

export const DEFAULTS = {
  workers: 4,          // Number of parallel HTTP connections (1..8)
  speedMBps: 8,        // Bandwidth cap via DownloadThrottler
  rangeSupport: true,  // Does server accept Range requests (206) or full only (200)?
  fileMiB: 64,         // Total file size
  errorRate: 0,        // Probability of network stall / dropped connection
};

/** Derived constants from configuration */
export function derive(input) {
  const c = { ...DEFAULTS, ...input };
  const effectiveWorkers = c.rangeSupport ? Math.min(MAX_WORKERS, Math.max(1, c.workers)) : 1;
  const totalSlots = SLOTS;

  // Partition slots into ranges for each worker
  const baseSlots = Math.floor(totalSlots / effectiveWorkers);
  const extra = totalSlots % effectiveWorkers;

  const partitions = [];
  let offset = 0;
  for (let i = 0; i < effectiveWorkers; i++) {
    const len = baseSlots + (i < extra ? 1 : 0);
    partitions.push({
      workerId: i,
      startSlot: offset,
      endSlot: offset + len, // exclusive
      slotCount: len,
      startByte: offset * BLOCK_MIB * 1024 * 1024,
      endByte: (offset + len) * BLOCK_MIB * 1024 * 1024,
    });
    offset += len;
  }

  return {
    ...c,
    effectiveWorkers,
    totalSlots,
    partitions,
    bytesPerSlot: (c.fileMiB * 1024 * 1024) / totalSlots,
  };
}

export function create(config) {
  const c = derive(config);
  return resetState(c);
}

export function resetState(c) {
  const workers = c.partitions.map((p, idx) => ({
    id: idx,
    range: p,
    progress: 0,       // slots completed within its partition (float)
    active: false,     // currently streaming bytes
    status: 'idle',    // 'probing', 'connecting', 'streaming', 'retrying', 'done'
    retryAttempt: 0,
    retryTimer: 0,
    speedMBps: 0,
    etag: '0x4F92B1',
  }));

  return {
    c,
    slots: new Float32Array(c.totalSlots), // 0.0 to 1.0 download progress per slot
    checkpoints: new Uint8Array(c.totalSlots), // 1 if SHA-256 block committed & flushed
    workers,
    activeWorkerCount: c.effectiveWorkers,
    // Serialized Offset Writer state
    writer: {
      position: 0,      // slot position where the write head is positioned
      targetSlot: 0,    // slot where head wants to go
      isWriting: false,
      queueLength: 0,
      flushCountdown: 0,
    },
    // Overall engine state
    stage: 'probe',     // 'probe', 'plan', 'restore', 'transfer', 'flush', 'complete', 'recovery'
    probing: 1.0,       // probe animation duration
    rateMBps: 0,
    totalDownloadedMiB: 0,
    completed: false,
    paused: false,
    resourceChanged: false, // ETag invalidation triggered
    time: 0,
  };
}

export function step(s, dt) {
  if (s.paused || s.completed) return;
  s.time += dt;

  // STAGE 1: PROBE (HTTP HEAD / Range: bytes=0-1)
  if (s.stage === 'probe') {
    s.probing -= dt * 2.0;
    if (s.probing <= 0) {
      s.stage = 'plan';
    }
    return;
  }

  // STAGE 2: PLAN (Partition ranges, allocate sparse file)
  if (s.stage === 'plan') {
    s.stage = 'transfer';
    s.workers.forEach(w => {
      w.active = true;
      w.status = 'streaming';
    });
    return;
  }

  // STAGE 3 & 4: TRANSFER & FLUSH
  if (s.stage === 'transfer' || s.stage === 'flush' || s.stage === 'recovery') {
    let activeStreamers = 0;
    const workerSpeed = (s.c.speedMBps / Math.max(1, s.workers.filter(w => w.status === 'streaming').length));

    for (let w of s.workers) {
      if (w.status === 'retrying') {
        w.retryTimer -= dt;
        if (w.retryTimer <= 0) {
          w.status = 'streaming';
          w.active = true;
        }
        continue;
      }

      if (w.status === 'streaming') {
        activeStreamers++;
        w.speedMBps = workerSpeed;
        const currentSlotIndex = Math.min(w.range.endSlot - 1, w.range.startSlot + Math.floor(w.progress));

        // Progress speed in slots per second
        // speedMBps / (fileMiB / totalSlots) = slots / sec
        const slotRate = (workerSpeed / (s.c.fileMiB / s.c.totalSlots));
        const delta = slotRate * dt;
        w.progress += delta;

        // Fill slots
        const fillIndex = Math.min(w.range.endSlot - 1, w.range.startSlot + Math.floor(w.progress));
        const slotFract = w.progress - Math.floor(w.progress);

        for (let i = w.range.startSlot; i < fillIndex; i++) {
          s.slots[i] = 1.0;
          s.checkpoints[i] = 1; // Verified block
        }
        if (fillIndex < w.range.endSlot) {
          s.slots[fillIndex] = Math.min(1.0, slotFract);
        }

        // Steer the serialized writer head toward this active slot
        s.writer.targetSlot = fillIndex;
        s.writer.isWriting = true;

        if (w.progress >= w.range.slotCount) {
          w.status = 'done';
          w.active = false;
          w.speedMBps = 0;
          for (let i = w.range.startSlot; i < w.range.endSlot; i++) {
            s.slots[i] = 1.0;
            s.checkpoints[i] = 1;
          }
        }
      }
    }

    // Move writer smoothly toward targetSlot
    const writerSpeed = 12; // slots per sec
    const diff = s.writer.targetSlot - s.writer.position;
    if (Math.abs(diff) > 0.05) {
      s.writer.position += Math.sign(diff) * Math.min(Math.abs(diff), writerSpeed * dt);
    } else {
      s.writer.position = s.writer.targetSlot;
    }

    // Update overall stats
    let totalDownloaded = 0;
    let allDone = true;
    for (let i = 0; i < s.c.totalSlots; i++) {
      totalDownloaded += s.slots[i];
      if (s.slots[i] < 1.0) allDone = false;
    }
    s.totalDownloadedMiB = (totalDownloaded / s.c.totalSlots) * s.c.fileMiB;
    s.rateMBps = activeStreamers > 0 ? s.c.speedMBps : 0;

    if (allDone) {
      s.stage = 'complete';
      s.completed = true;
      s.rateMBps = 0;
      s.writer.isWriting = false;
      s.workers.forEach(w => {
        w.active = false;
        w.status = 'done';
        w.speedMBps = 0;
      });
    } else if (s.workers.some(w => w.status === 'retrying')) {
      s.stage = 'recovery';
    } else {
      s.stage = 'transfer';
    }
  }
}

/** Action: trigger simulated connection drop on worker */
export function dropConnection(s, workerId = 0) {
  const w = s.workers[workerId % s.workers.length];
  if (w && w.status === 'streaming') {
    w.status = 'retrying';
    w.active = false;
    w.retryAttempt = Math.min(3, w.retryAttempt + 1);
    w.retryTimer = 2 << w.retryAttempt; // 4s, 8s, 16s backoff
    s.stage = 'recovery';
  }
}

/** Action: trigger ETag invalidation (server changed file) */
export function invalidateETag(s) {
  s.resourceChanged = true;
  s.stage = 'probe';
  s.probing = 1.0;
  // Discard all unverified data, restart from zero
  for (let i = 0; i < s.c.totalSlots; i++) {
    s.slots[i] = 0;
    s.checkpoints[i] = 0;
  }
  s.workers.forEach(w => {
    w.progress = 0;
    w.status = 'idle';
    w.active = false;
    w.retryAttempt = 0;
    w.retryTimer = 0;
    w.speedMBps = 0;
  });
  s.writer.position = 0;
  s.writer.targetSlot = 0;
  s.completed = false;
}

/** Action: pause/resume */
export function togglePause(s) {
  s.paused = !s.paused;
}

/** Action: reconfigure */
export function reconfigure(s, newConfig) {
  const c = derive({ ...s.c, ...newConfig });
  const fresh = resetState(c);
  Object.assign(s, fresh);
}
