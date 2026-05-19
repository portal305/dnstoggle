# DNS Toggle - Project Analysis & Feature Roadmap

## Current State

### Implemented Features
- System-level DNS control via Shizuku (Private DNS API)
- Quick Settings tile toggle
- Home screen widget (2x2, resizable)
- Excluded apps monitoring with auto DNS toggle
- Persistent notification with toggle actions
- Server latency measurement
- Custom server import/export (JSON)
- Auto-start on boot
- Material 3 Expressive UI with dynamic colors
- DNS connectivity test
- Background service for app monitoring

### Architecture
- Flutter UI with Provider state management
- Kotlin native services (foreground service, tile, widget, receiver)
- SharedPreferences for persistence
- Shizuku for privileged system settings access

---

## Feature Suggestions

### High Priority

#### 1. DNS-over-HTTPS (DoH) / DNS-over-TLS (DoT) Support
**Why:** System Private DNS only supports hostname-based DoT. Adding DoH would allow using DNS providers that don't support DoT or need custom endpoints.
**Implementation:** Integrate a local DNS proxy (like `dnsproxy` or custom implementation) that handles DoH/DoT and routes system DNS to localhost.

#### 2. DNS Leak Test
**Why:** Users need to verify DNS queries aren't leaking to ISP resolvers when using custom DNS.
**Implementation:** Use public DNS leak test APIs (dnsleaktest.com, ipleak.net) and display results with visual indicators.

#### 3. Network Change Detection
**Why:** DNS settings may break when switching between WiFi/mobile data or connecting to captive portals.
**Implementation:** Register `ConnectivityManager.NetworkCallback` to detect network changes and auto-reapply DNS settings or show a notification.

#### 4. Multiple DNS Profiles
**Why:** Users may want different DNS configurations for different scenarios (home, work, travel).
**Implementation:** Add profile management with quick switching. Each profile stores server selection, excluded apps, and settings.

#### 5. Scheduled DNS Toggling
**Why:** Users may want to disable DNS filtering during certain hours (e.g., for parental controls, work hours).
**Implementation:** Use `WorkManager` or `AlarmManager` to schedule DNS start/stop at specified times.

### Medium Priority

#### 6. DNS Query Statistics Dashboard
**Why:** Users want to see how many queries were blocked, latency trends, and uptime.
**Implementation:** Log DNS state changes and query counts locally. Display charts with `fl_chart` library.

#### 7. Widget Customization
**Why:** Users want to choose widget size, style, and displayed information.
**Implementation:** Add widget configuration activity. Support multiple widget sizes (1x1, 2x2, 4x1).

#### 8. Per-App DNS Bypass UI Improvements
**Why:** Current implementation uses `UsageStatsManager` which may not work reliably on all OEMs.
**Implementation:** Add fallback to `AccessibilityService` for OEMs that restrict UsageStats. Add manual refresh button.

#### 9. DNS Fallback Handling
**Why:** If the configured DNS server becomes unreachable, users lose internet access.
**Implementation:** Monitor DNS resolution failures. Auto-fallback to default DNS or show warning notification.

#### 10. Connection Quality Monitoring
**Why:** Users want to know if their DNS server is performing well over time.
**Implementation:** Periodic background latency checks. Alert if latency exceeds threshold or server becomes unreachable.

### Low Priority

#### 11. Ad-blocking Integration
**Why:** Many DNS users want ad-blocking without installing a full ad-blocker.
**Implementation:** Integrate with blocklist providers (StevenBlack, oisd). Download and apply blocklists via local DNS proxy.

#### 12. DNS Query Logging
**Why:** Advanced users want to see what domains are being resolved.
**Implementation:** Local DNS proxy with query logging. Display recent queries with filtering and export options.

#### 13. Theme Customization
**Why:** Users want more control over app appearance.
**Implementation:** Add theme picker (system, light, dark, amoled black). Custom accent color support.

#### 14. Backup/Restore Improvements
**Why:** Current backup only exports custom servers.
**Implementation:** Full backup including excluded apps, profiles, settings, and statistics. Support cloud backup (Google Drive).

