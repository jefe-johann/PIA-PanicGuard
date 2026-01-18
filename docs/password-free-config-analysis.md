# Assessment: Password-Free Config Editing Feasibility

**Date:** January 18, 2026
**Status:** Analysis complete - Reverting to password-prompt design
**Decision:** Option 1 (Revert) selected

---

## Problem Statement

We attempted to eliminate password prompts for SwiftBar feature toggles by making the config file user-owned. However, we hit fundamental Unix permission issues.

## What We Tried

**Changes Made:**
1. Config file ownership: `root:wheel` → `user:staff`
2. Modified helper script to not use sudo
3. Modified SwiftBar plugin to call helper without osascript

**Result:** Failed with permission errors

## Root Cause

This is a fundamental Unix permissions issue:
- Config file: `/usr/local/etc/pia-sleep.conf` (user-owned)
- Directory: `/usr/local/etc/` (root-owned)

**The Problem:**
- You can own a file but still can't modify it if the parent directory blocks you
- Writing requires creating temp files in the directory
- `mv /tmp/file /usr/local/etc/file` fails: "Permission denied"
- `/usr/local/etc/` is a system directory and **should** remain root-owned

---

## Options Evaluated

### Option 1: Revert Everything ✅ SELECTED

**What:** Accept password prompts as designed

**Pros:**
- Clean, simple, follows macOS security patterns
- Original design was correct
- Password prompts provide clear feedback
- No risk of breaking anything

**Cons:**
- Password prompt for each toggle

**Risk:** LOW

---

### Option 2: Move Config to User Directory

**What:** Move to `~/.config/pia-sleep/` or `~/Library/Application Support/`

**Pros:**
- No passwords needed
- Common pattern for user configs

**Cons:**
- Breaks existing setup
- Need to update 5+ files
- Complex migration
- Config is system-wide, not user-specific

**Risk:** MEDIUM

---

### Option 3: Make /usr/local/etc User-Writable

**What:** `sudo chown $USER:staff /usr/local/etc`

**Cons:**
- **SECURITY RISK**
- Violates Unix security principles
- Could affect other software
- Bad practice

**Risk:** HIGH - DO NOT DO THIS

---

### Option 4: Use sudoers NOPASSWD Rule

**What:** Add helper script to sudoers with NOPASSWD

**Cons:**
- Editing sudoers is dangerous
- Security risk
- Not user-friendly

**Risk:** HIGH

---

## Decision Rationale

**Password prompts are a feature, not a bug.**

1. **Security by Design:** macOS uses password prompts for system changes
2. **User Expectation:** Users expect prompts when changing system settings
3. **Low Frequency:** Settings don't toggle constantly
4. **Clear Feedback:** Prompts confirm action is privileged

The original design was correct. We were trying to "fix" something that wasn't broken.

---

## Lessons Learned

1. **Don't fight the system** - macOS security patterns exist for good reasons
2. **Test feasibility early** - Directory permissions matter as much as file permissions
3. **Original design was good** - Sometimes the "inconvenience" is intentional

---

## Implementation Notes

### What Was Reverted

1. Config ownership: `user:staff` → `root:wheel`
2. Helper script: Restored osascript usage
3. SwiftBar plugin: Restored "with administrator privileges"
4. install.sh: Restored root:wheel ownership

### How It Works Now

1. User clicks toggle in SwiftBar
2. SwiftBar calls helper script via osascript "with administrator privileges"
3. macOS shows native password prompt
4. Helper script modifies `/usr/local/etc/pia-sleep.conf`
5. Toggle updates successfully

---

## Future Consideration

If password prompts become truly problematic, **Option 2** (move config to user directory) is the only viable alternative. However, this requires:
- Careful planning
- Migration strategy
- Updates to multiple files
- Testing

For now, accept the password prompts. They serve a purpose.
