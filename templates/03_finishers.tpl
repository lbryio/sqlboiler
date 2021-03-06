{{- $tableNameSingular := .Table.Name | singular | titleCase -}}
{{- $varNameSingular := .Table.Name | singular | camelCase -}}
// OneP returns a single {{$tableNameSingular}} record from the query, and panics on error.
func (q {{$tableNameSingular}}Query) OneP() (*{{$tableNameSingular}}) {
	o, err := q.One()
	if err != nil {
		panic(errors.Err(err))
	}

	return o
}

// One returns a single {{$tableNameSingular}} record from the query.
func (q {{$tableNameSingular}}Query) One() (*{{$tableNameSingular}}, error) {
	o := &{{$tableNameSingular}}{}

	queries.SetLimit(q.Query, 1)

	err := q.Bind(o)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, errors.Prefix("{{.PkgName}}: failed to execute a one query for {{.Table.Name}}", err)
	}

	{{if not .NoHooks -}}
	if err := o.doAfterSelectHooks(queries.GetExecutor(q.Query)); err != nil {
		return o, err
	}
	{{- end}}

	return o, nil
}

// AllP returns all {{$tableNameSingular}} records from the query, and panics on error.
func (q {{$tableNameSingular}}Query) AllP() {{$tableNameSingular}}Slice {
	o, err := q.All()
	if err != nil {
		panic(errors.Err(err))
	}

	return o
}

// All returns all {{$tableNameSingular}} records from the query.
func (q {{$tableNameSingular}}Query) All() ({{$tableNameSingular}}Slice, error) {
	var o []*{{$tableNameSingular}}

	err := q.Bind(&o)
	if err != nil {
		return nil, errors.Prefix("{{.PkgName}}: failed to assign all query results to {{$tableNameSingular}} slice", err)
	}

	{{if not .NoHooks -}}
	if len({{$varNameSingular}}AfterSelectHooks) != 0 {
		for _, obj := range o {
			if err := obj.doAfterSelectHooks(queries.GetExecutor(q.Query)); err != nil {
				return o, err
			}
		}
	}
	{{- end}}

	return o, nil
}

// CountP returns the count of all {{$tableNameSingular}} records in the query, and panics on error.
func (q {{$tableNameSingular}}Query) CountP() int64 {
	c, err := q.Count()
	if err != nil {
		panic(errors.Err(err))
	}

	return c
}

// Count returns the count of all {{$tableNameSingular}} records in the query.
func (q {{$tableNameSingular}}Query) Count() (int64, error) {
	var count int64

	queries.SetSelect(q.Query, nil)
	queries.SetCount(q.Query)

	err := q.Query.QueryRow().Scan(&count)
	if err != nil {
		return 0, errors.Prefix("{{.PkgName}}: failed to count {{.Table.Name}} rows", err)
	}

	return count, nil
}

// Exists checks if the row exists in the table, and panics on error.
func (q {{$tableNameSingular}}Query) ExistsP() bool {
	e, err := q.Exists()
	if err != nil {
		panic(errors.Err(err))
	}

	return e
}

// Exists checks if the row exists in the table.
func (q {{$tableNameSingular}}Query) Exists() (bool, error) {
	var count int64

	queries.SetCount(q.Query)
	queries.SetSelect(q.Query, []string{})
	queries.SetLimit(q.Query, 1)

	err := q.Query.QueryRow().Scan(&count)
	if err != nil {
		return false, errors.Prefix("{{.PkgName}}: failed to check if {{.Table.Name}} exists", err)
	}

	return count > 0, nil
}