#### 15. DNS-over-QUIC (DoQ) Support
**Why:** DoQ offers lower latency and better privacy than DoH/DoT.
**Implementation:** Integrate `dnsproxy` or custom QUIC implementation for DoQ support.

#### 16. Split DNS / Conditional Forwarding
**Why:** Users may want different DNS servers for different domains (e.g., internal domains via local DNS).
**Implementation:** Add domain-based routing rules. Forward specific domains to different DNS servers.

#### 17. VPN Mode (Local VPN)
**Why:** System Private DNS may not work on all devices or Android versions.
**Implementation:** Use `VpnService` to create a local VPN that routes DNS queries. Works without Shizuku.

#### 18. Quick Settings Tile Customization
**Why:** Users may want multiple tiles for different profiles or actions.
**Implementation:** Add tile configuration. Support multiple tiles with different labels and actions.

#### 19. Notification Actions Expansion
**Why:** Current notification only has toggle. Users may want quick profile switching.
**Implementation:** Add action buttons for profile switching, server selection, and test connectivity.

#### 20. Onboarding Improvements
**Why:** New users may not understand DNS or how to set up Shizuku.
**Implementation:** Interactive tutorial with step-by-step Shizuku setup. Explain DNS benefits and risks.

---

## Technical Improvements

### Code Quality
- [ ] Add unit tests for `AppState` and `DnsService`
- [ ] Add integration tests for native service communication
- [ ] Migrate to `riverpod` or `flutter_riverpod` for better state management
- [ ] Add proper error handling with user-friendly messages
- [ ] Implement logging framework (e.g., `logger` package)

### Performance
- [ ] Optimize app list loading (pagination, virtualization)
- [ ] Reduce notification update frequency
- [ ] Implement DNS latency caching with TTL
- [ ] Optimize widget update logic

### Security
- [ ] Add certificate pinning for DoH endpoints
- [ ] Implement secure storage for sensitive data
- [ ] Add integrity checks for imported configurations
- [ ] Validate DNS server hostnames before applying

### Compatibility
- [ ] Test on Android 14/15 with new foreground service restrictions
- [ ] Add OEM-specific workarounds (MIUI, ColorOS, OneUI)
- [ ] Support foldable devices and tablets
- [ ] Add landscape mode support

---

## Risk Assessment

### High Risk
- **Local DNS proxy:** Requires significant native code, may break on Android updates
- **VPN mode:** Complex implementation, battery drain concerns
- **DoQ support:** Limited library support, requires QUIC implementation

### Medium Risk
- **Network change detection:** May conflict with system DNS settings
- **Scheduled toggling:** Battery optimization may prevent execution
- **Per-app bypass:** OEM restrictions on `UsageStatsManager`

### Low Risk
- **UI improvements:** Standard Flutter features
- **Statistics dashboard:** Local data only, no privacy concerns
- **Widget customization:** Well-documented Android APIs

---

## Recommended Next Steps

1. **DNS Leak Test** - Quick win, high user value
2. **Network Change Detection** - Improves reliability significantly
3. **DNS Fallback Handling** - Prevents user connectivity issues
4. **Multiple DNS Profiles** - Differentiates from competitors
5. **Scheduled DNS Toggling** - Highly requested feature

---

## Competitor Analysis

| Feature | DNS Toggle | Personal DNS | Rethink DNS | AdGuard |
|---------|-----------|--------------|-------------|---------|
| System DNS | ✅ | ✅ | ✅ | ✅ |
| Excluded Apps | ✅ | ✅ | ✅ | ✅ |
| DoH/DoT | ❌ | ✅ | ✅ | ✅ |
| Ad-blocking | ❌ | ❌ | ✅ | ✅ |
| Statistics | ❌ | ❌ | ✅ | ✅ |
| Profiles | ❌ | ❌ | ✅ | ✅ |
| Open Source | ✅ | ❌ | ✅ | Partial |
| No Root | ✅ (Shizuku) | ❌ | ✅ | ✅ |

---

## Conclusion

The project has a solid foundation with reliable DNS control and excluded apps monitoring. The highest-impact additions would be DNS leak testing, network change detection, and multiple profiles. These features would significantly improve user experience and differentiate the app from competitors.

Focus on stability and compatibility first, then add advanced features incrementally.
