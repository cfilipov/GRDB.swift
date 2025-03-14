import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueTests: GRDBTestCase {
    
    func testInvalidFileFormat() {
        assertNoError {
            do {
                let testBundle = NSBundle(forClass: self.dynamicType)
                let path = testBundle.pathForResource("Betty", ofType: "jpeg")!
                guard NSData(contentsOfFile: path) != nil else {
                    XCTFail("Missing file")
                    return
                }
                _ = try DatabaseQueue(path: path)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                XCTAssertEqual(error.message!.lowercaseString, "file is encrypted or is not a database") // lowercaseString: accept multiple SQLite version
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description.lowercaseString, "sqlite error 26: file is encrypted or is not a database")
            }
        }
    }
    
    func testAddRemoveFunction() {
        // Adding a function and then removing it should succeed
        assertNoError {
            do {
                let dbQueue = try makeDatabaseQueue()
                let fn = DatabaseFunction("succ", argumentCount: 1) { databaseValues in
                     let dbv = databaseValues.first!
                     guard let int = dbv.value() as Int? else {
                        return nil
                     }
                     return int + 1
                 }
                dbQueue.addFunction(fn)
                try dbQueue.inDatabase { db in
                    XCTAssertEqual(Int.fetchOne(db, "SELECT succ(1)"), 2) // 2
                    try db.execute("SELECT succ(1)")
                }
                dbQueue.removeFunction(fn)
                do {
                    try dbQueue.inDatabase { db in
                        try db.execute("SELECT succ(1)")
                        XCTFail("Expected Error")
                    }
                    XCTFail("Expected Error")
                }
                catch let error as DatabaseError {
                    // expected error
                    XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                    XCTAssertEqual(error.message!.lowercaseString, "no such function: succ") // lowercaseString: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "SELECT succ(1)")
                    XCTAssertEqual(error.description.lowercaseString, "sqlite error 1 with statement `select succ(1)`: no such function: succ")
                }
            }
        }
    }
    
    func testAddRemoveCollation() {
        // Adding a collation and then removing it should succeed
        assertNoError {
            do {
                let dbQueue = try makeDatabaseQueue()
                let collation = DatabaseCollation("test_collation_foo") { (string1, string2) in
                    return (string1 as NSString).localizedStandardCompare(string2)
                }
                dbQueue.addCollation(collation)
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE files (name TEXT COLLATE TEST_COLLATION_FOO)")
                }
                dbQueue.removeCollation(collation)
                do {
                    try dbQueue.inDatabase { db in
                        try db.execute("CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
                        XCTFail("Expected Error")
                    }
                    XCTFail("Expected Error")
                }
                catch let error as DatabaseError {
                    // expected error
                    XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                    XCTAssertEqual(error.message!.lowercaseString, "no such collation sequence: test_collation_foo") // lowercaseString: accept multiple SQLite version
                    XCTAssertEqual(error.sql!, "CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
                    XCTAssertEqual(error.description.lowercaseString, "sqlite error 1 with statement `create table files_fail (name text collate test_collation_foo)`: no such collation sequence: test_collation_foo")
                }
            }
        }
    }
}
