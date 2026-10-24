let
    Source = LoginEnterprise_PBI.Contents(FQDN, APIToken, DaysBack, UseDateRange, StartDateParam, EndDateParam),
    Navigation = Source{[Name="Workload Steps"]}[Data]
in
    Navigation