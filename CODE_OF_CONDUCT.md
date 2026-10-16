# Contributor Covenant Code of Conduct

**Project**: DNSCrypt Smart Filter
**Version**: v1.4.0
**License**: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Last updated**: 2026-10-08

> **Identifier inventory in this file (5 total)**:
>   • HARD-COC-01 (`Last updated` correction — v1.4.0)
>   • HARD-COC-02 (v1.3.0 block extended with SNAP-* / ROT-* — v1.4.0)
>   • HARD-COC-03 (Q7 table — v1.3.0 rotation research — v1.4.0)
>   • HARD-COC-04 (Q11 table — v1.3.0 rotation row — v1.4.0)
>   • HARD-COC-05 (Cross-references + Related Documents — v1.4.0)
>
> **Cross-references**:
>   • [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — full contribution guide
>   • [docs/SECURITY.md](docs/SECURITY.md) — security policy + threat model
>   • [docs/ARCHITECTURE.md §4.13](docs/ARCHITECTURE.md) — v1.3.0 server-side refinements (authoritative)
>   • [docs/BACKUP.md](docs/BACKUP.md) — backup system reference (v1.2.0 + v1.3.0 rotation semantics)
>   • [CHANGELOG.md](CHANGELOG.md) — version history (v1.0.0 → v1.4.0)

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 file-editing date.
>   • FAQ Q7 extended with the v1.4.0 **Companion Android app** and
>     **CodeQL hardening** notes.
>   • FAQ Q11 replaced — "What's new in v1.4.0 from a community
>     perspective?".
>   • `Related Documents` table extended with the v1.3.0 and v1.4.0
>     additions (`proxy/app-apk.version`, `scripts/fetch_app_apk.sh`,
>     `docs/ARCHITECTURE.md §4.13`).
>   • **Global edition note**: the WebUI ships with English as the
>     default language and an in-page toggle to switch to Arabic.
>     The Code of Conduct remains English-only for legal clarity —
>     this is consistent with the Contributor Covenant's canonical
>     language policy.
>   • Core Contributor Covenant text (Pledge / Standards / Scope /
>     Enforcement / Reporting) is **unchanged** — this is a
>     standard document.

> **v1.3.0 changes**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • `Last updated` reflects the v1.3.0 release date.
>   • FAQ Q11 replaced — "What's new in v1.3.0 from a community
>     perspective?".
>   • **Server-side refinements to the backup layer** — the v1.3.0
>     release ALSO refined the snapshot-detection and rotation
>     semantics that underpin the persistent backup directory.
>     Three identifiers document the change (also used in
>     `CHANGELOG.md` [v1.3.0] and `docs/ARCHITECTURE.md` §4.13):
>
>       🔧 **SNAP-MANIFEST** — `main.go:buildBackupInfo()` now
>         detects a snapshot by `.manifest.json` presence, not
>         by the v1.2.0 name pattern (`^[0-9]{8}-[0-9]{6}-`).
>
>       🔧 **SNAP-MTIME** — `last_backup_name` is now selected by
>         **mtime** (descending), with a name-based fallback.
>         This supersedes the v1.2.0 BUG-3 lexicographic-name
>         rule.
>
>       🔧 **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>         `functions.sh:rotate_backups()` was rewritten with the
>         same manifest-based detection, the same mtime sort,
>         and two additional protected targets on top of the
>         21-newest window:
>           • the `.last_stable` recovery pointer;
>           • the newest install snapshot (name matching
>             `-v<digit>`).
>
>     **Community impact**: The v1.3.0 rotation hardening makes
>     the backup layer more robust — a configuration snapshot
>     that recovery mode or rollback depends on can no longer be
>     silently pruned. Contributors can verify this on multiple
>     ROMs and report results via the standard bug report
>     template. See FAQ Q7 and Q11.
>
>   • **Global edition note**: the WebUI ships with English as the
>     default language and an in-page toggle to switch to Arabic.
>   • Core Contributor Covenant text is **unchanged**.

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date.
>   • FAQ Q7 extended with the v1.2.0 **Data Guardian** badge.
>   • FAQ Q11 replaced — "What's new in v1.2.0 from a community
>     perspective?".
>   • `Related Documents` table extended with `docs/BACKUP.md` and
>     `docs/EMERGENCY.md`.
>   • **Global edition note**: the WebUI ships with English as the
>     default language and an in-page toggle to switch to Arabic.
>     The Code of Conduct remains English-only for legal clarity —
>     this is consistent with the Contributor Covenant's canonical
>     language policy.
>   • Core Contributor Covenant text (Pledge / Standards / Scope /
>     Enforcement / Reporting) is **unchanged** — this is a
>     standard document.

> **v1.4.0 — POST-AUDIT FIXES (this revision)**:
>   A post-audit review of this file against the v1.3.0 / v1.4.0
>   code identified the following documentation gaps. All are
>   addressed in-place; no version bump.
>
>   🔧 **HARD-COC-01** — **`Last updated` corrected.** The header
>     and footer previously said `2026-10-06` (which corresponded
>     to the v1.4.0 release date, not to the v1.4.0 file-editing
>     date). Both now read `2026-10-08`, matching every other file
>     in the v1.4.0 module.
>
>   🔧 **HARD-COC-02** — **`v1.3.0` block extended.** The previous
>     block mentioned only the client-side changes (PWA install
>     button, live status LED, DNS auto-start) and did not document
>     the **server-side refinements** to snapshot detection and
>     rotation (SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST,
>     ROT-MTIME, ROT-PROTECT). The v1.3.0 block above now
>     documents them, with a community-impact note.
>
>   🔧 **HARD-COC-03** — **Q7 table extended.** A new row
>     documents the v1.3.0 rotation hardening as a research area
>     for contributors.
>
>   🔧 **HARD-COC-04** — **Q11 table extended.** A new row
>     documents the v1.3.0 rotation refiner alongside the
>     existing v1.3.0 rows.
>
>   🟢 **HARD-COC-05** — **Cross-references added** at the top of
>     the file, and the **Related Documents** table extended with
>     `docs/ARCHITECTURE.md §4.13` (the authoritative source for
>     the v1.3.0 rotation semantics) and `CHANGELOG.md` §[v1.3.0].

---

## Our Pledge

We, as members, contributors, and maintainers of **DNSCrypt Smart Filter**, pledge to make participation in our community a harassment-free experience for everyone, regardless of:

- Age
- Body size
- Visible or invisible disability
- Ethnicity
- Sex characteristics
- Gender identity and expression
- Level of experience
- Education
- Socio-economic status
- Nationality
- Personal appearance
- Race
- Religion
- Sexual identity and orientation

We pledge to act and interact in ways that contribute to an open, welcoming, diverse, inclusive, and healthy community.

---

## Our Standards

### Positive Behavior

Examples of behavior that contributes to a positive environment:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Accepting responsibility and apologizing to those affected by our mistakes, and learning from the experience
- Focusing on what is best for the community, not just for ourselves
- Showing empathy toward other community members
- Helping newcomers with patience and respect
- Documenting knowledge and sharing it
- Reporting issues constructively

### Unacceptable Behavior

Examples of unacceptable behavior:

- The use of sexualized language or imagery, and sexual attention or advances of any kind
- Trolling, insulting or derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information, such as a physical or email address, without their explicit permission
- Other conduct which could reasonably be considered inappropriate in a professional setting
- Impersonating a contributor or maintainer
- Deliberately spreading misinformation about the project
- Attempting to compromise project systems or users
- Discrimination in any form

---

## Scope

This Code of Conduct applies within all community spaces, and also applies when an individual is officially representing the community in public spaces.

### Inside the Scope

- Comments in Issues and Pull Requests
- Code content (variable names, comments, etc.)
- Documentation and the Wiki
- Official project email
- Interactions on GitHub Discussions
- Official streams or videos
- Social media when officially representing the project

### Outside the Scope

- Contributors' private lives
- Other projects (even those by the same contributor)
- Private conversations between individuals

When officially representing the project, this Code applies even outside the project's platforms.

---

## Enforcement Responsibilities

Project maintainers are responsible for:

- Clarifying and enforcing acceptable behavior standards
- Taking fair and appropriate corrective action
- Removing, editing, or rejecting comments, commits, code, and other contributions that do not align with this Code of Conduct
- Communicating reasons for moderation decisions when appropriate
- Protecting the privacy and safety of reporters
- Applying this Code equally to everyone, including maintainers themselves

---

## Enforcement Guidelines

Maintainers will follow these Community Impact Guidelines when determining consequences for any action they deem in violation of this Code of Conduct:

### 1. Correction

**Community Impact**: Use of inappropriate language or other behavior deemed unprofessional or unwelcome in the community.

**Consequence**: A private, written warning from maintainers, providing clarity around the nature of the violation and an explanation of why the behavior was inappropriate. A public apology may be requested.

### 2. Warning

**Community Impact**: A violation through a single incident or series of actions.

**Consequence**: A warning with consequences for continued behavior. No interaction with the people involved, including unsolicited interaction with those enforcing the Code of Conduct, for a specified period of time. This includes avoiding interactions in community spaces as well as external channels like social media. Violating these terms may lead to a temporary or permanent ban.

### 3. Temporary Ban

**Community Impact**: A serious violation of community standards, including sustained inappropriate behavior.

**Consequence**: A temporary ban from any sort of interaction or public communication with the community for a specified period of time. No public or private interaction with the people involved, including unsolicited interaction with those enforcing the Code of Conduct, is allowed during this period. Violating these terms may lead to a permanent ban.

### 4. Permanent Ban

**Community Impact**: Demonstrating a pattern of violation of community standards, including sustained inappropriate behavior, harassment of an individual, or aggression toward or disparagement of classes of individuals.

**Consequence**: A permanent ban from any sort of public interaction within the community.

---

## Reporting Violations

### Preferred Channels

- **GitHub Private Report**: [Report abuse](https://github.com/contact/report-abuse)
- **Maintainer contact**: [@gasciljh](https://github.com/gasciljh)

### What to Include

- A clear description of the incident
- When and where it occurred
- Who was involved
- Supporting evidence (screenshots, links)
- Any additional context

### After Reporting

| Phase | Duration |
|---|---|
| Acknowledgment | 24–48 hours |
| Initial investigation | 3–7 days |
| Decision + action | Depends on severity |
| Reporter notification | After decision |

### Confidentiality

- Reporter privacy is fully protected
- Accused party privacy is protected during investigation
- Investigation details are not disclosed publicly
- Final decision may be published in summary form (without names)

---

## Project Philosophy

This Code of Conduct is applied in a spirit that emphasizes:

### 1. Inclusivity

We welcome users from all backgrounds:

- All languages (English is the primary language of the project)
- All countries and cultures
- All levels of experience (from beginners to experts)
- Users with disabilities

### 2. Respect

- Focus on the problem, not the person
- Constructive criticism only
- Apologize when wrong
- Teach rather than insult

### 3. Transparency

- Issues are discussed publicly (except security and privacy)
- Decisions are documented in Issues / PRs
- Reasons are stated when rejecting a PR

### 4. Zero Tolerance for Harassment

- Any form of harassment results in immediate action
- Discrimination is unacceptable in any form
- Victims are fully protected

---

## Attribution

This Code of Conduct is adapted from:

- **[Contributor Covenant](https://www.contributor-covenant.org)** v2.1
  - Official document: https://www.contributor-covenant.org/version/2/1/code_of_conduct/
  - Markdown source: https://www.contributor-covenant.org/version/2/1/code_of_conduct/code_of_conduct.md
  - License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)

- Community Impact Guidelines were inspired by [Mozilla's code of conduct enforcement ladder](https://github.com/mozilla/inclusion#code-of-conduct).

### Project Information

- Project version: `v1.4.0`
- First release: `2026-09-24`
- Latest release: `2026-10-06` (v1.4.0)
- Maintainer: [@gasciljh](https://github.com/gasciljh)
- License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

---

## Related Documents

| Document | Content |
|---|---|
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Full contribution guide |
| [docs/SECURITY.md](docs/SECURITY.md) | Security policy + Threat Model (§5.31, §5.32, §5.33, §5.34, §5.35) |
| [.github/SECURITY.md](.github/SECURITY.md) | Vulnerability reporting (short) |
| [SECURITY.md](SECURITY.md) | Root security policy summary |
| [docs/HALL_OF_FAME.md](docs/HALL_OF_FAME.md) | Contributors recognition (Memory Architect + Data Guardian) |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Project roadmap |
| **[docs/ARCHITECTURE.md §4.13](docs/ARCHITECTURE.md)** | **v1.3.0 server-side refinements (SNAP-* / ROT-* — authoritative)** |
| [docs/BACKUP.md](docs/BACKUP.md) | **Backup system reference (v1.2.0 + v1.3.0 rotation semantics)** |
| [docs/EMERGENCY.md](docs/EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [docs/UPGRADE.md](docs/UPGRADE.md) | Version upgrade guide (§3.0, §3.1) |
| [CHANGELOG.md](CHANGELOG.md) | Version history (including v1.3.0 and v1.4.0) |
| [LICENSE](LICENSE) | Project license (MIT) |
| [README.md](README.md) | Project overview |
| [docs/BRANCHING.md](docs/BRANCHING.md) | Git branching strategy |
| [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) | Release process |
| [GitHub Community Guidelines](https://docs.github.com/en/site-policy/github-terms/github-community-guidelines) | GitHub platform rules |

---

## FAQ

### Q1: Are there any exceptions?

No. This Code applies to everyone — including the maintainers themselves.

### Q2: How do I report a violation?

See [Reporting Violations](#reporting-violations) above.

### Q3: Can a ban be appealed?

Yes. A banned individual may contact the maintainer after the ban period ends to request reconsideration.

### Q4: What if a maintainer is the one violating?

- GitHub Support can be contacted via [Report abuse](https://github.com/contact/report-abuse).
- A formal complaint can be filed via [GitHub Private Advisory](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new).

### Q5: Is the Code translated?

The canonical version is English. The Contributor Covenant is available in [40+ languages](https://www.contributor-covenant.org/translations/).

### Q6: How can I contribute correctly?

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for details:

- Accepted contribution types
- Pull Request lifecycle
- Build verification requirements
- Coding standards
- **v1.2.0**: backup-layer changes must update `docs/BACKUP.md` and
  `docs/EMERGENCY.md`. See `docs/CONTRIBUTING.md` §8.9 and §9.5.
- **v1.2.0**: any new user-facing string must supply both `en` and
  `ar` entries. See `docs/CONTRIBUTING.md` §8.11 and §9.6.
- **v1.3.0**: any change to snapshot detection or rotation must
  align with the SNAP-MANIFEST / SNAP-MTIME / ROT-* semantics
  documented in `docs/ARCHITECTURE.md` §4.13. See
  `docs/CONTRIBUTING.md` §8.9 and `docs/BACKUP.md` §6.5.

### Q7: How is the Code enforced technically?

| Aspect | Implementation |
|---|---|
| Welcoming environment | Issue and PR templates request clear information |
| Anti-abuse | `detect-secrets` + code review before merge |
| Transparency | All decisions are in public Issues / PRs |
| Recognition | [HALL_OF_FAME.md](docs/HALL_OF_FAME.md) honors contributors |
| Bilingual support | WebUI bilingual (EN default + AR toggle) + AR Contributor Covenant linked in Q9 |
| Newcomer protection | [docs/FAQ.md](docs/FAQ.md) with common questions |
| Memory research (v1.1.0) | Memory Architect badge for contributors who test dynamic memory limits across RAM tiers |
| **Data preservation research (v1.2.0)** | **Data Guardian badge for contributors who test the 10 defensive layers across devices, root solutions, and upgrade scenarios** |
| **Rotation semantics research (v1.3.0)** | **Contributors can verify the SNAP-MANIFEST / SNAP-MTIME / ROT-MANIFEST / ROT-MTIME / ROT-PROTECT semantics on real devices — see `docs/COMPATIBILITY.md` §10.3.5 for the on-device verification procedure. Results reported via the standard bug report template.** |
| **Boot reliability research (v1.3.0)** | **Contributors can verify the DNS auto-start-after-boot fix on multiple ROMs and report results via the standard bug report template** |
| **Companion app ecosystem (v1.4.0)** | **Companion Android app bundled as an OPTIONAL asset; contributed to the sister repository [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)** |
| **Static analysis hygiene (v1.4.0)** | **Two CodeQL `go/path-injection` alerts (#1, #2) closed in `removeModule` — reduces the project's SAST surface** |

### Q8: Does the Code conflict with my local laws?

No. The Code provides additional protection above the legal minimum. If a conflict arises with local law, the law applies with consideration for the Code's ethical principles.

### Q9: Where can I find the Arabic translation?

The Arabic version of the Contributor Covenant is available at:
https://www.contributor-covenant.org/ar/version/2/1/code_of_conduct/

**Note (v1.4.0)**: The WebUI ships with **English as the default
language** and an in-page toggle (`langToggle`) that switches to
**Arabic**. The Code of Conduct itself is **English-only** for legal
clarity, in line with the Contributor Covenant's recommendation.
Documentation remains English-only by project convention — community
translations are welcome as separate files
(`docs/*.<lang>.md`).

### Q10: How do I report a violation in another project using Contributor Covenant?

- GitHub Support: [Report abuse](https://github.com/contact/report-abuse)
- Contributor Covenant Team: via their official website

### Q11: What's new in v1.4.0 from a community perspective?

**Short answer**: Nothing that changes the Code of Conduct itself. The
v1.4.0 release is an **integration release**. From a community
perspective, the following additions are relevant:

| Change | Impact on the community |
|---|---|
| **Companion Android app integration (v1.4.0)** | A native WebView wrapper (~3 MB) is now bundled into the module ZIP as an OPTIONAL asset at `web/app-debug.apk`. Users can install it from the WebUI install button. It lives in the sister repository [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) — contributors can send PRs there. |
| **CodeQL `go/path-injection` fix (v1.4.0)** | Two CodeQL alerts in `removeModule` were closed via `filepath.Base()` sanitization. Reduces the project's SAST surface. No user-facing change. |
| **iOS PWA logic removed (v1.4.0)** | Android-only project. Removes ~35 lines of dead code from `web/index.html`. |
| **PWA install button (v1.3.0)** | A smart dynamic install button that adapts to the browser (Chromium, iOS Safari, unsupported browsers). |
| **Live status LED (v1.3.0)** | A 12×12 LED on the Today counter reflects DNS engine state. |
| **DNS auto-start after boot (v1.3.0)** | A **critical fix** in `service.sh` closes a boot race. DNS now starts within seconds of the WebUI coming up. |
| **Rotation semantics refinement (v1.3.0)** | **`buildBackupInfo` + `rotate_backups` now use SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME + ROT-PROTECT. The `.last_stable` pointer and the newest install snapshot are protected from pruning. Custom-named snapshots are now visible to the API. See `docs/ARCHITECTURE.md` §4.13.** |
| **Data preservation (v1.2.0)** | Users' configuration is preserved across upgrades, renames, reinstalls, and root-solution changes. The v1.1.0 data-loss bug is fixed. |
| **Persistent backup directory (v1.2.0)** | A snapshot survives uninstall, so a reinstall restores your settings automatically. |
| **Recovery mode (v1.2.0)** | Users can recover from a corrupted config with one command. No more "start from scratch". |
| **New CLI tools (v1.2.0)** | `action.sh --backup` and `status.sh --diagnose` let users take snapshots and inspect the state without leaving the terminal. |
| **Data Guardian badge (v1.2.0)** | New recognition path in `docs/HALL_OF_FAME.md` for contributors who test the backup/restore system across 3+ devices or root solutions. |
| **Bilingual WebUI (EN + AR) (v1.2.0)** | English remains the default, and an in-page toggle switches to Arabic. The API remains language-neutral. |
| **New documentation (v1.2.0)** | `docs/BACKUP.md` and `docs/EMERGENCY.md` give users a full reference and a step-by-step recovery guide. |
| **All documentation in English** | The project is a global English edition. Arabic-speaking users benefit from the bilingual WebUI and the AR Contributor Covenant. |

**Nothing was removed.** All v1.0.0, v1.1.0, v1.2.0, and v1.3.0
community features (bilingual WebUI, HALL_OF_FAME recognition,
contribution guide, Memory Architect badge, Data Guardian badge,
PWA install button, live status LED, DNS auto-start fix, rotation
hardening) remain in place.

See [CHANGELOG.md](CHANGELOG.md) §[v1.4.0] for the full v1.4.0
changelog.

---

## Contact

- GitHub: [@gasciljh](https://github.com/gasciljh)
- Repository: [dnscrypt-proxy-webui](https://github.com/gasciljh/dnscrypt-proxy-webui)
- Issues: [Report a bug](https://github.com/gasciljh/dnscrypt-proxy-webui/issues)
- Discussions: [Join the discussion](https://github.com/gasciljh/dnscrypt-proxy-webui/discussions)
- Behavior reports: [GitHub Private Report](https://github.com/contact/report-abuse)

---

## License

This Code of Conduct is licensed under the [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

It may be used and modified freely with attribution.

- Original text: [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/)
- License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Usage: Open for other projects (with attribution)

The project's own code and documentation are licensed under the [MIT License](LICENSE). The Code of Conduct is a separate document under CC BY 4.0.

---

*Last updated: 2026-10-08*
*Version: v1.4.0*
*Maintainer: [@gasciljh](https://github.com/gasciljh)*
*Author: gasciljh*
