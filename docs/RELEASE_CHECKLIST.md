# Ruby Run 1.0.0 Release Checklist

- [ ] Release signing configured through GitHub Secrets
- [ ] Debug logging disabled and final logs reviewed
- [x] Test ads disabled (no ad SDK in base build)
- [ ] Production ads configured **or ads remain disabled and are declared absent**
- [ ] Privacy Policy published and URL configured
- [x] Data Safety reviewed for current base source
- [ ] Target SDK 36 still satisfies current Play requirements on submission date
- [x] Permissions reviewed in source/export preset
- [x] Third-party SDKs reviewed (none beyond Godot base runtime)
- [ ] Final APK/AAB manifest audited
- [ ] Crash testing completed on representative physical Android devices
- [ ] Offline mode tested on physical device
- [x] Ads-unavailable mode automated test
- [x] Save system automated test
- [ ] Reset Data tested on physical device
- [ ] Store listing, icon, feature graphic and truthful screenshots finalized
- [ ] Content rating and target audience completed accurately
- [ ] 16 KB page-size compatibility verified in Play Console
- [ ] AAB generated and signature verified
- [ ] APK generated and signature verified

A release is blocked while any item relevant to the chosen build remains unchecked. Never enable a release service without updating privacy and Data Safety disclosures.
