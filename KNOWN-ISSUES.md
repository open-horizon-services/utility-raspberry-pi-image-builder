# Known Issues and Workarounds
## Raspberry Pi Image Builder v1.0

**Last Updated:** 2026-01-26  
**Status:** ✅ No known issues (all previously reported issues resolved)

---

## ✅ Resolved Issues

All previously reported issues are resolved in the current codebase:

1. **macOS PLATFORM_TOOLS initialization** — fixed by ensuring the array is initialized before use.
2. **Library function name conflicts** — fixed by namespacing library CLI helpers.
3. **Registry parameter validation warning** — fixed by correcting argument handling.

---

## Platform-Specific Limitations

### macOS
- ✅ **Fully functional** - All core features working
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
