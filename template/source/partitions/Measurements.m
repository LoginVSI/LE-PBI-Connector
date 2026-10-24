let
    Source = LoginEnterprise_PBI.Contents(FQDN, APIToken, DaysBack, UseDateRange, StartDateParam, EndDateParam),
    Navigation = Source{[Name="Measurements"]}[Data],
    #"Added Custom" = Table.AddColumn(Navigation, "duation_seconds", each [duration] / 1000),
    #"Renamed Columns" = Table.RenameColumns(#"Added Custom",{{"duation_seconds", "duration_seconds"}})
in
    #"Renamed Columns"