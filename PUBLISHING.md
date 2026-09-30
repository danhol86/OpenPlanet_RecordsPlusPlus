# Publishing Records++

## GitHub release

1. Update `version` in `info.toml` and `CHANGELOG.md`.
2. Run `./build.ps1` and test the generated `.op` locally.
3. Commit and push to `main`.
4. Tag the same version, e.g. `git tag v0.3.0 && git push origin v0.3.0`.
5. GitHub Actions creates a Release and attaches `RecordsPlusPlus-0.3.0.op`.

## Openplanet Regular mode

Regular mode only loads user-created plugins that have been reviewed, approved and signed by the Openplanet team. The current website flow is the replacement for the old archived `plugin-signing` GitHub repository.

Before submission:

- Keep `siteid` out of `info.toml` for a new plugin. Openplanet's review process adds it automatically unless the Auth API requires it beforehand.
- Keep the `MLHook` dependency declared in `info.toml`.
- Test in Developer signature mode, then submit the built `.op` through the Openplanet website while logged in.
- Use a non-AI-generated thumbnail.
- Disclose all AI assistance truthfully in the review and choose the appropriate public AI classification on the Openplanet site.
- The plugin must respect Trackmania feature permissions. Records++ checks `Permissions::ViewRecords()` before querying or injecting friend records.
- Do not change the implementation to request full leaderboards; Openplanet explicitly disallows plugins that generate large full-leaderboard request loads.

## Important AI-review constraint

As of September 2026, Openplanet's Plugin Terms of Service say that plugins which are **mostly AI generated are not allowed on the website**. Other AI usage must be disclosed during review and publicly classified.

Records++ has had substantial AI assistance during development. Do not misrepresent that history. Before attempting publication, contact the Openplanet reviewers (Discord or `miss@openplanet.dev`) and ask whether a thorough human review/refactor is sufficient for submission under the current rule.

Relevant Openplanet pages:

- Plugin terms: `https://openplanet.dev/docs/plugin-tos`
- Signature modes: `https://openplanet.dev/docs/tutorials/signature-modes`
- `info.toml` reference: `https://openplanet.dev/docs/reference/info-toml`
- Signature feed: `https://openplanet.dev/plugins/signs`
