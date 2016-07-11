import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class SchemaTests: GRDBTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testCreateNoColumns() {
        //try! SQL.create(table: "foo", ifNotExists: true).build(db)
        assertError {
            let dbq = try makeDatabaseQueue()
            _ = try dbq.inDatabase { db in
                try db.create(table: "foo") { _ in }
            }
        }
    }

    func testCreateTableReferences() {
        assertNoError {
            let id: SQLColumn = "id"
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column(id, type: .integer)
                        .primaryKey()
                }
                try db.create(table: "bar") { t in
                    t.column(id, type: .integer)
                        .primaryKey()
                    t.column("foo_id", type: .integer)
                        .references(table: "foo", columns: "id")
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE bar ( id INTEGER PRIMARY KEY, foo_id INTEGER REFERENCES foo ( id ) )")
                try db.execute("INSERT INTO foo (id) VALUES (?)", arguments: [1])
                try db.execute("INSERT INTO bar (id, foo_id) VALUES (?, ?)", arguments: [1, 1])
                assertError {
                    try db.execute("INSERT INTO bar (id, foo_id) VALUES (?, ?)", arguments: [2, 2])
                }
            }
        }
    }

    func testCreateTableForeignKeyTableConstraint() {
        assertNoError {
            let id: SQLColumn = "id"
            let fooId: SQLColumn = "foo_id"
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column(id, type: .integer)
                        .primaryKey()
                }
                try db.create(table: "bar") { t in
                    t.column(id, type: .integer)
                        .primaryKey()
                    t.column(fooId, type: .integer)
                    t.foreignKey(
                        columns: [fooId],
                        foreignTable: "foo",
                        foreignColumns: id)
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE bar ( id INTEGER PRIMARY KEY, foo_id INTEGER , FOREIGN KEY ( foo_id ) REFERENCES foo ( id ) )")
                try db.execute("INSERT INTO foo (id) VALUES (?)", arguments: [1])
                try db.execute("INSERT INTO bar (id, foo_id) VALUES (?, ?)", arguments: [1, 1])
                assertError {
                    try db.execute("INSERT INTO bar (id, foo_id) VALUES (?, ?)", arguments: [2, 2])
                }
            }
        }
    }

    func testCreateTableReferencesOnDeleteCascade() {
        assertNoError {
            let id: SQLColumn = "id"
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column(id, type: .integer)
                        .primaryKey()
                }
                try db.create(table: "bar") { t in
                    t.column(id, type: .integer)
                        .primaryKey()
                    t.column("foo_id", type: .integer)
                        .references(
                            table: "foo",
                            columns: "id",
                            onDelete: .cascade)
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE bar ( id INTEGER PRIMARY KEY, foo_id INTEGER REFERENCES foo ( id ) ON DELETE CASCADE )")
                try db.execute("INSERT INTO foo (id) VALUES (?)", arguments: [1])
                try db.execute("INSERT INTO bar (id, foo_id) VALUES (?, ?)", arguments: [1, 1])
                XCTAssertEqual(1, Int.fetchOne(db, "SELECT COUNT(*) FROM bar"))
                try db.execute("DELETE FROM foo")
                XCTAssertEqual(0, Int.fetchOne(db, "SELECT COUNT(*) FROM bar"))
            }
        }
    }

    func testCreateTable1() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id")
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id )")
            }
        }
    }

    func testCreateTable2() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", type: .integer)
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER )")
            }
        }
    }

    func testCreateTable3() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", type: .integer)
                        .primaryKey(onConflict: .rollback)
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK )")
            }
        }
    }

    func testCreateTable4() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", type: .integer)
                        .primaryKey(autoincrement: true)
                        .unique()
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE )")
            }
        }
    }

    func testCreateTable6() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", type: .integer)
                        .primaryKey(order: .desc, onConflict: .rollback)
                        .unique(true)
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER PRIMARY KEY DESC ON CONFLICT ROLLBACK UNIQUE )")
            }
        }
    }

    func testCreateTable7() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", type: .integer)
                        .primaryKey(autoincrement: true, onConflict: .rollback)
                        .unique()
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT UNIQUE )")
            }
        }
    }

    func testCreateTable8() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", type: .integer)
                        .primaryKey(order: .asc, onConflict: .rollback)
                        .unique(onConflict: .rollback)
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER PRIMARY KEY ASC ON CONFLICT ROLLBACK UNIQUE ON CONFLICT ROLLBACK )")
            }
        }
    }

    func testCreateTable9() {
        assertNoError {
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column("id", type: .integer)
                        .primaryKey()
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER PRIMARY KEY )")
            }
        }
    }

    func testCreateTable10() {
        assertNoError {
            let id: SQLColumn = "id"
            let dbq = try makeDatabaseQueue()
            try dbq.inDatabase { db in
                try db.create(table: "foo") { t in
                    t.column(id, type: .integer)
                        .primaryKey()
                        .check(sql: "id > 10")
//                        .check(id > 10) // SQLite error 1 with statement `CREATE TABLE foo ( id INTEGER PRIMARY KEY CHECK ("id" > ?) )`: parameters prohibited in CHECK constraints
                }
                XCTAssertEqual(lastSQLQuery, "CREATE TABLE foo ( id INTEGER PRIMARY KEY CHECK ( id > 10 ) )")
                try db.execute("INSERT INTO foo (id) VALUES (?)", arguments: [11])
                assertError {
                    try db.execute("INSERT INTO foo (id) VALUES (?)", arguments: [1])
                }
                XCTAssertEqual(db.lastInsertedRowID, 11)
            }
        }
    }

}
