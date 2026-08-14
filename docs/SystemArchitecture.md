## System Architecture & Execution Workflow

### 1. Hardware & OS Detection

When an external monitor connects via HDMI or DisplayPort:

* **EDID Inspection:** macOS inspects the display's onboard **EDID (Extended Display Identification Data)** payload.
* **CEA-861 Flag Trigger:** If a **CEA-861 extension block** is detected, macOS misclassifies the display as a consumer television.
* **Software Underscan:** `WindowServer` assumes the screen will crop image edges and sets `overscanAdjustment` to `scaleContent`.
* **Border Padding:** QuartzCore scales the desktop surface down to ~80–90% of native bounds, creating black padding around the picture.

---

### 2. FixDisplay Swift Runtime Execution

To override this misclassification dynamically without modifying system plist files:

* **Framework Ingestion:** Upon launch, `FixDisplay` calls `dlopen` to dynamically load `QuartzCore.framework` into memory.
* **Runtime Reflection:** It reflects active `CADisplay` instances for all connected screens.
* **Property Override:** It explicitly invokes `setOverscanAdjustment:` with `"none"` across each display object to remove the scaling directive.
* **Session Transaction:** It opens a transaction via `CGBeginDisplayConfiguration` and commits it with `CGCompleteDisplayConfiguration`.

---

### 3. Render Pipeline Output

Once the CoreGraphics transaction commits:

* **Cache Invalidation:** `WindowServer` tears down its cached state and flushes active framebuffers.
* **Direct Pipeline Mapping:** With `overscanAdjustment` set to `"none"`, the graphics pipeline bypasses all software padding algorithms.
* **Native 1:1 Resolution:** GPU output buffers re-allocate to drive the physical screen at 100% unscaled, borderless resolution.