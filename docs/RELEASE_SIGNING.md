# Release signing (so updates install over older builds and keep your data)

Builds are signed with a permanent key when these repository secrets exist:
`KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Without them CI
falls back to a debug key (each build then has a different signature, and Android
refuses to update in place).

The key lives at `~/.cash-buddy-signing/` (keystore + credentials.txt). BACK IT UP:
if it is lost you can never ship an update to installed copies. Set the secrets:

    cd ~/.cash-buddy-signing && . ./credentials.txt
    base64 < cash-buddy-release.jks | tr -d '\n' | gh secret set KEYSTORE_B64 --repo nawinsr24/cash-buddy
    gh secret set KEYSTORE_PASSWORD --repo nawinsr24/cash-buddy --body "$KEYSTORE_PASSWORD"
    gh secret set KEY_ALIAS --repo nawinsr24/cash-buddy --body "$KEY_ALIAS"
    gh secret set KEY_PASSWORD --repo nawinsr24/cash-buddy --body "$KEY_PASSWORD"
