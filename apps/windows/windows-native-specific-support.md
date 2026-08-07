# Windows Native Specific Support

## Capabilities
- WinUI 3 plus Windows App SDK is preferred.
- Settings guidance is store-safe.
- Store package template declares `internetClient` for benchmark traffic and `runFullTrust` for packaged desktop shell/helper/tray behavior.
- Admin service can be considered for later power edition.
- Native shell localization uses `.resw` resources for English and Vietnamese.
- Dynamic Windows shell text follows `CurrentUICulture` for English and Vietnamese.

## Limitations
- Microsoft Store should not depend on UAC elevation.
- DNS settings surfaces differ by Windows version and network adapter.
- `runFullTrust` requires Store review/justification and may affect packaging approval.
- CLI-returned free-text notes/errors may still need stable message IDs for complete multilingual diagnostics.

## Opportunities
- D14 adaptation: keep one non-elevated user-started measurement alive and use Windows
  App SDK `AppNotificationManager` for local completion/result activation. Do not add
  WNS/Azure or depend on elevated notification behavior.
- Adapter detection and settings deep links.
- Enterprise policy detection later.
- Store-specific SKU without tray/helper could be considered if `runFullTrust` is rejected.
