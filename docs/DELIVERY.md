# Delivering the report: email subscriptions and Teams (bounded exploration)

Unsupported community preview. This page records what Microsoft documents (checked 2026-11-04 on Microsoft Learn) and what was and was not tested here. **Nothing was configured or sent.** No email subscription exists for the test report, and no Teams mechanism was set up.

**Tested 2026-11-04 (owner-authorised, owner-only):** on the test report in My workspace the Subscribe button is present, but selecting it showed "Upgrade to a paid Power BI license" (Buy now / Try free). The signed-in work account has no Pro or PPU licence, so the test stopped there: no trial was started, nothing was purchased, no subscription was created and no email was sent. Delivery is therefore **blocked by licence, not by the connector or the report**. The Share button was not opened. "Eligible on paper" is not the same as "received", and neither was verified in a live subscription.

## Native Power BI email subscriptions

| Question | What Microsoft documents | Tested here |
|---|---|---|
| Who can subscribe | Access to the report plus a Pro or PPU licence, or a workspace on paid Premium/Fabric capacity. A Fabric admin must enable the tenant setting "Create email subscriptions". | **Blocked:** Subscribe showed an upgrade prompt (no paid licence on this account); tenant setting not checked |
| My workspace | Not excluded; only the creator can manage subscriptions on content in My workspace. | Not tested |
| Recipients | Internal recipients work without Premium for a Pro or PPU owner with Contributor, Member or Admin on the content. External/B2B recipients need paid non-PPU capacity. Whether a free-licence recipient receives mail is not stated. | Not tested |
| Content on Pro (non-Premium) | A preview image of one report page plus a link. | Not tested |
| Full attachment | PDF or PowerPoint needs Premium or PPU capacity; under 20 pages and 25 MB. | Not tested |
| Cadence | Hourly, daily, weekly, monthly and "after data refresh" (once per day, after the first scheduled refresh of that day, UTC day boundaries). Whether an on-demand or API refresh triggers it is not stated. | Not tested |
| Limits | At most 24 subscriptions per report, 200 recipients each. "Run now" does not refresh the model and is rate limited per hour. | Not tested |
| Disable / remove | A slider turns a subscription off; the trash icon deletes it; "Manage all" lists them. | Not tested |
| Common blockers | Tenant switch off, expired licence, conditional access/MFA, password reset auto-disabling, private link with public access blocked, no mailbox for the owner, spam filtering. A renamed or deleted report page breaks the subscription. | Not tested |

Sources: Microsoft Learn, [Subscribe to report or dashboard](https://learn.microsoft.com/en-us/power-bi/collaborate-share/end-user-subscribe), [Troubleshoot subscriptions](https://learn.microsoft.com/en-us/power-bi/collaborate-share/service-troubleshoot-subscribe), [Subscription email delivery changes](https://learn.microsoft.com/en-us/power-bi/collaborate-share/service-subscription-email-delivery-changes).

## Teams

There is **no built-in scheduled or after-refresh delivery to Teams** in the pages checked. Subscription recipients are email addresses. Microsoft 365 groups and plain security groups are not supported as recipients.

- Built in and manual: Share to Teams and Chat in Teams post a link (no preview, no permissions granted). [Learn](https://learn.microsoft.com/en-us/power-bi/collaborate-share/office-integration/service-share-report-teams)
- Needs Power Automate: the "Export to file for Power BI reports" action (PowerPoint, PDF or PNG) with a Teams step you add yourself. The connector page checked does not state licence or capacity requirements, and no refresh-completed trigger was listed. [Connector](https://learn.microsoft.com/en-us/connectors/powerbi/)

This project adds no custom Teams, SharePoint or email service, no webhook and no tenant-wide policy.

## A safe owner-only test (not run)

1. Confirm the tenant switch is on and the owner's mailbox can receive mail.
2. On the report in My workspace choose Subscribe, then create a subscription with only the owner's own address and the permission-grant box unticked.
3. Choose daily or "after data refresh", set a near end date and leave it off until the test.
4. With the owner's go-ahead, use "Run now" once and check the preview and link.
5. Trigger one scheduled refresh to see whether "after data refresh" fires, then delete the subscription and confirm it is gone under "Manage all".
