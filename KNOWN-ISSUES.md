# Known Issues and Workarounds
## Raspberry Pi Image Builder v1.0

**Last Updated:** 2026-01-26  
**Status:** 3 known issues (1 blocking macOS, 2 cosmetic)

---

## 🔴 Issue #1: macOS PLATFORM_TOOLS Initialization (BLOCKING)

**Severity:** HIGH  
**Status:** Open  
**Affects:** macOS only  
**Impact:** Script fails on startup on macOS  

### Symptoms
```
[2026-01-26 12:19:52] INFO: Checking platform dependencies...
/lib/platform-detect.sh: line 187: PLATFORM_TOOLS[@]: unbound variable
```

### Root Cause
When libraries were fixed in Task 5 to not overwrite `SCRIPT_DIR`, the `PLATFORM_TOOLS=()` array initialization on line 12 of `lib/platform-detect.sh` was not properly initialized when accessed in strict mode (`set -euo pipefail`).

### Workaround
**Use Linux for production deployments.** macOS is currently only suitable for development after fixing this bug.

### Fix Required
Ensure `PLATFORM_TOOLS` array is properly initialized before first access. Add explicit initialization or check for array existence before accessing.

**Proposed fix:**
```bash
# In lib/platform-detect.sh, before line 187
if [[ -z "${PLATFORM_TOOLS+x}" ]]; then
    PLATFORM_TOOLS=()
fi
```

---

## 🟡 Issue #2: Library Function Name Conflicts (COSMETIC)

**Severity:** LOW  
**Status:** Known limitation  
**Affects:** Help output on both platforms  
**Impact:** Wrong help message displayed  

### Symptoms
Running `./build-rpi-image.sh --help` shows library help instead of main script help:

```bash
$ ./build-rpi-image.sh --help
Open Horizon Installation Library

Usage: horizon-install.sh [COMMAND] [OPTIONS]
...
```

### Root Cause
Libraries define functions with common names (e.g., `show_usage`) that override the main script's functions when sourced.

### Workaround
Read README.md for correct usage information. The --help flag still exits correctly, just shows wrong content.

### Fix Options
1. **Namespace library functions** - Prefix with library name (`horizon_show_usage`)
2. **Conditional definition** - Only define show_usage in standalone mode
3. **Remove library CLI mode** - Libraries as pure imports only

**Not fixing in v1.0** - Low priority, doesn't affect functionality.

---

## 🟡 Issue #3: Registry Function Parameter Error (COSMETIC)

**Severity:** LOW  
**Status:** Known limitation  
**Affects:** Both platforms  
**Impact:** Non-critical warning, does not block execution  

### Symptoms
```
./build-rpi-image.sh: line 1033: $3: unbound variable
[2026-01-26 17:14:13] ERROR: append_to_agents_file: Missing required parameters
[2026-01-26 17:14:13] WARN: Failed to register agent configuration (non-critical)
```

### Root Cause
Registry creation functions have incorrect parameter validation logic. Script continues successfully despite warning.

### Workaround
Ignore the warning. Registry tracking is optional and failure doesn't affect image creation.

### Fix Required
Review `create_registry_entry()` and `append_to_agents_file()` parameter handling.

---

## Platform-Specific Limitations

### macOS
- ❌ **Blocked by Issue #1** - Not functional until PLATFORM_TOOLS bug fixed
- ⚠️ **No Open Horizon operations** - ARM chroot requires Linux + QEMU
- ⚠️ **No systemd operations** - Wi-Fi config and service management require systemd

### Linux
- ✅ **Fully functional** - All features working
- ⚠️ **Requires sudo** - Mount operations need root privileges
- ⚠️ **x86_64 architecture** - ARM hosts not tested (may work with native chroot)

---

## Reporting New Issues

If you encounter issues:

1. **Check this document first** - Your issue may be known
2. **Enable debug logging** - Run with `DEBUG=1`
3. **Check build-rpi-image.log** - Contains detailed execution trace
4. **Collect system information** - Platform, OS version, dependency versions
5. **Create minimal reproduction** - Simplest command that triggers the issue

---

**Document Version:** 1.0  
**Compatible with:** Raspberry Pi Image Builder v1.0 MVP
