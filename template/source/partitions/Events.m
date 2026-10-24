let
    Source = LoginEnterprise_PBI.Contents(FQDN, APIToken, DaysBack, UseDateRange, StartDateParam, EndDateParam),
    Navigation = Source{[Name="Events"]}[Data]
in
    Navigation