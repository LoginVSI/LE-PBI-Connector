let
    Source = LoginEnterprise_PBI.Contents(FQDN, APIToken, DaysBack, UseDateRange, StartDateParam, EndDateParam),
    Navigation = Source{[Name="User Sessions"]}[Data],
    #"Sorted Rows" = Table.Sort(Navigation,{{"created", Order.Descending}})
in
    #"Sorted Rows"