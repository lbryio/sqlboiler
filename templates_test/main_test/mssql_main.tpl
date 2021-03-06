type mssqlTester struct {
	dbConn     *sql.DB
	dbName     string
	host       string
	user       string
	pass       string
	sslmode    string
	port       int
	testDBName string
}

func init() {
	dbMain = &mssqlTester{}
}

func (m *mssqlTester) setup() error {
	var err error
	m.dbName = viper.GetString("mssql.dbname")
	m.host = viper.GetString("mssql.host")
	m.user = viper.GetString("mssql.user")
	m.pass = viper.GetString("mssql.pass")
	m.port = viper.GetInt("mssql.port")
	m.sslmode = viper.GetString("mssql.sslmode")
	// Create a randomized db name.
	m.testDBName = randomize.StableDBName(m.dbName)

	if err = m.dropTestDB(); err != nil {
		return errors.Err(err)
	}
	if err = m.createTestDB(); err != nil {
		return errors.Err(err)
	}

	createCmd := exec.Command("sqlcmd", "-S", m.host, "-U", m.user, "-P", m.pass, "-d", m.testDBName)

	f, err := os.Open("tables_schema.sql")
	if err != nil {
		return errors.Prefix("failed to open tables_schema.sql file", err)
	}

	defer f.Close()

	createCmd.Stdin = newFKeyDestroyer(rgxMSSQLkey, f)

	if err = createCmd.Start(); err != nil {
		return errors.Prefix("failed to start sqlcmd command", err)
	}

	if err = createCmd.Wait(); err != nil {
		fmt.Println(err)
		return errors.Prefix("failed to wait for sqlcmd command", err)
	}

	return nil
}

func (m *mssqlTester) sslMode(mode string) string {
	switch mode {
	case "true":
		return "true"
	case "false":
		return "false"
	default:
		return "disable"
	}
}

func (m *mssqlTester) createTestDB() error {
	sql := fmt.Sprintf(`
	CREATE DATABASE %s;
	GO
	ALTER DATABASE %[1]s
	SET READ_COMMITTED_SNAPSHOT ON;
	GO`, m.testDBName)
	return m.runCmd(sql, "sqlcmd", "-S", m.host, "-U", m.user, "-P", m.pass)
}

func (m *mssqlTester) dropTestDB() error {
	// Since MS SQL 2016 it can be done with
	// DROP DATABASE [ IF EXISTS ] { database_name | database_snapshot_name } [ ,...n ] [;]
	sql := fmt.Sprintf(`
	IF EXISTS(SELECT name FROM sys.databases 
		WHERE name = '%s')
		DROP DATABASE %s
	GO`, m.testDBName, m.testDBName)
	return m.runCmd(sql, "sqlcmd", "-S", m.host, "-U", m.user, "-P", m.pass)
}

func (m *mssqlTester) teardown() error {
	if m.dbConn != nil {
		m.dbConn.Close()
	}

	if err := m.dropTestDB(); err != nil {
		return errors.Err(err)
	}

	return nil
}

func (m *mssqlTester) runCmd(stdin, command string, args ...string) error {
	cmd := exec.Command(command, args...)
	cmd.Stdin = strings.NewReader(stdin)

	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	if err := cmd.Run(); err != nil {
		fmt.Println("failed running:", command, args)
		fmt.Println(stdout.String())
		fmt.Println(stderr.String())
		return errors.Err(err)
	}

	return nil
}

func (m *mssqlTester) conn() (*sql.DB, error) {
	if m.dbConn != nil {
		return m.dbConn, nil
	}

	var err error
	m.dbConn, err = sql.Open("mssql", drivers.MSSQLBuildQueryString(m.user, m.pass, m.testDBName, m.host, m.port, m.sslmode))
	if err != nil {
		return nil, err
	}

	return m.dbConn, nil
}
