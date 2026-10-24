// Test query for the Power Query SDK (VS Code). Do NOT commit a real API token.
// Replace the placeholders locally; the token is stored by the SDK credential store when you set the credential.
//
// Legacy entry point (Anonymous authentication, token passed as an argument):
//   LoginEnterprise_PBI.Contents(FQDN, ApiToken, DaysBack, UseDateRange, StartDateParam, EndDateParam)
// New Key-credential entry point (token entered once in the credential dialog, not in the query):
//   LoginEnterprise_PBI.ContentsKey(FQDN, DaysBack, UseDateRange, StartDateParam, EndDateParam)
let
    result = LoginEnterprise_PBI.ContentsKey("<your-appliance-fqdn>", 7, false, null, null)
in
    result
